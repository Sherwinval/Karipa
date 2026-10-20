import { validateAndDeduplicateCandidateRoutes, } from './routingService.js';
import { rankRouteCandidateIds, } from './geminiService.js';
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
        if (route.features.majorRoadRatio !== undefined) {
            criteria++;
            score += 1 - ratio(route.features.majorRoadRatio);
        }
    }
    if (preferences.preferSidewalks) {
        if (route.features.sidewalkRatio !== undefined) {
            criteria++;
            score += ratio(route.features.sidewalkRatio);
        }
    }
    if (preferences.preferCyclingInfrastructure) {
        if (route.features.cyclingLaneRatio !== undefined) {
            criteria++;
            score += ratio(route.features.cyclingLaneRatio);
        }
    }
    return criteria === 0 ? 0.5 : score / criteria;
}
export async function rankCandidateRoutes(activity, targetDistanceKm, preferences, routes, aiRanker = rankRouteCandidateIds) {
    if (!Number.isFinite(targetDistanceKm) || targetDistanceKm <= 0)
        return [];
    const validatedRoutes = validateAndDeduplicateCandidateRoutes(routes, targetDistanceKm);
    if (validatedRoutes.length === 0)
        return [];
    const scored = validatedRoutes.map((route) => {
        const distanceDeltaKm = Math.abs(route.distanceKm - targetDistanceKm);
        const distanceScore = Math.max(0, 100 - (distanceDeltaKm / targetDistanceKm) * 100);
        const preferencesScore = preferenceScore(route, preferences, activity.toLowerCase());
        return {
            route,
            distanceDeltaKm,
            preferenceScore: preferencesScore,
            score: Number(distanceScore.toFixed(1)),
        };
    });
    let aiOrder;
    let aiResolvedTie = false;
    if (process.env.AI_ROUTE_RANKING_ENABLED?.trim().toLowerCase() !== 'false') {
        const primaryOrder = [...scored].sort((a, b) => a.distanceDeltaKm - b.distanceDeltaKm ||
            b.preferenceScore - a.preferenceScore ||
            a.route.id.localeCompare(b.route.id));
        const tiedGroups = [];
        for (const item of primaryOrder) {
            const currentGroup = tiedGroups[tiedGroups.length - 1];
            if (currentGroup &&
                currentGroup[0].distanceDeltaKm === item.distanceDeltaKm &&
                currentGroup[0].preferenceScore === item.preferenceScore) {
                currentGroup.push(item);
            }
            else {
                tiedGroups.push([item]);
            }
        }
        aiOrder = new Map();
        for (const group of tiedGroups) {
            if (group.length < 2)
                continue;
            try {
                const candidates = group.map(({ route, distanceDeltaKm }) => ({
                    id: route.id,
                    distanceKm: route.distanceKm,
                    absoluteDeviationKm: distanceDeltaKm,
                    isLoop: route.features.isLoop,
                }));
                const aiRankedIds = await aiRanker(activity, targetDistanceKm, preferences.preferLoop === true, candidates);
                const validIds = new Set(candidates.map(({ id }) => id));
                const returnedIds = new Set(aiRankedIds);
                if (aiRankedIds.length !== validIds.size ||
                    returnedIds.size !== validIds.size ||
                    aiRankedIds.some((id) => !validIds.has(id))) {
                    throw new Error('AI returned missing, duplicate, or unknown route identifiers');
                }
                aiResolvedTie = true;
                aiRankedIds.forEach((id, index) => aiOrder.set(id, index));
            }
            catch (error) {
                const errorCode = typeof error === 'object' && error !== null && 'code' in error
                    ? String(error.code)
                    : 'INVALID_RANKING';
                console.warn(`AI route tie-break unavailable (${errorCode}); using deterministic fallback`);
            }
        }
        if (!aiResolvedTie)
            aiOrder = undefined;
    }
    scored.sort((a, b) => a.distanceDeltaKm - b.distanceDeltaKm ||
        b.preferenceScore - a.preferenceScore ||
        (aiOrder?.get(a.route.id) ?? 0) - (aiOrder?.get(b.route.id) ?? 0) ||
        a.route.id.localeCompare(b.route.id));
    return scored.map((item, index) => {
        const reasons = [`${item.route.distanceKm.toFixed(2)} km; ${item.distanceDeltaKm.toFixed(2)} km from target`];
        if (preferences.preferLoop && item.route.features.isLoop)
            reasons.push('Preferred loop route');
        if (preferences.avoidMajorRoads && item.route.features.majorRoadRatio !== undefined) {
            if (item.route.features.majorRoadRatio < 0.15)
                reasons.push('Low major-road exposure');
        }
        if (preferences.preferSidewalks && item.route.features.sidewalkRatio !== undefined &&
            item.route.features.sidewalkRatio >= 0.7)
            reasons.push('Sidewalk preference matched in available data');
        if (preferences.preferCyclingInfrastructure &&
            item.route.features.cyclingLaneRatio !== undefined &&
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
            targetDistanceKm,
            score: item.score,
            rank: index + 1,
            isTopRecommendation: index === 0,
            suitability,
            matchLabel: index === 0 ? 'Best Match' : item.score >= 70 ? 'Recommended' : 'Alternative',
            reasoning: reasons.join(' • '),
            absoluteDistanceDeviationKm: Number(item.distanceDeltaKm.toFixed(2)),
            percentageDistanceDeviation: Number(((item.distanceDeltaKm / targetDistanceKm) * 100).toFixed(1)),
            rankingSource: aiOrder ? 'ai_assisted' : 'deterministic_fallback',
        };
    });
}
