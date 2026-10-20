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

const GOOGLE_ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';
const GOOGLE_ROUTE_CANDIDATE_SCALES = [0.75, 1, 1.25];

export class GoogleRoutesError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
    readonly providerStatus?: string,
  ) {
    super(message);
    this.name = 'GoogleRoutesError';
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

function getOsrmProfile(activity: string): string {
  switch (activity.toLowerCase()) {
    case 'cycling':
      return 'bike';
    case 'walking':
    case 'jogging':
    case 'running':
    default:
      return 'foot';
  }
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

function googleTravelMode(activity: string): 'WALK' | 'BICYCLE' {
  return activity.toLowerCase() === 'cycling' ? 'BICYCLE' : 'WALK';
}

function decodeGooglePolyline(encoded: string): [number, number][] {
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
          throw new Error('Google Routes API returned malformed route geometry');
        }
        byte = encoded.charCodeAt(index++) - 63;
        if (byte < 0 || byte > 0x3f) {
          throw new Error('Google Routes API returned malformed route geometry');
        }
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      deltas.push((result & 1) ? ~(result >> 1) : result >> 1);
    }
    latitude += deltas[0];
    longitude += deltas[1];
    coordinates.push([longitude / 1e5, latitude / 1e5]);
  }
  return coordinates;
}

function toWaypoint([latitude, longitude]: [number, number]) {
  return {
    location: {
      latLng: { latitude, longitude },
    },
  };
}

async function callGoogleRoutes(
  activity: string,
  coordinates: [number, number][],
): Promise<{ distanceMeters: number; durationSeconds: number; coordinates: [number, number][] } | null> {
  const apiKey = process.env.GOOGLE_MAPS_ROUTES_API_KEY?.trim();
  if (!apiKey) {
    throw new GoogleRoutesError(
      'Google Maps Routes API is not configured. Add GOOGLE_MAPS_ROUTES_API_KEY to the backend environment.',
      503,
      'MISSING_API_KEY',
    );
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  let response: Response;
  try {
    response = await fetch(GOOGLE_ROUTES_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
      },
      body: JSON.stringify({
        origin: toWaypoint(coordinates[0]),
        destination: toWaypoint(coordinates[coordinates.length - 1]),
        intermediates: coordinates.slice(1, -1).map(toWaypoint),
        travelMode: googleTravelMode(activity),
        polylineQuality: 'HIGH_QUALITY',
        polylineEncoding: 'ENCODED_POLYLINE',
        units: 'METRIC',
        languageCode: 'en',
      }),
      signal: controller.signal,
    });
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new GoogleRoutesError('Google Maps Routes API timed out. Retry route planning.', 504, 'TIMEOUT');
    }
    throw new GoogleRoutesError('Could not connect to Google Maps Routes API.', 503, 'NETWORK_ERROR');
  } finally {
    clearTimeout(timeout);
  }

  const payload = await response.json().catch(() => ({})) as {
    routes?: Array<{
      distanceMeters?: number;
      duration?: string;
      polyline?: { encodedPolyline?: string };
    }>;
    error?: { status?: string; message?: string };
  };
  if (!response.ok) {
    const status = payload.error?.status ?? 'PROVIDER_ERROR';
    const message = status === 'ROUTE_NOT_FOUND'
      ? `Google Maps has no ${googleTravelMode(activity) === 'BICYCLE' ? 'cycling' : 'walking'} route available for this area.`
      : 'Google Maps Routes API could not generate a route. Check the API key, enabled APIs, billing, and coverage.';
    throw new GoogleRoutesError(message, response.status, status);
  }

  const route = payload.routes?.[0];
  const encodedPolyline = route?.polyline?.encodedPolyline;
  if (!route || !Number.isFinite(route.distanceMeters) || !encodedPolyline) return null;
  const durationSeconds = Number.parseFloat(route.duration ?? '');
  if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) {
    throw new Error('Google Routes API returned an invalid route duration');
  }

  return {
    distanceMeters: route.distanceMeters!,
    durationSeconds,
    coordinates: decodeGooglePolyline(encodedPolyline),
  };
}

export async function generateCandidateRoutes(
  activity: string,
  targetDistanceKm: number,
  preferences: RoutePreferences,
  startLocation: StartLocation
): Promise<CandidateRoute[]> {
  const start: [number, number] = [startLocation.latitude, startLocation.longitude];
  const constructionScales = GOOGLE_ROUTE_CANDIDATE_SCALES;
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
      name: `Google Maps ${candidate.name} (${scale}x)`,
    }));
  });

  const results = await Promise.allSettled(
    candidateConfigs.map(async (config) => ({
      config,
      route: await callGoogleRoutes(activity, config.coords),
    })),
  );
  const successfulResults = results.flatMap((result) =>
    result.status === 'fulfilled' && result.value.route ? [result.value] : [],
  );
  const failures = results.filter(
    (result): result is PromiseRejectedResult => result.status === 'rejected',
  );
  if (successfulResults.length > 0 && failures.length > 0) {
    console.warn(`Google Maps returned ${successfulResults.length} candidates; ${failures.length} candidate requests failed.`);
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
