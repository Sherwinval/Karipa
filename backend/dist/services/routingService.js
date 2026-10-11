const MAX_DISTANCE_DEVIATION_KM = 2;
const DEFAULT_OSRM_URL = 'https://router.project-osrm.org';
function haversineDistanceKm([lon1, lat1], [lon2, lat2]) {
    const toRadians = Math.PI / 180;
    const deltaLat = (lat2 - lat1) * toRadians;
    const deltaLon = (lon2 - lon1) * toRadians;
    const a = Math.sin(deltaLat / 2) ** 2 +
        Math.cos(lat1 * toRadians) * Math.cos(lat2 * toRadians) * Math.sin(deltaLon / 2) ** 2;
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
function isValidGeometry(coordinates) {
    if (!Array.isArray(coordinates) || coordinates.length < 2)
        return false;
    let hasMovement = false;
    let previous;
    for (const point of coordinates) {
        if (!Array.isArray(point) ||
            point.length < 2 ||
            typeof point[0] !== 'number' ||
            typeof point[1] !== 'number' ||
            !Number.isFinite(point[0]) ||
            !Number.isFinite(point[1]) ||
            point[0] < -180 ||
            point[0] > 180 ||
            point[1] < -90 ||
            point[1] > 90) {
            return false;
        }
        const coordinate = [point[0], point[1]];
        if (previous && haversineDistanceKm(previous, coordinate) > 0)
            hasMovement = true;
        previous = coordinate;
    }
    return hasMovement;
}
function geometryFingerprint(coordinates) {
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
export function validateAndDeduplicateCandidateRoutes(routes, targetDistanceKm) {
    if (!Number.isFinite(targetDistanceKm) || targetDistanceKm < 0)
        return [];
    const minimumDistanceKm = Math.max(0, targetDistanceKm - MAX_DISTANCE_DEVIATION_KM);
    const maximumDistanceKm = targetDistanceKm + MAX_DISTANCE_DEVIATION_KM;
    const seenGeometries = new Set();
    const validRoutes = [];
    for (const route of routes) {
        if (!route || typeof route !== 'object')
            continue;
        const distanceMeters = route.distanceMeters;
        if (!Number.isFinite(distanceMeters) ||
            distanceMeters <= 0 ||
            !route.geometry ||
            route.geometry.type !== 'LineString' ||
            !isValidGeometry(route.geometry.coordinates)) {
            continue;
        }
        const distanceKm = distanceMeters / 1000;
        if (distanceKm < minimumDistanceKm || distanceKm > maximumDistanceKm)
            continue;
        const fingerprint = geometryFingerprint(route.geometry.coordinates);
        if (seenGeometries.has(fingerprint))
            continue;
        seenGeometries.add(fingerprint);
        const features = route.features ?? {};
        validRoutes.push({
            ...route,
            distanceKm,
            features: {
                ...features,
                distanceDeltaKm: Math.abs(distanceKm - targetDistanceKm),
                isLoop: Boolean(features.isLoop),
                sidewalkRatio: Number.isFinite(features.sidewalkRatio) ? features.sidewalkRatio : 0,
                majorRoadRatio: Number.isFinite(features.majorRoadRatio) ? features.majorRoadRatio : 1,
                cyclingLaneRatio: Number.isFinite(features.cyclingLaneRatio) ? features.cyclingLaneRatio : 0,
                roadTypes: Array.isArray(features.roadTypes) ? features.roadTypes : [],
                elevationGainM: Number.isFinite(features.elevationGainM) ? features.elevationGainM : undefined,
            },
        });
    }
    return validRoutes;
}
function getOsrmProfile(activity) {
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
function destinationPoint(lat, lon, distanceKm, bearingDeg) {
    const R = 6371; // Earth radius in km
    const rad = Math.PI / 180;
    const lat1 = lat * rad;
    const lon1 = lon * rad;
    const brng = bearingDeg * rad;
    const lat2 = Math.asin(Math.sin(lat1) * Math.cos(distanceKm / R) +
        Math.cos(lat1) * Math.sin(distanceKm / R) * Math.cos(brng));
    const lon2 = lon1 + Math.atan2(Math.sin(brng) * Math.sin(distanceKm / R) * Math.cos(lat1), Math.cos(distanceKm / R) - Math.sin(lat1) * Math.sin(lat2));
    return [lat2 / rad, lon2 / rad];
}
let _resolvedBaseUrl = null;
async function getWorkingOsrmBaseUrl() {
    if (_resolvedBaseUrl)
        return _resolvedBaseUrl;
    const localUrl = process.env.OSRM_URL;
    if (localUrl && !localUrl.includes('project-osrm.org')) {
        try {
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), 1200);
            const test = await fetch(`${localUrl.replace(/\/+$/, '')}/health`, { signal: controller.signal });
            clearTimeout(timeout);
            if (test.ok) {
                _resolvedBaseUrl = localUrl.replace(/\/+$/, '');
                return _resolvedBaseUrl;
            }
        }
        catch {
            // Local not running, use public OSRM
        }
    }
    _resolvedBaseUrl = DEFAULT_OSRM_URL;
    return _resolvedBaseUrl;
}
async function callOsrm(profile, coordinates) {
    const coordString = coordinates.map(([lat, lon]) => `${lon.toFixed(6)},${lat.toFixed(6)}`).join(';');
    const baseUrl = await getWorkingOsrmBaseUrl();
    try {
        const url = `${baseUrl}/route/v1/${profile}/${coordString}?overview=full&geometries=geojson&steps=true&annotations=true`;
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 6000);
        const resp = await fetch(url, { signal: controller.signal });
        clearTimeout(timeout);
        if (resp.ok) {
            const json = await resp.json();
            if (json.code === 'Ok' && json.routes && json.routes.length > 0) {
                return json.routes[0];
            }
        }
    }
    catch {
        // Retry once with default OSRM if not already
        if (baseUrl !== DEFAULT_OSRM_URL) {
            try {
                const fallbackUrl = `${DEFAULT_OSRM_URL}/route/v1/${profile}/${coordString}?overview=full&geometries=geojson&steps=true`;
                const resp = await fetch(fallbackUrl);
                if (resp.ok) {
                    const json = await resp.json();
                    if (json.code === 'Ok' && json.routes && json.routes.length > 0) {
                        return json.routes[0];
                    }
                }
            }
            catch {
                // failed
            }
        }
    }
    return null;
}
export async function generateCandidateRoutes(activity, targetDistanceKm, preferences, startLocation) {
    const profile = getOsrmProfile(activity);
    const start = [startLocation.latitude, startLocation.longitude];
    const constructionScales = [0.55, 0.75, 0.9, 1, 1.1, 1.25, 1.45];
    const candidateConfigs = constructionScales.flatMap((scale) => {
        const constructionDistanceKm = targetDistanceKm * scale;
        const loopRadiusKm = Math.max(0.1, constructionDistanceKm / (2 * Math.PI));
        const outAndBackRadiusKm = Math.max(0.15, (constructionDistanceKm / 2) * 0.9);
        const p1 = destinationPoint(...start, loopRadiusKm, 30);
        const p2 = destinationPoint(...start, loopRadiusKm, 150);
        const p3 = destinationPoint(...start, loopRadiusKm, 270);
        const q1 = destinationPoint(...start, loopRadiusKm * 1.15, 90);
        const q2 = destinationPoint(...start, loopRadiusKm * 1.15, 210);
        const q3 = destinationPoint(...start, loopRadiusKm * 1.15, 330);
        const w1 = destinationPoint(...start, outAndBackRadiusKm, 45);
        const s1 = destinationPoint(...start, loopRadiusKm * 0.9, 180);
        const s2 = destinationPoint(...start, loopRadiusKm * 0.9, 270);
        return [
            { name: 'Scenic Park Loop', coords: [start, p1, p2, p3, start], isLoop: true },
            { name: 'Neighborhood Circuit', coords: [start, q1, q2, q3, start], isLoop: true },
            { name: 'Boulevard Out & Back', coords: [start, w1, start], isLoop: false },
            { name: 'Quiet Residential Loop', coords: [start, s1, s2, start], isLoop: true },
        ].map((candidate) => ({
            ...candidate,
            name: `${candidate.name} (${scale}x)`,
        }));
    });
    const results = await Promise.all(candidateConfigs.map(async (config) => {
        const osrmRoute = await callOsrm(profile, config.coords);
        return { config, osrmRoute };
    }));
    const candidates = [];
    for (const { config, osrmRoute } of results) {
        if (osrmRoute && osrmRoute.geometry && osrmRoute.geometry.coordinates) {
            const distanceMeters = osrmRoute.distance;
            const distanceKm = distanceMeters / 1000;
            const durationSeconds = Math.round(osrmRoute.duration);
            // Analyze road classification from steps
            const roadNames = [];
            let totalSteps = 0;
            let majorRoadSteps = 0;
            let sidewalkSteps = 0;
            if (osrmRoute.legs) {
                for (const leg of osrmRoute.legs) {
                    if (leg.steps) {
                        for (const step of leg.steps) {
                            totalSteps++;
                            const name = step.name || '';
                            if (name && !roadNames.includes(name))
                                roadNames.push(name);
                            const ref = (step.ref || '').toLowerCase();
                            const mode = (step.mode || '').toLowerCase();
                            if (ref.includes('highway') || ref.includes('ah') || name.toLowerCase().includes('avenue') || name.toLowerCase().includes('highway')) {
                                majorRoadSteps++;
                            }
                            if (mode.includes('foot') || name.toLowerCase().includes('walk') || name.toLowerCase().includes('park') || name.toLowerCase().includes('trail')) {
                                sidewalkSteps++;
                            }
                        }
                    }
                }
            }
            const majorRatio = totalSteps > 0 ? Number((majorRoadSteps / totalSteps).toFixed(2)) : 0.1;
            const sidewalkRatio = totalSteps > 0 ? Number((Math.max(sidewalkSteps, totalSteps - majorRoadSteps) / totalSteps).toFixed(2)) : 0.85;
            candidates.push({
                id: `route-${candidates.length + 1}`,
                name: config.name,
                activityType: activity,
                distanceKm,
                distanceMeters,
                durationSeconds,
                geometry: {
                    type: 'LineString',
                    coordinates: osrmRoute.geometry.coordinates,
                },
                features: {
                    distanceDeltaKm: Number(Math.abs(distanceKm - targetDistanceKm).toFixed(2)),
                    isLoop: config.isLoop,
                    sidewalkRatio,
                    majorRoadRatio: majorRatio,
                    cyclingLaneRatio: activity === 'cycling' ? 0.75 : 0.3,
                    roadTypes: roadNames.slice(0, 5),
                    elevationGainM: Math.round(distanceKm * 4),
                },
            });
        }
    }
    // Retry with a direct routed leg if OSRM rejected all multi-waypoint candidates.
    if (candidates.length === 0) {
        const fallbackP1 = destinationPoint(startLocation.latitude, startLocation.longitude, Math.max(0.15, targetDistanceKm / 2), 45);
        const osrmRoute = await callOsrm(profile, [
            start,
            fallbackP1,
        ]);
        if (osrmRoute && osrmRoute.geometry) {
            const distanceKm = osrmRoute.distance / 1000;
            candidates.push({
                id: 'route-1',
                name: 'Direct OpenStreetMap Route',
                activityType: activity,
                distanceKm,
                distanceMeters: osrmRoute.distance,
                durationSeconds: Math.round(osrmRoute.duration),
                geometry: {
                    type: 'LineString',
                    coordinates: osrmRoute.geometry.coordinates,
                },
                features: {
                    distanceDeltaKm: Number(Math.abs(distanceKm - targetDistanceKm).toFixed(2)),
                    isLoop: false,
                    sidewalkRatio: 0.8,
                    majorRoadRatio: 0.1,
                    cyclingLaneRatio: activity === 'cycling' ? 0.8 : 0.3,
                    roadTypes: ['Street', 'Pathway'],
                },
            });
        }
    }
    return validateAndDeduplicateCandidateRoutes(candidates, targetDistanceKm);
}
