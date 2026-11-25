import { globalRouteQueue } from './routeQueueService.js';

export interface StartLocation {
  latitude: number;
  longitude: number;
}

export interface RoutePreferences {
  avoidMajorRoads?: boolean;
  preferSidewalks?: boolean;
  preferLoop?: boolean;
  preferCyclingInfrastructure?: boolean;
  avoidHills?: boolean;
}

export interface CandidateRoute {
  id: string;
  name: string;
  activityType: string;
  distanceKm: number;
  distanceMeters: number;
  durationSeconds: number;
  geometry: {
    type: 'LineString';
    coordinates: [number, number][]; // [lon, lat]
  };
  features: {
    distanceDeltaKm: number;
    isLoop: boolean;
    sidewalkRatio?: number;
    majorRoadRatio?: number;
    cyclingLaneRatio?: number;
    roadTypes: string[];
    elevationGainM?: number;
  };
}

const CANDIDATE_SCALES = [0.75, 1, 1.25];
const APPROVED_ADJUSTMENT_SCALES = new Set([0.5, 0.9, 1.1, 1.5]);
const DEFAULT_MAX_DISTANCE_DEVIATION_KM = 0.5;
const MAX_GEOMETRY_GAP_KM = 5;
const MAX_SUMMARY_GEOMETRY_DRIFT_RATIO = 0.15;

export interface CandidateGenerationOptions {
  additionalScales?: number[];
  onlyAdditionalScales?: boolean;
  targetDistanceToleranceKm?: number;
}

export class RoutingServiceError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
    readonly providerStatus?: string,
  ) {
    super(message);
    this.name = 'RoutingServiceError';
  }
}

export function getMaximumDistanceDeviationKm(overrideToleranceKm?: number): number {
  if (typeof overrideToleranceKm === 'number' && Number.isFinite(overrideToleranceKm) && overrideToleranceKm > 0) {
    return overrideToleranceKm;
  }
  const configuredValue = process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM?.trim();
  if (!configuredValue) return DEFAULT_MAX_DISTANCE_DEVIATION_KM;

  const maximumDeviationKm = Number(configuredValue);
  if (!Number.isFinite(maximumDeviationKm) || maximumDeviationKm <= 0) {
    throw new Error('ROUTE_MAX_DISTANCE_DEVIATION_KM must be a positive number');
  }
  return maximumDeviationKm;
}

function haversineDistanceKm([lon1, lat1]: [number, number], [lon2, lat2]: [number, number]): number {
  const toRadians = Math.PI / 180;
  const deltaLat = (lat2 - lat1) * toRadians;
  const deltaLon = (lon2 - lon1) * toRadians;
  const a = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1 * toRadians) * Math.cos(lat2 * toRadians) * Math.sin(deltaLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function isValidGeometry(coordinates: unknown): coordinates is [number, number][] {
  if (!Array.isArray(coordinates) || coordinates.length < 2) return false;

  let hasMovement = false;
  let previous: [number, number] | undefined;
  for (const point of coordinates) {
    if (
      !Array.isArray(point) ||
      point.length < 2 ||
      typeof point[0] !== 'number' ||
      typeof point[1] !== 'number' ||
      !Number.isFinite(point[0]) ||
      !Number.isFinite(point[1]) ||
      point[0] < -180 ||
      point[0] > 180 ||
      point[1] < -90 ||
      point[1] > 90
    ) {
      return false;
    }

    const coordinate: [number, number] = [point[0], point[1]];
    if (previous) {
      const segmentDistanceKm = haversineDistanceKm(previous, coordinate);
      if (segmentDistanceKm === 0 || segmentDistanceKm > MAX_GEOMETRY_GAP_KM) return false;
      hasMovement = true;
    }
    previous = coordinate;
  }
  return hasMovement;
}

function geometryDistanceKm(coordinates: [number, number][]): number {
  return coordinates.slice(1).reduce(
    (total, point, index) => total + haversineDistanceKm(coordinates[index], point),
    0,
  );
}

function geometryFingerprint(coordinates: [number, number][]): string {
  const samples = Array.from({ length: Math.min(12, coordinates.length) }, (_, index) => {
    const coordinateIndex = Math.round(index * (coordinates.length - 1) / (Math.min(12, coordinates.length) - 1));
    const [longitude, latitude] = coordinates[coordinateIndex];
    return `${longitude.toFixed(3)},${latitude.toFixed(3)}`;
  });
  const reversed = [...samples].reverse();
  return samples.join(';') < reversed.join(';') ? samples.join(';') : reversed.join(';');
}

function averageSampleSeparationKm(
  first: [number, number][],
  second: [number, number][],
): number {
  const sampleCount = Math.min(12, first.length, second.length);
  if (sampleCount === 0) return 0;
  let separation = 0;
  for (let index = 0; index < sampleCount; index++) {
    const firstIndex = Math.round(index * (first.length - 1) / (sampleCount - 1));
    const secondIndex = Math.round(index * (second.length - 1) / (sampleCount - 1));
    const firstCoordinate = first[firstIndex];
    const secondCoordinate = second[secondIndex];
    separation += haversineDistanceKm(firstCoordinate, secondCoordinate);
  }
  return separation / sampleCount;
}

/**
 * Treat the routing engine's distance as authoritative; never qualify a route
 * from its requested waypoints or its rounded display distance.
 */
export function validateAndDeduplicateCandidateRoutes(
  routes: CandidateRoute[],
  targetDistanceKm: number,
  options: { enforceDistanceTolerance?: boolean; targetDistanceToleranceKm?: number } = {},
): CandidateRoute[] {
  if (!Number.isFinite(targetDistanceKm) || targetDistanceKm <= 0) return [];

  const maximumDistanceDeviationKm = getMaximumDistanceDeviationKm(options.targetDistanceToleranceKm);
  const seenGeometries = new Set<string>();
  const seenIds = new Set<string>();
  const validRoutes: CandidateRoute[] = [];

  for (const route of routes) {
    if (
      !route ||
      typeof route !== 'object' ||
      typeof route.id !== 'string' ||
      !/^[A-Za-z0-9_-]{1,100}$/.test(route.id) ||
      seenIds.has(route.id)
    ) continue;
    const distanceMeters = route.distanceMeters;
    if (
      !Number.isFinite(distanceMeters) ||
      distanceMeters <= 0 ||
      !route.geometry ||
      route.geometry.type !== 'LineString' ||
      !isValidGeometry(route.geometry.coordinates)
    ) {
      continue;
    }

    const distanceKm = distanceMeters / 1000;
    const distanceDeltaKm = Math.abs(distanceKm - targetDistanceKm);
    if (
      options.enforceDistanceTolerance !== false &&
      maximumDistanceDeviationKm !== undefined &&
      distanceDeltaKm > maximumDistanceDeviationKm
    ) continue;

    const fingerprint = geometryFingerprint(route.geometry.coordinates);
    if (seenGeometries.has(fingerprint)) continue;
    if (validRoutes.some((selected) =>
      averageSampleSeparationKm(
        route.geometry.coordinates,
        selected.geometry.coordinates,
      ) < 0.10
    )) continue;
    seenGeometries.add(fingerprint);
    seenIds.add(route.id);
    const features = route.features ?? {} as CandidateRoute['features'];

    validRoutes.push({
      ...route,
      distanceKm,
      features: {
        ...features,
        distanceDeltaKm,
        isLoop: Boolean(features.isLoop),
        roadTypes: Array.isArray(features.roadTypes) ? features.roadTypes : [],
        sidewalkRatio: typeof features.sidewalkRatio === 'number' && Number.isFinite(features.sidewalkRatio)
          ? features.sidewalkRatio
          : undefined,
        majorRoadRatio: typeof features.majorRoadRatio === 'number' && Number.isFinite(features.majorRoadRatio)
          ? features.majorRoadRatio
          : undefined,
        cyclingLaneRatio: typeof features.cyclingLaneRatio === 'number' && Number.isFinite(features.cyclingLaneRatio)
          ? features.cyclingLaneRatio
          : undefined,
        elevationGainM: typeof features.elevationGainM === 'number' && Number.isFinite(features.elevationGainM)
          ? features.elevationGainM
          : undefined,
      },
    });
  }

  return validRoutes;
}

/**
 * Calculates a destination coordinate given start point, distance (km), and bearing (degrees).
 */
function destinationPoint(lat: number, lon: number, distanceKm: number, bearingDeg: number): [number, number] {
  const R = 6371; // Earth radius in km
  const rad = Math.PI / 180;
  const lat1 = lat * rad;
  const lon1 = lon * rad;
  const brng = bearingDeg * rad;

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(distanceKm / R) +
    Math.cos(lat1) * Math.sin(distanceKm / R) * Math.cos(brng)
  );

  const lon2 = lon1 + Math.atan2(
    Math.sin(brng) * Math.sin(distanceKm / R) * Math.cos(lat1),
    Math.cos(distanceKm / R) - Math.sin(lat1) * Math.sin(lat2)
  );

  return [lat2 / rad, lon2 / rad];
}

// ── Valhalla integration ────────────────────────────────────────────────────

/**
 * Maps Karipa activity types to Valhalla costing models.
 * Pedestrian costing is used for walking, jogging, and running.
 * Bicycle costing is used for cycling.
 */
function valhallaCosting(activity: string): 'pedestrian' | 'bicycle' {
  return activity.toLowerCase() === 'cycling' ? 'bicycle' : 'pedestrian';
}

/**
 * Decodes a Valhalla encoded polyline (precision 6) into GeoJSON [lon, lat] coordinates.
 * Valhalla uses the standard Google polyline algorithm with 10^6 precision.
 */
function decodeValhallaPolyline(encoded: string): [number, number][] {
  const coordinates: [number, number][] = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;

  while (index < encoded.length) {
    const deltas: number[] = [];
    for (let axis = 0; axis < 2; axis++) {
      let result = 0;
      let shift = 0;
      let byte: number;
      do {
        if (index >= encoded.length || shift > 30) {
          throw new Error('Valhalla returned malformed route geometry');
        }
        byte = encoded.charCodeAt(index++) - 63;
        if (byte < 0 || byte > 0x3f) {
          throw new Error('Valhalla returned malformed route geometry');
        }
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      deltas.push((result & 1) ? ~(result >> 1) : result >> 1);
    }
    latitude += deltas[0];
    longitude += deltas[1];
    // Output as [lon, lat] for GeoJSON format
    coordinates.push([longitude / 1e6, latitude / 1e6]);
  }
  return coordinates;
}

interface ValhallaLocation {
  lat: number;
  lon: number;
  type: 'break' | 'through';
  radius: number;
}

function toValhallaLocation(
  [latitude, longitude]: [number, number],
  type: 'break' | 'through' = 'break',
): ValhallaLocation {
  return { lat: latitude, lon: longitude, type, radius: 150 };
}

interface ValhallaResponse {
  trip?: {
    legs?: Array<{
      shape?: string;
      summary?: {
        length?: number;
        time?: number;
      };
    }>;
    summary?: {
      length?: number;
      time?: number;
    };
    status?: number;
    status_message?: string;
  };
  error_code?: number;
  error?: string;
}

async function callValhalla(
  activity: string,
  coordinates: [number, number][], // [lat, lon] pairs
  preferences: RoutePreferences,
  options: { jobId?: string; signal?: AbortSignal } = {},
): Promise<{ distanceMeters: number; durationSeconds: number; coordinates: [number, number][] } | null> {
  const baseUrl = process.env.VALHALLA_BASE_URL?.trim();
  if (!baseUrl) {
    throw new RoutingServiceError(
      'Valhalla routing service is not configured. Add VALHALLA_BASE_URL to the backend environment.',
      503,
      'MISSING_CONFIGURATION',
    );
  }

  const performFetch = async (signal?: AbortSignal) => {
    const costing = valhallaCosting(activity);
    const locations = coordinates.map((coord, index) => {
      const isEndpoint = index === 0 || index === coordinates.length - 1;
      return toValhallaLocation(coord, isEndpoint ? 'break' : 'through');
    });

    const costingOptions: Record<string, number> = {};
    if (preferences.avoidHills) costingOptions.use_hills = 0.2;
    if (costing === 'pedestrian' && preferences.preferSidewalks) {
      costingOptions.sidewalk_factor = 0.5;
    }
    if (costing === 'bicycle' && preferences.avoidMajorRoads) {
      costingOptions.use_roads = 0.2;
    }
    if (costing === 'bicycle' && preferences.preferCyclingInfrastructure) {
      costingOptions.use_roads = Math.min(costingOptions.use_roads ?? 1, 0.3);
      costingOptions.use_trails = 0.7;
    }

    const requestBody = {
      locations,
      costing,
      ...(Object.keys(costingOptions).length > 0 && {
        costing_options: { [costing]: costingOptions },
      }),
      units: 'kilometers',
      directions_type: 'none',
    };

    let response: Response;
    try {
      response = await fetch(`${baseUrl}/route`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
        signal: signal ?? options.signal ?? AbortSignal.timeout(10000),
      });
    } catch (error) {
      if (
        error instanceof Error &&
        (error.name === 'AbortError' || error.name === 'TimeoutError')
      ) {
        throw new RoutingServiceError(
          'Valhalla routing service timed out. Retry route planning.',
          504,
          'TIMEOUT',
        );
      }
      throw new RoutingServiceError(
        'Could not connect to Valhalla routing service.',
        503,
        'NETWORK_ERROR',
      );
    }

    if (response.status === 429) {
      const retryAfter = response.headers.get('Retry-After');
      globalRouteQueue.handleRateLimit429(retryAfter);
      throw new RoutingServiceError(
        'Valhalla routing service rate limit exceeded. Please retry in a few moments.',
        429,
        'RATE_LIMIT_EXCEEDED',
      );
    }

    let rawPayload: unknown;
    try {
      rawPayload = await response.json();
    } catch {
      throw new RoutingServiceError(
        'Valhalla returned an unreadable response.',
        502,
        'INVALID_RESPONSE',
      );
    }
    if (!rawPayload || typeof rawPayload !== 'object') {
      throw new RoutingServiceError(
        'Valhalla returned an invalid response.',
        502,
        'INVALID_RESPONSE',
      );
    }
    const payload = rawPayload as ValhallaResponse;

    if (!response.ok) {
      const errorCode = payload.error_code;
      const errorMessage = payload.error ?? 'Unknown routing error';

      if (errorCode === 170 || errorCode === 171 || errorCode === 442) {
        const activityLabel = costing === 'bicycle' ? 'cycling' : 'walking';
        throw new RoutingServiceError(
          `No ${activityLabel} route is available for this area.`,
          404,
          'ROUTE_NOT_FOUND',
        );
      }

      if (errorCode === 154) {
        throw new RoutingServiceError(
          'The requested route distance exceeds the routing service limit. Try a shorter distance.',
          400,
          'DISTANCE_EXCEEDED',
        );
      }

      throw new RoutingServiceError(
        `Valhalla routing service error: ${errorMessage}`,
        response.status >= 400 && response.status < 600 ? response.status : 502,
        `VALHALLA_${errorCode ?? 'ERROR'}`,
      );
    }

    const trip = payload.trip;
    if (
      !trip?.legs ||
      trip.legs.length === 0 ||
      trip.legs.some((leg) => !leg || typeof leg !== 'object' ||
        (leg.shape !== undefined && typeof leg.shape !== 'string'))
    ) {
      throw new RoutingServiceError(
        'Valhalla returned no route geometry for this request.',
        502,
        'INVALID_RESPONSE',
      );
    }

    let allCoordinates: [number, number][] = [];
    for (const leg of trip.legs) {
      if (!leg.shape) continue;
      const legCoords = decodeValhallaPolyline(leg.shape);
      if (allCoordinates.length > 0 && legCoords.length > 0) {
        allCoordinates = allCoordinates.concat(legCoords.slice(1));
      } else {
        allCoordinates = allCoordinates.concat(legCoords);
      }
    }

    const distanceKm = trip.summary?.length;
    const durationSeconds = trip.summary?.time;

    if (!Number.isFinite(distanceKm) || !distanceKm || distanceKm <= 0) {
      throw new RoutingServiceError(
        'Valhalla returned an invalid route distance.',
        502,
        'INVALID_RESPONSE',
      );
    }
    if (!Number.isFinite(durationSeconds) || !durationSeconds || durationSeconds <= 0) {
      throw new RoutingServiceError(
        'Valhalla returned an invalid route duration.',
        502,
        'INVALID_RESPONSE',
      );
    }
    if (!isValidGeometry(allCoordinates)) {
      throw new RoutingServiceError(
        'Valhalla returned invalid or discontinuous route geometry.',
        502,
        'INVALID_GEOMETRY',
      );
    }
    const shapeDistanceKm = geometryDistanceKm(allCoordinates);
    const distanceDriftRatio = Math.abs(shapeDistanceKm - distanceKm) / distanceKm;
    if (distanceDriftRatio > MAX_SUMMARY_GEOMETRY_DRIFT_RATIO) {
      throw new RoutingServiceError(
        'Valhalla route geometry does not match its reported distance closely enough to be considered factual.',
        502,
        'DISTANCE_GEOMETRY_MISMATCH',
      );
    }
    const start = coordinates[0];
    if (
      haversineDistanceKm(start, [allCoordinates[0][1], allCoordinates[0][0]]) > 0.5 ||
      haversineDistanceKm(start, [
        allCoordinates[allCoordinates.length - 1][1],
        allCoordinates[allCoordinates.length - 1][0],
      ]) > 0.5
    ) {
      throw new RoutingServiceError(
        'Valhalla could not snap both route endpoints near the requested start location.',
        422,
        'ENDPOINT_SNAP_FAILED',
      );
    }

    return {
      distanceMeters: Math.round(distanceKm * 1000),
      durationSeconds: Math.round(durationSeconds),
      coordinates: allCoordinates,
    };
  };

  const activeJobId = options.jobId || globalRouteQueue.createJob().id;
  return globalRouteQueue.enqueue(activeJobId, (signal) => performFetch(signal));
}

export async function generateCandidateRoutes(
  activity: string,
  targetDistanceKm: number,
  preferences: RoutePreferences,
  startLocation: StartLocation,
  options: CandidateGenerationOptions & { jobId?: string } = {},
): Promise<CandidateRoute[]> {
  const cacheKey = globalRouteQueue.generateCacheKey(
    activity,
    targetDistanceKm,
    startLocation,
    preferences,
    options,
  );

  const cachedRoutes = globalRouteQueue.getCachedRoute<CandidateRoute[]>(cacheKey, startLocation);
  if (cachedRoutes && cachedRoutes.length > 0) {
    return cachedRoutes;
  }

  const start: [number, number] = [startLocation.latitude, startLocation.longitude];
  const activeJobId = options.jobId || globalRouteQueue.createJob().id;
  const toleranceKm = getMaximumDistanceDeviationKm(options.targetDistanceToleranceKm);

  let stages: number[][];
  if (options.onlyAdditionalScales && options.additionalScales?.length) {
    stages = [options.additionalScales];
  } else if (options.additionalScales?.length) {
    stages = [[1.0], options.additionalScales];
  } else {
    stages = [[1.0], [0.75, 1.25], [0.9, 1.1]];
  }

  const accumulatedRawResults: Array<{ config: { name: string; isLoop: boolean }; route: any }> = [];
  const failures: PromiseRejectedResult[] = [];

  for (let stageIdx = 0; stageIdx < stages.length; stageIdx++) {
    const activeJob = globalRouteQueue.getJob(activeJobId);
    if (!activeJob || activeJob.status === 'cancelled' || activeJob.status === 'expired') {
      return [];
    }

    const stageScales = stages[stageIdx];
    const stageConfigs = stageScales.flatMap((scale) => {
      const constructionDistanceKm = targetDistanceKm * scale;
      const loopRadiusKm = Math.max(0.1, constructionDistanceKm / (2 * Math.PI));
      const outAndBackRadiusKm = Math.max(0.15, (constructionDistanceKm / 2) * 0.9);
      const bearings = [30, 120, 210, 300];
      const loopPoints = bearings.map((bearing) => destinationPoint(...start, loopRadiusKm, bearing));
      const outAndBackPoint = destinationPoint(...start, outAndBackRadiusKm, 45);

      return [
        { name: 'Generated loop', coords: [start, ...loopPoints, start], isLoop: true },
        { name: 'Generated out-and-back', coords: [start, outAndBackPoint, start], isLoop: false },
      ].map((candidate) => ({
        ...candidate,
        name: `Valhalla ${candidate.name} (${scale}x)`,
      }));
    });

    const results = await Promise.allSettled(
      stageConfigs.map(async (config) => ({
        config,
        route: await callValhalla(activity, config.coords, preferences, { jobId: activeJobId }),
      })),
    );

    for (const result of results) {
      if (result.status === 'fulfilled' && result.value.route) {
        accumulatedRawResults.push(result.value);
      } else if (result.status === 'rejected') {
        failures.push(result);
      }
    }

    // Convert accumulated raw results to candidate routes and validate/deduplicate
    const candidates: CandidateRoute[] = accumulatedRawResults.map(({ config, route }, idx) => ({
      id: `route-${idx + 1}`,
      name: config.name,
      activityType: activity,
      distanceKm: route.distanceMeters / 1000,
      distanceMeters: route.distanceMeters,
      durationSeconds: Math.round(route.durationSeconds),
      geometry: {
        type: 'LineString',
        coordinates: route.coordinates,
      },
      features: {
        distanceDeltaKm: Number(Math.abs(route.distanceMeters / 1000 - targetDistanceKm).toFixed(2)),
        isLoop: config.isLoop,
        roadTypes: [],
      },
    }));

    const validCandidates = validateAndDeduplicateCandidateRoutes(candidates, targetDistanceKm, {
      enforceDistanceTolerance: false,
      targetDistanceToleranceKm: toleranceKm,
    });

    const acceptableCandidates = validCandidates.filter(
      (c) => Math.abs(c.distanceKm - targetDistanceKm) <= toleranceKm,
    ).filter((candidate) => {
      if (preferences.preferLoop && !candidate.features.isLoop) return false;
      if (activity.toLowerCase() === 'cycling' && preferences.avoidMajorRoads &&
        candidate.features.majorRoadRatio !== undefined &&
        candidate.features.majorRoadRatio >= 0.15) return false;
      if (preferences.preferSidewalks &&
        candidate.features.sidewalkRatio !== undefined &&
        candidate.features.sidewalkRatio < 0.5) return false;
      if (activity.toLowerCase() === 'cycling' && preferences.preferCyclingInfrastructure &&
        candidate.features.cyclingLaneRatio !== undefined &&
        candidate.features.cyclingLaneRatio < 0.5) return false;
      return true;
    }).slice(0, 5);

    // Stop early if we have at least 5 acceptable candidates or reached last stage
    if (acceptableCandidates.length >= 5 || stageIdx === stages.length - 1) {
      const activeJobAfterStage = globalRouteQueue.getJob(activeJobId);
      if (!activeJobAfterStage || activeJobAfterStage.status === 'cancelled' || activeJobAfterStage.status === 'expired') {
        return [];
      }
      const bestValidCandidates = validCandidates.slice(0, 5);
      if (bestValidCandidates.length > 0) {
        globalRouteQueue.setCachedRoute(cacheKey, startLocation, bestValidCandidates);
      } else if (failures.length > 0 && accumulatedRawResults.length === 0) {
        throw failures[0].reason;
      }
      return bestValidCandidates;
    }
  }

  if (failures.length > 0 && accumulatedRawResults.length === 0) {
    throw failures[0].reason;
  }

  return [];
}
