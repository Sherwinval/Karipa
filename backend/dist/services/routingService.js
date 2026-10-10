const DEFAULT_OSRM_URL = 'https://router.project-osrm.org';
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
    // If bike profile failed, try foot profile on public OSRM as fallback
    if (profile === 'bike') {
        try {
            const fallbackUrl = `${DEFAULT_OSRM_URL}/route/v1/foot/${coordString}?overview=full&geometries=geojson&steps=true`;
            const resp = await fetch(fallbackUrl);
            if (resp.ok) {
                const json = await resp.json();
                if (json.code === 'Ok' && json.routes && json.routes.length > 0) {
                    return json.routes[0];
                }
            }
        }
        catch {
            // Fallback failed
        }
    }
    return null;
}
export async function generateCandidateRoutes(activity, targetDistanceKm, preferences, startLocation) {
    const profile = getOsrmProfile(activity);
    const candidates = [];
    // Circle radius for loop generation
    // For a polygon loop with perimeter P ≈ targetDistanceKm, radius R ≈ P / (2 * pi)
    const loopRadiusKm = Math.max(0.3, targetDistanceKm / (2 * Math.PI));
    const outAndBackRadiusKm = Math.max(0.4, (targetDistanceKm / 2) * 0.9);
    // Strategy 1: Clockwise Triangle/Square Loop (Bearing 0, 120, 240)
    const p1 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm, 30);
    const p2 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm, 150);
    const p3 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm, 270);
    const loop1Coords = [
        [startLocation.latitude, startLocation.longitude],
        p1,
        p2,
        p3,
        [startLocation.latitude, startLocation.longitude],
    ];
    // Strategy 2: Counter-Clockwise Hex Loop (Bearing 90, 210, 330)
    const q1 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm * 1.15, 90);
    const q2 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm * 1.15, 210);
    const q3 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm * 1.15, 330);
    const loop2Coords = [
        [startLocation.latitude, startLocation.longitude],
        q1,
        q2,
        q3,
        [startLocation.latitude, startLocation.longitude],
    ];
    // Strategy 3: Out-and-back route to North/East
    const w1 = destinationPoint(startLocation.latitude, startLocation.longitude, outAndBackRadiusKm, 45);
    const outAndBackCoords = [
        [startLocation.latitude, startLocation.longitude],
        w1,
        [startLocation.latitude, startLocation.longitude],
    ];
    // Strategy 4: South/West Scenic Loop
    const s1 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm * 0.9, 180);
    const s2 = destinationPoint(startLocation.latitude, startLocation.longitude, loopRadiusKm * 0.9, 270);
    const loop3Coords = [
        [startLocation.latitude, startLocation.longitude],
        s1,
        s2,
        [startLocation.latitude, startLocation.longitude],
    ];
    const candidateConfigs = [
        { name: 'Scenic Park Loop', coords: loop1Coords, isLoop: true },
        { name: 'Neighborhood Circuit', coords: loop2Coords, isLoop: true },
        { name: 'Boulevard Out & Back', coords: outAndBackCoords, isLoop: false },
        { name: 'Quiet Residential Loop', coords: loop3Coords, isLoop: true },
    ];
    const results = await Promise.all(candidateConfigs.map(async (config) => {
        const osrmRoute = await callOsrm(profile, config.coords);
        return { config, osrmRoute };
    }));
    let routeCounter = 1;
    for (const { config, osrmRoute } of results) {
        if (osrmRoute && osrmRoute.geometry && osrmRoute.geometry.coordinates) {
            const distanceMeters = osrmRoute.distance;
            const distanceKm = Number((distanceMeters / 1000).toFixed(2));
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
                id: `route-${routeCounter++}`,
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
    // Fallback: If OSRM was temporarily unreachable for complex multi-point loops,
    // query a 2-point realistic waypoint to ensure real OSM route is returned!
    if (candidates.length === 0) {
        const fallbackP1 = destinationPoint(startLocation.latitude, startLocation.longitude, Math.max(0.8, targetDistanceKm / 2), 45);
        const osrmRoute = await callOsrm(profile, [
            [startLocation.latitude, startLocation.longitude],
            fallbackP1,
        ]);
        if (osrmRoute && osrmRoute.geometry) {
            const distanceKm = Number((osrmRoute.distance / 1000).toFixed(2));
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
    return candidates;
}
