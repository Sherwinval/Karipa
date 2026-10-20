import { afterEach, describe, expect, it, vi } from 'vitest';
import { rankCandidateRoutes } from '../services/routeRankingService.js';
import {
  generateCandidateRoutes,
  validateAndDeduplicateCandidateRoutes,
  type CandidateRoute,
} from '../services/routingService.js';

let geometryCounter = 0;
const originalMaximumDeviation = process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
const originalAiRankingEnabled = process.env.AI_ROUTE_RANKING_ENABLED;
const originalGoogleRoutesApiKey = process.env.GOOGLE_MAPS_ROUTES_API_KEY;

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
  if (originalGoogleRoutesApiKey === undefined) {
    delete process.env.GOOGLE_MAPS_ROUTES_API_KEY;
  } else {
    process.env.GOOGLE_MAPS_ROUTES_API_KEY = originalGoogleRoutesApiKey;
  }
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

describe('route distance validation', () => {
  it('does not apply an unapproved default distance tolerance', () => {
    delete process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
    const candidates = [route('near', 10.1), route('far', 17)];

    expect(validateAndDeduplicateCandidateRoutes(candidates, 10).map((item) => item.id))
      .toEqual(['near', 'far']);
  });

  it('applies only an explicitly configured distance tolerance', () => {
    process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM = '2';
    const candidates = [route('within', 12), route('outside', 12.01)];

    expect(validateAndDeduplicateCandidateRoutes(candidates, 10).map((item) => item.id))
      .toEqual(['within']);
  });

  it('uses the routing-engine distance instead of the supplied display distance', () => {
    delete process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
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

    expect(validateAndDeduplicateCandidateRoutes([valid, duplicate, malformed, stationary], 5).map((item) => item.id))
      .toEqual(['valid']);
  });

  it('handles short targets and filters routes only under an explicit tolerance', () => {
    delete process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM;
    expect(validateAndDeduplicateCandidateRoutes([route('short', 0.4)], 0.5)).toHaveLength(1);
    expect(validateAndDeduplicateCandidateRoutes([route('far', 17.99)], 20)).toHaveLength(1);

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

describe('Google Maps Routes API generation', () => {
  it('requests Google walking routes and measures returned geometry and distance', async () => {
    process.env.GOOGLE_MAPS_ROUTES_API_KEY = 'test-routes-key';
    const requests: RequestInit[] = [];
    vi.stubGlobal('fetch', vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
      requests.push(init ?? {});
      return new Response(JSON.stringify({
        routes: [{
          distanceMeters: 4800,
          duration: '900s',
          polyline: { encodedPolyline: '??gEgE' },
        }],
      }), { status: 200 });
    }));

    const candidates = await generateCandidateRoutes(
      'running',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    );

    expect(requests).toHaveLength(6);
    expect(JSON.parse(String(requests[0].body)).travelMode).toBe('WALK');
    expect((requests[0].headers as Record<string, string>)['X-Goog-Api-Key'])
      .toBe('test-routes-key');
    expect(candidates).toHaveLength(1);
    expect(candidates[0].distanceMeters).toBe(4800);
    expect(candidates[0].geometry.coordinates).toEqual([[0, 0], [0.001, 0.001]]);
  });

  it('uses Google bicycle mode without silently falling back to another provider', async () => {
    process.env.GOOGLE_MAPS_ROUTES_API_KEY = 'test-routes-key';
    let requestCount = 0;
    vi.stubGlobal('fetch', vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
      requestCount++;
      expect(JSON.parse(String(init?.body)).travelMode).toBe('BICYCLE');
      return new Response(JSON.stringify({
        routes: [{
          distanceMeters: 5000,
          duration: '900s',
          polyline: { encodedPolyline: '??gEgE' },
        }],
      }), { status: 200 });
    }));

    await generateCandidateRoutes(
      'cycling',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    );
    expect(requestCount).toBe(6);
  });

  it('returns an explicit no-coverage error when Google has no bicycle route', async () => {
    process.env.GOOGLE_MAPS_ROUTES_API_KEY = 'test-routes-key';
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
      error: { status: 'ROUTE_NOT_FOUND' },
    }), { status: 404 })));

    await expect(generateCandidateRoutes(
      'cycling',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    )).rejects.toThrow('Google Maps has no cycling route available');
  });

  it('requires a server-side Google Routes API key', async () => {
    delete process.env.GOOGLE_MAPS_ROUTES_API_KEY;
    await expect(generateCandidateRoutes(
      'walking',
      5,
      {},
      { latitude: 14.5995, longitude: 120.9842 },
    )).rejects.toThrow('GOOGLE_MAPS_ROUTES_API_KEY');
  });
});

describe('route ranking', () => {
  it('ranks by distance before preferences without excluding valid routes by default', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'false';
    const closest = route('closest', 9.9, { isLoop: false, majorRoadRatio: 0.9 });
    const preferredButFarther = route('preferred', 11.4, { isLoop: true, majorRoadRatio: 0 });
    const outOfRange = route('excluded', 12.01);

    const ranked = await rankCandidateRoutes(
      'running',
      10,
      { preferLoop: true, avoidMajorRoads: true },
      [preferredButFarther, outOfRange, closest]
    );

    expect(ranked.map((item) => item.id)).toEqual(['closest', 'preferred', 'excluded']);
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

  it('uses AI only as a validated tie-break and labels the ranking source', async () => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'true';
    const routes = [route('alpha', 5), route('beta', 5)];
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      routes,
      async () => ['beta', 'alpha'],
    );

    expect(ranked.map(({ id }) => id)).toEqual(['beta', 'alpha']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'ai_assisted')).toBe(true);
  });

  it('uses the AI ranker when the setting is omitted', async () => {
    delete process.env.AI_ROUTE_RANKING_ENABLED;
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('alpha', 5), route('beta', 5)],
      async () => ['beta', 'alpha'],
    );

    expect(ranked.map(({ id }) => id)).toEqual(['beta', 'alpha']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'ai_assisted')).toBe(true);
  });

  it('does not call AI to change the order of candidates with different primary scores', async () => {
    delete process.env.AI_ROUTE_RANKING_ENABLED;
    const aiRanker = vi.fn(async () => ['far', 'near']);
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('near', 5), route('far', 6)],
      aiRanker,
    );

    expect(aiRanker).not.toHaveBeenCalled();
    expect(ranked.map(({ id }) => id)).toEqual(['near', 'far']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'deterministic_fallback')).toBe(true);
  });

  it('sends only equivalent primary-score groups to AI', async () => {
    delete process.env.AI_ROUTE_RANKING_ENABLED;
    const aiRanker = vi.fn(async (
      _activity: string,
      _target: number,
      _preferLoop: boolean,
      candidates: { id: string; distanceKm: number; absoluteDeviationKm: number; isLoop: boolean }[],
    ) =>
      [...candidates].reverse().map(({ id }) => id),
    );
    const ranked = await rankCandidateRoutes(
      'running',
      5,
      {},
      [route('near', 5), route('tie-a', 6), route('tie-b', 6)],
      aiRanker,
    );

    expect(aiRanker).toHaveBeenCalledTimes(1);
    expect(aiRanker.mock.calls[0][3].map(({ id }) => id)).toEqual(['tie-a', 'tie-b']);
    expect(ranked.map(({ id }) => id)).toEqual(['near', 'tie-b', 'tie-a']);
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
        return ['beta', 'alpha'];
      },
    );

    expect(aiCalled).toBe(false);
    expect(ranked.map(({ id }) => id)).toEqual(['alpha', 'beta']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'deterministic_fallback')).toBe(true);
  });

  it.each([
    ['throws', async () => { throw new Error('service unavailable'); }],
    ['returns an unknown identifier', async () => ['missing', 'alpha']],
    ['returns duplicate identifiers', async () => ['alpha', 'alpha']],
    ['omits a candidate', async () => ['alpha']],
  ])('uses deterministic fallback when AI %s', async (_scenario, aiRanker) => {
    process.env.AI_ROUTE_RANKING_ENABLED = 'true';
    const routes = [route('alpha', 5), route('beta', 5)];
    const ranked = await rankCandidateRoutes('running', 5, {}, routes, aiRanker);

    expect(ranked.map(({ id }) => id)).toEqual(['alpha', 'beta']);
    expect(ranked.every(({ rankingSource }) => rankingSource === 'deterministic_fallback')).toBe(true);
  });
});
