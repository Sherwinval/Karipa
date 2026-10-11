import { validateAndDeduplicateCandidateRoutes, } from './routingService.js';
function ratio(value) {
    return Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0;
}
function preferenceScore(route, preferences, activity) {
    let score = 0;
    let criteria = 0;
    if (preferences.preferLoop) {
        criteria++;
        if (route.features.isLoop)
            score++;
    }
    if (preferences.avoidMajorRoads) {
        criteria++;
        score += 1 - ratio(route.features.majorRoadRatio);
    }
    if (preferences.preferSidewalks) {
        criteria++;
        score += ratio(route.features.sidewalkRatio);
    }
    if (preferences.preferCyclingInfrastructure || activity === 'cycling') {
        criteria++;
        score += ratio(route.features.cyclingLaneRatio);
    }
    if (preferences.avoidHills) {
        criteria++;
        score += route.features.elevationGainM !== undefined
            ? 1 - Math.min(1, Math.max(0, route.features.elevationGainM) / Math.max(100, route.distanceKm * 20))
            : 0;
    }
    return criteria === 0 ? 0.5 : score / criteria;
}
function routeQualityScore(route) {
    const geometry = route.geometry.coordinates;
    const uniquePoints = new Set(geometry.map(([longitude, latitude]) => `${longitude.toFixed(4)},${latitude.toFixed(4)}`));
    const shapeScore = Math.min(1, uniquePoints.size / Math.max(4, geometry.length * 0.5));
    const hasRoadData = route.features.roadTypes.length > 0 ? 1 : 0.5;
    return (shapeScore + hasRoadData) / 2;
}
export async function rankCandidateRoutes(activity, targetDistanceKm, preferences, routes) {
    const validatedRoutes = validateAndDeduplicateCandidateRoutes(routes, targetDistanceKm);
    if (validatedRoutes.length === 0)
        return [];
    const scored = validatedRoutes.map((route) => {
        const distanceDeltaKm = Math.abs(route.distanceKm - targetDistanceKm);
        const distanceScore = Math.max(0, 100 - (distanceDeltaKm / Math.max(targetDistanceKm, 1)) * 100);
        const preferencesScore = preferenceScore(route, preferences, activity.toLowerCase());
        const qualityScore = routeQualityScore(route);
        return {
            route,
            distanceDeltaKm,
            preferenceScore: preferencesScore,
            qualityScore,
            score: Number((distanceScore * 0.7 + preferencesScore * 20 + qualityScore * 10).toFixed(1)),
        };
    });
    scored.sort((a, b) => a.distanceDeltaKm - b.distanceDeltaKm ||
        b.preferenceScore - a.preferenceScore ||
        b.qualityScore - a.qualityScore ||
        a.route.id.localeCompare(b.route.id));
    return scored.map((item, index) => {
        const reasons = [`${item.route.distanceKm.toFixed(2)} km; ${item.distanceDeltaKm.toFixed(2)} km from target`];
        if (preferences.preferLoop && item.route.features.isLoop)
            reasons.push('Preferred loop route');
        if (preferences.avoidMajorRoads && item.route.features.majorRoadRatio < 0.15)
            reasons.push('Low major-road exposure');
        if (preferences.preferSidewalks && item.route.features.sidewalkRatio >= 0.7)
            reasons.push('Sidewalk-friendly');
        if ((preferences.preferCyclingInfrastructure || activity.toLowerCase() === 'cycling') &&
            item.route.features.cyclingLaneRatio >= 0.5) {
            reasons.push('Cycling infrastructure available');
        }
        const suitability = item.score >= 85
            ? 'Excellent match'
            : item.score >= 70
                ? 'Good match'
                : 'Fair match';
        return {
            ...item.route,
            score: item.score,
            rank: index + 1,
            isTopRecommendation: index === 0,
            suitability,
            matchLabel: index === 0 ? 'Best Match' : item.score >= 70 ? 'Recommended' : 'Alternative',
            reasoning: reasons.join(' • '),
        };
    });
}
