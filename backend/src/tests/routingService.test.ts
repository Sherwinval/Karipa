import { afterEach, describe, expect, it, vi } from 'vitest';
import { rankCandidateRoutes, type RouteCandidateRanker } from '../services/routeRankingService.js';
import {
  generateCandidateRoutes,
  validateAndDeduplicateCandidateRoutes,
  type CandidateRoute,
} from '../services/routingService.js';
import type {
  RouteCandidateEvaluation,
  RouteCandidateForRanking,
  RoutePreferencesForEvaluation,
} from '../services/groqService.js';

let geometryCounter = 0;
const originalMaximumDeviation = process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
const originalAiRankingEnabled = process.env.AI_ROUTE_RANKING_ENABLED;
const originalValhallaBaseUrl = process.env.VALHALLA_BASE_URL;

afterEach(() => {
  vi.unstubAllGlobals();
  if (originalMaximumDeviation === undefined) {
    delete process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
  } else {
    process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM = originalMaximumDeviation;
  }
  if (originalAiRankingEnabled === undefined) {
    delete process.env.AI_ROUTE_RANKING_ENABLED;
  } else {
    process.env.AI_ROUTE_RANKING_ENABLED = originalAiRankingEnabled;
  }
  if (originalValhallaBaseUrl === undefined) {
    delete process.env.VALHALLA_BASE_URL;
  } else {
    process.env.VALHALLA_BASE_URL = originalValhallaBaseUrl;
  }
});

it('rejects route geometry that conflicts with the authoritative Valhalla distance', async () => {
  process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
  vi.stubGlobal('fetch', vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body));
    return mockRouteResponse(1, body.locations[0].lat, body.locations[0].lon).json().then((payload) =>
      new Response(JSON.stringify({
        ...payload,
        trip: {
          ...payload.trip,
          summary: { length: 10, time: 900 },
          legs: [{ ...payload.trip.legs[0], summary: { length: 10, time: 900 } }],
        },
      }), { status: 200 })
    );
  }));

  await expect(generateCandidateRoutes(
    'walking',
    5,
    {},
    { latitude: 14.5995, longitude: 120.9842 },
  )).rejects.toMatchObject({
    name: 'RoutingServiceError',
    providerStatus: 'DISTANCE_GEOMETRY_MISMATCH',
  });
});

it('rejects fabricated route geometry that is materially inconsistent with Valhalla summary values', async () => {
  process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
  vi.stubGlobal('fetch', vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body));
    const startLat = body.locations[0].lat;
    const startLon = body.locations[0].lon;
    const shortShape = encodePolyline([
      [startLat, startLon],
      [startLat + 0.002, startLon],
      [startLat + 0.003, startLon + 0.002],
      [startLat, startLon + 0.002],
      [startLat, startLon],
    ]);

    return new Response(JSON.stringify({
      trip: {
        legs: [{ shape: shortShape, summary: { length: 5, time: 900 } }],
        summary: { length: 5, time: 900 },
      },
    }), { status: 200 });
  }));

  await expect(generateCandidateRoutes(
    'walking',
    5,
    {},
    { latitude: 14.5995, longitude: 120.9842 },
  )).rejects.toMatchObject({
    name: 'RoutingServiceError',
    providerStatus: 'DISTANCE_GEOMETRY_MISMATCH',
  });
});

function route(
  id: string,
  distanceKm: number,
  options: { isLoop?: boolean; majorRoadRatio?: number; coordinates?: [number, number][] } = {}
): CandidateRoute {
  const longitudeOffset = geometryCounter++ / 1000;

  return {
    id,
    name: id,
    activityType: 'running',
    distanceKm,
    distanceMeters: distanceKm * 1000,
    durationSeconds: Math.round(distanceKm * 360),
    geometry: {
      type: 'LineString',
      coordinates: options.coordinates ?? [
        [120 + longitudeOffset, 14.5],
        [120.01 + longitudeOffset, 14.51],
        [120.02 + longitudeOffset, 14.52],
      ],
    },
    features: {
      distanceDeltaKm: 0,
      isLoop: options.isLoop ?? false,
      sidewalkRatio: 0.8,
      majorRoadRatio: options.majorRoadRatio ?? 0.1,
      cyclingLaneRatio: 0.5,
      roadTypes: ['Residential'],
    },
  };
}

function encodePolyline(points: [number, number][]): string {
  let previousLat = 0;
  let previousLon = 0;
  let encoded = '';
  for (const [lat, lon] of points) {
    const scaledLat = Math.round(lat * 1e6);
    const scaledLon = Math.round(lon * 1e6);
    for (const delta of [scaledLat - previousLat, scaledLon - previousLon]) {
      let value = delta < 0 ? ~(delta << 1) : delta << 1;
      while (value >= 0x20) {
        encoded += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
        value >>= 5;
      }
      encoded += String.fromCharCode(value + 63);
    }
    previousLat = scaledLat;
    previousLon = scaledLon;
  }
  return encoded;
}

function mockRouteResponse(distanceKm: number, lat: number, lon: number): Response {
  const sideKm = distanceKm / 4;
  const latOffset = sideKm / 111.32;
  const lonOffset = sideKm / (111.32 * Math.cos(lat * Math.PI / 180));
  const shape = encodePolyline([
    [lat, lon],
    [lat + latOffset, lon],
    [lat + latOffset, lon + lonOffset],
    [lat, lon + lonOffset],
    [lat, lon],
  ]);
  return new Response(JSON.stringify({
    trip: {
      legs: [{ shape, summary: { length: distanceKm, time: 900 } }],
      summary: { length: distanceKm, time: 900 },
    },
  }), { status: 200 });
}

function candidateEvaluation(ids: string[]): RouteCandidateEvaluation {
  return {
    rankedRouteIds: ids,
    candidateReasons: ids.map((routeId) => ({ routeId, reason: `Reason for ${routeId}.` })),
    distanceInsight: 'Candidates are compared by their routed distances.',
  };
}

describe('route distance validation', () => {
  it('applies the documented default distance tolerance', () => {
    delete process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
    const candidates = [route('near', 10.1), route('far', 17)];

    expect(validateAndDeduplicateCandidateRoutes(candidates, 10).map((item) => item.id))
      .toEqual(['near']);
  });

  it('applies only an explicitly configured distance tolerance', () => {
    process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM = '2';
    const candidates = [route('within', 12), route('outside', 12.01)];

    expect(validateAndDeduplicateCandidateRoutes(candidates, 10).map((item) => item.id))
      .toEqual(['within']);
  });

  it('uses the routing-engine distance instead of the supplied display distance', () => {
    process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM = '6';
    const candidate = { ...route('authoritative', 8), distanceKm: 13 };

    expect(validateAndDeduplicateCandidateRoutes([candidate], 10)[0].distanceKm).toBe(8);
    expect(validateAndDeduplicateCandidateRoutes([candidate], 14)[0].distanceKm).toBe(8);
  });

  it('rejects malformed, discontinuous, and substantially duplicate route geometries', () => {
    const valid = route('valid', 5);
    const duplicate = {
      ...route('duplicate', 5),
      geometry: valid.geometry,
    };
    const malformed = {
      ...route('malformed', 5),
      geometry: { type: 'LineString' as const, coordinates: [[181, 14], [182, 14]] as [number, number][] },
    };
    const stationary = {
      ...route('stationary', 5),
      geometry: { type: 'LineString' as const, coordinates: [[120, 14], [120, 14]] as [number, number][] },
    };
    const duplicatePoint = {
      ...route('duplicate-point', 5),
      geometry: {
        type: 'LineString' as const,
        coordinates: [[120, 14], [120, 14], [120.02, 14]] as [number, number][],
      },
    };
    const largeJump = {
      ...route('large-jump', 5),
      geometry: { type: 'LineString' as const, coordinates: [[120, 14], [121, 14]] as [number, number][] },
    };

    expect(validateAndDeduplicateCandidateRoutes([
      valid,
      duplicate,
      malformed,
      stationary,
      duplicatePoint,
      largeJump,
    ], 5).map((item) => item.id))
      .toEqual(['valid']);
  });

  it('handles short targets and filters routes using the configured tolerance', () => {
    delete process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
    expect(validateAndDeduplicateCandidateRoutes([route('short', 0.4)], 0.5)).toHaveLength(1);
    expect(validateAndDeduplicateCandidateRoutes([route('far', 17.99)], 20)).toHaveLength(0);

    process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM = '1';
    expect(validateAndDeduplicateCandidateRoutes([route('outside', 17.99)], 20)).toEqual([]);
  });

  it('rejects duplicate candidate identifiers', () => {
    const first = route('same-id', 5);
    const duplicate = { ...route('same-id', 5), name: 'duplicate identifier' };

    expect(validateAndDeduplicateCandidateRoutes([first, duplicate], 5).map((item) => item.name))
      .toEqual(['same-id']);
  });
});

describe('Valhalla routing API generation', () => {
  it('requests Valhalla pedestrian route and measures returned geometry and distance', async () => {
    process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
    const requests: { url: string; init: RequestInit }[] = [];
    vi.stubGlobal('fetch', vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
      requests.push({ url: String(input), init: init ?? {} });
      const requestBody = JSON.parse(String(init?.body));
      return mockRouteResponse(4.8, requestBody.locations[0].lat, requestBody.locations[0].lon);
    }));

    const candidates = await generateCandidateRoutes(
      'running',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    );

    expect(requests).toHaveLength(6);
    expect(requests[0].url).toBe('http://localhost:8002/route');
    expect(JSON.parse(String(requests[0].init.body)).costing).toBe('pedestrian');
    expect(JSON.parse(String(requests[0].init.body)).locations[0].radius).toBe(150);
    expect(candidates).toHaveLength(1);
    expect(candidates[0].distanceMeters).toBe(4800);
    expect(candidates[0].geometry.coordinates[0]).toEqual([120.9842, 14.5995]);
    expect(candidates[0].geometry.coordinates.at(-1)).toEqual([120.9842, 14.5995]);
  });

  it('uses Valhalla bicycle mode without silently falling back to another provider', async () => {
    process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
    let requestCount = 0;
    vi.stubGlobal('fetch', vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
      requestCount++;
      const requestBody = JSON.parse(String(init?.body));
      expect(requestBody.costing).toBe('bicycle');
      return mockRouteResponse(5, requestBody.locations[0].lat, requestBody.locations[0].lon);
    }));

    await generateCandidateRoutes(
      'cycling',
      5,
      { avoidMajorRoads: true, preferCyclingInfrastructure: true, avoidHills: true },
      { latitude: 14.5995, longitude: 120.9842 },
    );
    expect(requestCount).toBe(6);
    const firstBody = JSON.parse(String((vi.mocked(fetch).mock.calls[0][1] as RequestInit).body));
    expect(firstBody.costing_options.bicycle).toMatchObject({
      use_hills: 0.2,
      use_roads: 0.2,
      use_trails: 0.7,
    });
  });

  it('returns an explicit no-coverage error when Valhalla has no bicycle route', async () => {
    process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
      error_code: 171,
      error: 'No path could be found for input',
    }), { status: 404 })));

    await expect(generateCandidateRoutes(
      'cycling',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    )).rejects.toThrow('No cycling route is available for this area.');
  });

  it('rejects a malformed successful Valhalla response instead of returning an empty success', async () => {
    process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
      trip: { legs: [] },
    }), { status: 200 })));

    await expect(generateCandidateRoutes(
      'walking',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    )).rejects.toMatchObject({
      name: 'RoutingServiceError',
      providerStatus: 'INVALID_RESPONSE',
    });
  });

  it('turns Valhalla timeouts into explicit routing errors', async () => {
    process.env.VALHALLA_BASE_URL = 'http://localhost:8002';
    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new DOMException('Request aborted', 'AbortError');
    }));

    await expect(generateCandidateRoutes(
      'walking',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    )).rejects.toMatchObject({
      name: 'RoutingServiceError',
      statusCode: 504,
      providerStatus: 'TIMEOUT',
    });
  });

  it('requires a server-side VALHALLA_BASE_URL configuration', async () => {
    delete process.env.VALHALLA_BASE_URL;
    await expect(generateCandidateRoutes(
      'walking',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    )).rejects.toThrow('VALHALLA_BASE_URL');
  });
});

describe('route ranking', () => {
  it('ranks by distance before preferences without excluding valid routes by default', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'false';
    const closest = route('closest', 9.9, { isLoop: false, majorRoadRatio: 0.9 });
    const preferredButFarther = route('preferred', 10.4, { isLoop: true, majorRoadRatio: 0 });
    const outOfRange = route('excluded', 12.01);

    const ranked = await rankCandidateRoutes(
      'running',
      10,
      { preferLoop: true, avoidMajorRoads: true },
      [preferredButFarther, outOfRange, closest]
    );

    expect(ranked.map((item) => item.id)).toEqual(['closest', 'preferred']);
    expect(ranked[0].distanceKm).toBeCloseTo(9.9);
    expect(ranked[0].absoluteDistanceDeviationKm).toBeCloseTo(0.1);
    expect(ranked[0].percentageDistanceDeviation).toBeCloseTo(1);
    expect(ranked[0].rank).toBe(1);
    expect(ranked[0].isTopRecommendation).toBe(true);
  });

  it('changes preference ordering when selected preferences change', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'false';
    const loop = route('loop', 5, { isLoop: true });
    const direct = route('direct', 5, { isLoop: false });

    const loopPreferred = await rankCandidateRoutes('running', 5, { preferLoop: true }, [direct, loop]);
    const noLoopPreference = await rankCandidateRoutes('running', 5, { preferLoop: false }, [direct, loop]);

    expect(loopPreferred[0].id).toBe('loop');
    expect(noLoopPreference[0].id).toBe('direct');
  });

  it('uses AI to rank all validated routes and labels the ranking source', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'true';
    const routes = [route('alpha', 5), route('beta', 5.02)];
    const aiRanker = vi.fn(async (
      _activity: string,
      _targetDistance: number,
      _preferences: RoutePreferencesForEvaluation,
      _candidates: RouteCandidateForRanking[],
    ) => candidateEvaluation(['beta', 'alpha']));
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      routes,
      aiRanker,
    );

    expect(aiRanker).toHaveBeenCalledTimes(1);
    expect(aiRanker.mock.calls[0][3].map(({ id }) => id)).toEqual(['alpha', 'beta']);
    expect(ranked.map(({ id }) => id)).toEqual(['beta', 'alpha']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'ai_assisted')).toBe(true);
  });

  it('uses the AI ranker when the setting is omitted', async () => {
    delete process.env.AI_ROUTE_RANKING_ENABLED;
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('alpha', 5), route('beta', 5.02)],
      async () => candidateEvaluation(['beta', 'alpha']),
    );

    expect(ranked.map(({ id }) => id)).toEqual(['beta', 'alpha']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'ai_assisted')).toBe(true);
  });

  it('lets AI reorder only distance-close candidates, keeping larger deviations distance-first', async () => {
    delete process.env.AI_ROUTE_RANKING_ENABLED;
    const aiRanker = vi.fn(async (
      _activity: string,
      _targetDistance: number,
      _preferences: RoutePreferencesForEvaluation,
      _candidates: RouteCandidateForRanking[],
    ) => candidateEvaluation(['farther', 'nearby', 'nearest']));
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('nearest', 5), route('nearby', 5.02), route('farther', 5.2)],
      aiRanker,
    );

    expect(aiRanker).toHaveBeenCalledTimes(1);
    expect(aiRanker.mock.calls[0][3].map(({ id }) => id)).toEqual(['nearest', 'nearby', 'farther']);
    expect(ranked.map(({ id }) => id)).toEqual(['nearby', 'nearest', 'farther']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'ai_assisted')).toBe(true);
  });

  it('skips AI when explicitly disabled', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'false';
    let aiCalled = false;
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('alpha', 5), route('beta', 5)],
      async () => {
        aiCalled = true;
        return candidateEvaluation(['beta', 'alpha']);
      },
    );

    expect(aiCalled).toBe(false);
    expect(ranked.map(({ id }) => id)).toEqual(['alpha', 'beta']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'deterministic_fallback')).toBe(true);
  });

  it('uses deterministic ranking when Groq is unavailable', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'true';
    delete process.env.GROQ_API_KEY;
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('alpha', 5), route('beta', 5.02)],
    );

    expect(ranked.map(({ id }) => id)).toEqual(['alpha', 'beta']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'deterministic_fallback')).toBe(true);
  });

  const failingRankers: [string, RouteCandidateRanker][] = [
    ['throws', async () => { throw new Error('service unavailable'); }],
    ['returns an unknown identifier', async () => candidateEvaluation(['missing', 'alpha'])],
    ['returns duplicate identifiers', async () => candidateEvaluation(['alpha', 'alpha'])],
    ['omits a candidate', async () => candidateEvaluation(['alpha'])],
  ];

  it.each(failingRankers)('uses deterministic fallback when AI %s', async (_scenario, aiRanker) => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'true';
    const routes = [route('alpha', 5), route('beta', 5)];
    const ranked = await rankCandidateRoutes('running', 5, {}, routes, aiRanker);

    expect(ranked.map(({ id }) => id)).toEqual(['alpha', 'beta']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'deterministic_fallback')).toBe(true);
  });
});
