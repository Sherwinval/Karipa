import {
  validateAndDeduplicateCandidateRoutes,
  type CandidateRoute,
  type RoutePreferences,
} from './routingService.js';
import {
  evaluateRouteCandidates,
  isGroqEnabled,
  type RouteCandidateEvaluation,
  type RoutePreferencesForEvaluation,
  type RouteCandidateForRanking,
} from './groqService.js';

export interface RankedRoute extends CandidateRoute {
  targetDistanceKm: number;
  score: number;
  rank: number;
  isTopRecommendation: boolean;
  suitability: string;
  matchLabel: string;
  reasoning: string;
  absoluteDistanceDeviationKm: number;
  percentageDistanceDeviation: number;
  rankingSource: 'ai_assisted' | 'deterministic_fallback';
}

export type RouteCandidateRanker = (
  activity: string,
  targetDistanceKm: number,
  preferences: RoutePreferencesForEvaluation,
  candidates: RouteCandidateForRanking[],
) => Promise<RouteCandidateEvaluation>;

interface ScoredRoute {
  route: CandidateRoute;
  distanceDeltaKm: number;
  preferenceScore: number;
  score: number;
}

function ratio(value: number | undefined): number {
  return Number.isFinite(value) ? Math.min(1, Math.max(0, value!)) : 0;
}

function preferenceScore(route: CandidateRoute, preferences: RoutePreferences, activity: string): number {
  let score = 0;
  let criteria = 0;

  if (preferences.preferLoop) {
    criteria++;
    if (route.features.isLoop) score++;
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

export async function rankCandidateRoutes(
  activity: string,
  targetDistanceKm: number,
  preferences: RoutePreferences,
  routes: CandidateRoute[],
  aiRanker: RouteCandidateRanker = evaluateRouteCandidates,
  targetDistanceToleranceKm?: number,
): Promise<RankedRoute[]> {
  if (!Number.isFinite(targetDistanceKm) || targetDistanceKm <= 0) return [];
  const validatedRoutes = validateAndDeduplicateCandidateRoutes(routes, targetDistanceKm, {
    targetDistanceToleranceKm,
  });
  if (validatedRoutes.length === 0) return [];

  const scored: ScoredRoute[] = validatedRoutes.map((route) => {
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

  let aiOrder: Map<string, number> | undefined;
  let aiReasons: Map<string, string> | undefined;
  let distanceInsight: string | undefined;
  if (
    process.env.AI_ROUTE_RANKING_ENABLED?.trim().toLowerCase() !== 'false' &&
    (aiRanker !== evaluateRouteCandidates || isGroqEnabled())
  ) {
    try {
      const candidates = scored.map(({ route, distanceDeltaKm }) => ({
        id: route.id,
        distanceKm: route.distanceKm,
        absoluteDeviationKm: distanceDeltaKm,
        isLoop: route.features.isLoop,
        majorRoadRatio: route.features.majorRoadRatio,
        sidewalkRatio: route.features.sidewalkRatio,
        cyclingLaneRatio: route.features.cyclingLaneRatio,
      }));
      const evaluation = await aiRanker(
        activity,
        targetDistanceKm,
        preferences,
        candidates,
      );
      const validIds = new Set(candidates.map(({ id }) => id));
      const returnedIds = new Set(evaluation.rankedRouteIds);
      if (
        evaluation.rankedRouteIds.length !== validIds.size ||
        returnedIds.size !== validIds.size ||
        evaluation.rankedRouteIds.some((id) => !validIds.has(id)) ||
        evaluation.candidateReasons.length !== validIds.size ||
        new Set(evaluation.candidateReasons.map(({ routeId }) => routeId)).size !== validIds.size ||
        evaluation.candidateReasons.some(({ routeId, reason }) =>
          !validIds.has(routeId) || typeof reason !== 'string' || reason.length === 0
        ) ||
        typeof evaluation.distanceInsight !== 'string' ||
        evaluation.distanceInsight.length === 0
      ) {
        throw new Error('AI returned missing, duplicate, or unknown route identifiers');
      }
      aiOrder = new Map(evaluation.rankedRouteIds.map((id, index) => [id, index]));
      aiReasons = new Map(evaluation.candidateReasons.map(({ routeId, reason }) => [routeId, reason]));
      distanceInsight = evaluation.distanceInsight;
    } catch (error) {
      const errorCode = typeof error === 'object' && error !== null && 'code' in error
        ? String(error.code)
        : 'INVALID_RANKING';
      console.warn(`AI route ranking unavailable (${errorCode}); using deterministic fallback`);
    }
  }

  scored.sort((a, b) =>
    a.distanceDeltaKm - b.distanceDeltaKm ||
    b.preferenceScore - a.preferenceScore ||
    a.route.id.localeCompare(b.route.id)
  );
  if (aiOrder && scored.length > 1) {
    const nearestDeviation = scored[0].distanceDeltaKm;
    const tieGroup = scored.filter((item) => item.distanceDeltaKm <= nearestDeviation + 0.05);
    const tieIds = new Set(tieGroup.map((item) => item.route.id));
    const aiRankedTieGroup = tieGroup.sort(
      (a, b) => aiOrder!.get(a.route.id)! - aiOrder!.get(b.route.id)!,
    );
    const remaining = scored.filter((item) => !tieIds.has(item.route.id));
    scored.splice(0, scored.length, ...aiRankedTieGroup, ...remaining);
  }

  const topScored = scored.slice(0, 5);

  return topScored.map((item, index) => {
    const reasons: string[] = [`${item.route.distanceKm.toFixed(2)} km; ${item.distanceDeltaKm.toFixed(2)} km from target`];
    if (preferences.preferLoop && item.route.features.isLoop) reasons.push('Preferred loop route');
    if (preferences.avoidMajorRoads && item.route.features.majorRoadRatio !== undefined) {
      if (item.route.features.majorRoadRatio < 0.15) reasons.push('Low major-road exposure');
    }
    if (preferences.preferSidewalks && item.route.features.sidewalkRatio !== undefined &&
      item.route.features.sidewalkRatio >= 0.7) reasons.push('Sidewalk preference matched in available data');
    if (preferences.preferCyclingInfrastructure &&
      item.route.features.cyclingLaneRatio !== undefined &&
      item.route.features.cyclingLaneRatio >= 0.5) {
      reasons.push('Cycling infrastructure available');
    }
    if (aiReasons?.has(item.route.id)) reasons.push(aiReasons.get(item.route.id)!);
    if (index === 0 && distanceInsight) reasons.push(distanceInsight);

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
