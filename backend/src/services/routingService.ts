export interface StartLocation {
  latitude: number;
  longitude: number;
}

export interface RoutePreferences {
  avoidMajorRoads?: boolean;
  preferSidewalks?: boolean;
  preferLoop?: boolean;
  preferCyclingInfrastructure?: boolean;
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

function getMaximumDistanceDeviationKm(): number | undefined {
  const configuredValue = process.env.ROUTE_MAX_DISTANCE_DEVIATION_KM?.trim();
  if (!configuredValue) return undefined;

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
    if (previous && haversineDistanceKm(previous, coordinate) > 0) hasMovement = true;
    previous = coordinate;
  }
  return hasMovement;
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

/**
 * Treat the routing engine's distance as authoritative; never qualify a route
 * from its requested waypoints or its rounded display distance.
 */
export function validateAndDeduplicateCandidateRoutes(
  routes: CandidateRoute[],
  targetDistanceKm: number
): CandidateRoute[] {
  if (!Number.isFinite(targetDistanceKm) || targetDistanceKm <= 0) return [];

  const maximumDistanceDeviationKm = getMaximumDistanceDeviationKm();
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
      maximumDistanceDeviationKm !== undefined &&
      distanceDeltaKm > maximumDistanceDeviationKm
    ) continue;

    const fingerprint = geometryFingerprint(route.geometry.coordinates);
    if (seenGeometries.has(fingerprint)) continue;
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
}

function toValhallaLocation(
  [latitude, longitude]: [number, number],
  type: 'break' | 'through' = 'break',
): ValhallaLocation {
  return { lat: latitude, lon: longitude, type };
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
): Promise<{ distanceMeters: number; durationSeconds: number; coordinates: [number, number][] } | null> {
  const baseUrl = process.env.VALHALLA_BASE_URL?.trim();
  if (!baseUrl) {
    throw new RoutingServiceError(
      'Valhalla routing service is not configured. Add VALHALLA_BASE_URL to the backend environment.',
      503,
      'MISSING_CONFIGURATION',
    );
  }

  const costing = valhallaCosting(activity);

  // First and last locations are "break" (stop/leg boundary);
  // intermediate locations are "through" (pass-through waypoints).
  const locations = coordinates.map((coord, index) => {
    const isEndpoint = index === 0 || index === coordinates.length - 1;
    return toValhallaLocation(coord, isEndpoint ? 'break' : 'through');
  });

  const requestBody = {
    locations,
    costing,
    units: 'kilometers',
    directions_type: 'none', // Only need shape and summary, not turn-by-turn
  };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  let response: Response;
  try {
    response = await fetch(`${baseUrl}/route`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
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
  } finally {
    clearTimeout(timeout);
  }

  const payload = (await response.json().catch(() => ({}))) as ValhallaResponse;

  if (!response.ok) {
    const errorCode = payload.error_code;
    const errorMessage = payload.error ?? 'Unknown routing error';

    // Error codes 170/171: No path could be found for the input
    if (errorCode === 170 || errorCode === 171 || errorCode === 442) {
      const activityLabel = costing === 'bicycle' ? 'cycling' : 'walking';
      throw new RoutingServiceError(
        `No ${activityLabel} route is available for this area.`,
        404,
        'ROUTE_NOT_FOUND',
      );
    }

    // Error code 154: Path distance exceeds max limit
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
  if (!trip?.legs || trip.legs.length === 0) return null;

  // Combine decoded shape from all legs (handles multi-leg responses)
  let allCoordinates: [number, number][] = [];
  for (const leg of trip.legs) {
    if (!leg.shape) continue;
    const legCoords = decodeValhallaPolyline(leg.shape);
    if (allCoordinates.length > 0 && legCoords.length > 0) {
      // Skip first point of subsequent legs to avoid duplicate junction points
      allCoordinates = allCoordinates.concat(legCoords.slice(1));
    } else {
      allCoordinates = allCoordinates.concat(legCoords);
    }
  }

  const distanceKm = trip.summary?.length;
  const durationSeconds = trip.summary?.time;

  if (!Number.isFinite(distanceKm) || !distanceKm || distanceKm <= 0) return null;
  if (!Number.isFinite(durationSeconds) || !durationSeconds || durationSeconds <= 0) {
    throw new Error('Valhalla returned an invalid route duration');
  }

  return {
    distanceMeters: Math.round(distanceKm * 1000),
    durationSeconds: Math.round(durationSeconds),
    coordinates: allCoordinates,
  };
}

export async function generateCandidateRoutes(
  activity: string,
  targetDistanceKm: number,
  preferences: RoutePreferences,
  startLocation: StartLocation
): Promise<CandidateRoute[]> {
  const start: [number, number] = [startLocation.latitude, startLocation.longitude];
  const constructionScales = CANDIDATE_SCALES;
  const candidateConfigs = constructionScales.flatMap((scale) => {
    const constructionDistanceKm = targetDistanceKm * scale;
    const loopRadiusKm = Math.max(0.1, constructionDistanceKm / (2 * Math.PI));
    const outAndBackRadiusKm = Math.max(0.15, (constructionDistanceKm / 2) * 0.9);
    const p1 = destinationPoint(...start, loopRadiusKm, 30);
    const p2 = destinationPoint(...start, loopRadiusKm, 150);
    const p3 = destinationPoint(...start, loopRadiusKm, 270);
    const w1 = destinationPoint(...start, outAndBackRadiusKm, 45);

    return [
      { name: 'Generated loop', coords: [start, p1, p2, p3, start], isLoop: true },
      { name: 'Generated out-and-back', coords: [start, w1, start], isLoop: false },
    ].map((candidate) => ({
      ...candidate,
      name: `Valhalla ${candidate.name} (${scale}x)`,
    }));
  });

  const results = await Promise.allSettled(
    candidateConfigs.map(async (config) => ({
      config,
      route: await callValhalla(activity, config.coords),
    })),
  );
  const successfulResults = results.flatMap((result) =>
    result.status === 'fulfilled' && result.value.route ? [result.value] : [],
  );
  const failures = results.filter(
    (result): result is PromiseRejectedResult => result.status === 'rejected',
  );
  if (successfulResults.length > 0 && failures.length > 0) {
    console.warn(`Valhalla returned ${successfulResults.length} candidates; ${failures.length} candidate requests failed.`);
  }
  if (successfulResults.length === 0 && failures.length > 0) {
    throw failures[0].reason;
  }

  const candidates: CandidateRoute[] = [];
  for (const { config, route } of successfulResults) {
    if (route && route.coordinates.length >= 2) {
      const distanceMeters = route.distanceMeters;
      const distanceKm = distanceMeters / 1000;
      const durationSeconds = Math.round(route.durationSeconds);

      candidates.push({
        id: `route-${candidates.length + 1}`,
        name: config.name,
        activityType: activity,
        distanceKm,
        distanceMeters,
        durationSeconds,
        geometry: {
          type: 'LineString',
          coordinates: route.coordinates,
        },
        features: {
          distanceDeltaKm: Number(Math.abs(distanceKm - targetDistanceKm).toFixed(2)),
          isLoop: config.isLoop,
          roadTypes: [],
        },
      });
    }
  }

  return validateAndDeduplicateCandidateRoutes(candidates, targetDistanceKm);
}
