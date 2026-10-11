import { describe, expect, it } from 'vitest';
import { rankCandidateRoutes } from '../services/routeRankingService.js';
import { validateAndDeduplicateCandidateRoutes, } from '../services/routingService.js';
let geometryCounter = 0;
function route(id, distanceKm, options = {}) {
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
    it.each([
        [3, 1, 5],
        [5, 3, 7],
        [10, 8, 12],
        [20, 18, 22],
    ])('applies the dynamic +/-2 km window for a %s km target', (target, minimum, maximum) => {
        const candidates = [
            route('minimum', minimum),
            route('within', target),
            route('maximum', maximum),
            route('too-short', Math.max(0.01, minimum - 0.01)),
            route('too-long', maximum + 0.01),
        ];
        expect(validateAndDeduplicateCandidateRoutes(candidates, target).map((item) => item.id))
            .toEqual(['minimum', 'within', 'maximum']);
    });
    it('uses the routing-engine distance instead of the supplied display distance', () => {
        const candidate = { ...route('authoritative', 8), distanceKm: 13 };
        expect(validateAndDeduplicateCandidateRoutes([candidate], 10)[0].distanceKm).toBe(8);
        expect(validateAndDeduplicateCandidateRoutes([candidate], 14)).toEqual([]);
    });
    it('rejects malformed, discontinuous, and substantially duplicate route geometries', () => {
        const valid = route('valid', 5);
        const duplicate = {
            ...route('duplicate', 5),
            geometry: valid.geometry,
        };
        const malformed = {
            ...route('malformed', 5),
            geometry: { type: 'LineString', coordinates: [[181, 14], [182, 14]] },
        };
        const stationary = {
            ...route('stationary', 5),
            geometry: { type: 'LineString', coordinates: [[120, 14], [120, 14]] },
        };
        expect(validateAndDeduplicateCandidateRoutes([valid, duplicate, malformed, stationary], 5).map((item) => item.id))
            .toEqual(['valid']);
    });
    it('handles short targets and returns no candidate when every actual distance is out of range', () => {
        expect(validateAndDeduplicateCandidateRoutes([route('short', 0.4)], 0.5)).toHaveLength(1);
        expect(validateAndDeduplicateCandidateRoutes([route('too-far', 17.99)], 20)).toEqual([]);
    });
});
describe('route ranking', () => {
    it('ranks by distance before preferences and never returns out-of-range candidates', async () => {
        const closest = route('closest', 9.9, { isLoop: false, majorRoadRatio: 0.9 });
        const preferredButFarther = route('preferred', 11.4, { isLoop: true, majorRoadRatio: 0 });
        const outOfRange = route('excluded', 12.01);
        const ranked = await rankCandidateRoutes('running', 10, { preferLoop: true, avoidMajorRoads: true }, [preferredButFarther, outOfRange, closest]);
        expect(ranked.map((item) => item.id)).toEqual(['closest', 'preferred']);
        expect(ranked[0].distanceKm).toBeCloseTo(9.9);
        expect(ranked[0].rank).toBe(1);
        expect(ranked[0].isTopRecommendation).toBe(true);
    });
    it('changes preference ordering when selected preferences change', async () => {
        const loop = route('loop', 5, { isLoop: true });
        const direct = route('direct', 5, { isLoop: false });
        const loopPreferred = await rankCandidateRoutes('running', 5, { preferLoop: true }, [direct, loop]);
        const noLoopPreference = await rankCandidateRoutes('running', 5, { preferLoop: false }, [direct, loop]);
        expect(loopPreferred[0].id).toBe('loop');
        expect(noLoopPreference[0].id).toBe('direct');
    });
});
