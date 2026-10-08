const DEFAULT_AI_URL = 'http://localhost:8000';
export async function rankCandidateRoutesWithAi(activity, targetDistanceKm, preferences, routes) {
    if (routes.length === 0)
        return [];
    const aiServiceUrl = process.env.AI_SERVICE_URL || DEFAULT_AI_URL;
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 4000);
        const response = await fetch(`${aiServiceUrl}/recommend`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                activity,
                targetDistanceKm,
                preferences,
                routes,
            }),
            signal: controller.signal,
        });
        clearTimeout(timeout);
        if (response.ok) {
            const data = await response.json();
            if (data.success && Array.isArray(data.rankedRoutes) && data.rankedRoutes.length > 0) {
                return data.rankedRoutes;
            }
        }
    }
    catch (err) {
        console.warn('AI recommendation service unavailable, using ML heuristic fallback ranking:', err);
    }
    // Fallback: scikit-learn compatible heuristic ranking
    return fallbackRanking(activity, targetDistanceKm, preferences, routes);
}
function fallbackRanking(activity, targetDistanceKm, preferences, routes) {
    const scored = routes.map((route) => {
        const distDiff = Math.abs(route.distanceKm - targetDistanceKm);
        const distScore = Math.max(0, 100 - (distDiff / Math.max(targetDistanceKm, 1)) * 100);
        let prefScore = 70;
        if (preferences.preferLoop && route.features.isLoop)
            prefScore += 15;
        if (preferences.avoidMajorRoads)
            prefScore += (1 - route.features.majorRoadRatio) * 10;
        if (preferences.preferSidewalks)
            prefScore += route.features.sidewalkRatio * 10;
        const totalScore = Number(((distScore * 0.55) + (prefScore * 0.45)).toFixed(1));
        return {
            route,
            score: Math.min(99, Math.max(45, totalScore)),
        };
    });
    scored.sort((a, b) => b.score - a.score);
    return scored.map((item, idx) => {
        const isTop = idx === 0;
        let suitability = 'Good match';
        let matchLabel = 'Recommended';
        if (item.score >= 85) {
            suitability = 'Excellent match';
            matchLabel = 'Best Match';
        }
        else if (item.score < 70) {
            suitability = 'Fair match';
            matchLabel = 'Alternative';
        }
        const reasons = [];
        if (Math.abs(item.route.distanceKm - targetDistanceKm) <= 0.4) {
            reasons.push(`Accurate to target ${targetDistanceKm} km`);
        }
        if (item.route.features.isLoop) {
            reasons.push('Circular loop');
        }
        if (item.route.features.majorRoadRatio < 0.15) {
            reasons.push('Pedestrian-friendly / low traffic');
        }
        if (reasons.length === 0) {
            reasons.push(`Optimal for ${activity}`);
        }
        return {
            ...item.route,
            score: item.score,
            rank: idx + 1,
            isTopRecommendation: isTop,
            suitability,
            matchLabel,
            reasoning: reasons.join(' • '),
        };
    });
}
