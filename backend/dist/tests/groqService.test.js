import { afterEach, describe, expect, it, vi } from 'vitest';
import { evaluateRouteCandidates, explainUnavailableDistance, getGroqUsageMetrics, interpretRoutePreferences, rankRouteCandidateIds, } from '../services/groqService.js';
const originalGroqApiKey = process.env.GROQ_API_KEY;
afterEach(() => {
    vi.unstubAllGlobals();
    if (originalGroqApiKey === undefined) {
        delete process.env.GROQ_API_KEY;
    }
    else {
        process.env.GROQ_API_KEY = originalGroqApiKey;
    }
});
describe('Groq route ranking', () => {
    it('sends validated candidates to Groq and returns the validated ranking', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        const fetchMock = vi.fn(async (_input, init) => {
            const body = JSON.parse(String(init?.body));
            expect(body.model).toBe('openai/gpt-oss-20b');
            expect(body.response_format.type).toBe('json_schema');
            expect(body.response_format.json_schema.strict).toBe(true);
            expect(body.messages.at(-1).content).toContain('"id":"route-a"');
            return new Response(JSON.stringify({
                choices: [{
                        message: {
                            content: JSON.stringify({
                                rankedRouteIds: ['route-b', 'route-a'],
                                candidateReasons: [
                                    { routeId: 'route-a', reason: 'A little farther from the target.' },
                                    { routeId: 'route-b', reason: 'Closer and matches the loop preference.' },
                                ],
                                distanceInsight: 'Both candidates are within the requested target range.',
                            }),
                        },
                    }],
                usage: { prompt_tokens: 40, completion_tokens: 30 },
            }), { status: 200 });
        });
        vi.stubGlobal('fetch', fetchMock);
        const rankedIds = await rankRouteCandidateIds('running', 5, true, [
            { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: false },
            { id: 'route-b', distanceKm: 5.1, absoluteDeviationKm: 0.1, isLoop: true },
        ]);
        expect(fetchMock).toHaveBeenCalledOnce();
        expect(rankedIds).toEqual(['route-b', 'route-a']);
        expect(getGroqUsageMetrics().inputTokens).toBeGreaterThan(0);
    });
    it('reports invalid credentials as an authentication error', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 401 })));
        await expect(rankRouteCandidateIds('running', 5, false, [
            { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: false },
        ])).rejects.toMatchObject({
            code: 'AUTH_ERROR',
            statusCode: 500,
        });
    });
    it('validates that Groq returns every candidate exactly once', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
            choices: [{
                    message: {
                        content: JSON.stringify({
                            rankedRouteIds: ['unknown'],
                            candidateReasons: [{ routeId: 'unknown', reason: 'Unknown.' }],
                            distanceInsight: 'Not available.',
                        }),
                    },
                }],
        }), { status: 200 })));
        await expect(rankRouteCandidateIds('running', 5, false, [
            { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: false },
        ])).rejects.toMatchObject({
            code: 'INVALID_RESPONSE',
        });
    });
    it('translates notes into validated nullable routing constraints', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        vi.stubGlobal('fetch', vi.fn(async (_input, init) => {
            const body = JSON.parse(String(init?.body));
            expect(body.messages.at(-1).content).toContain('avoid hills');
            return new Response(JSON.stringify({
                choices: [{
                        message: {
                            content: JSON.stringify({
                                constraints: {
                                    avoidMajorRoads: true,
                                    preferSidewalks: null,
                                    preferLoop: false,
                                    preferCyclingInfrastructure: null,
                                    avoidHills: true,
                                },
                                unsupportedPreferences: ['well-lit route'],
                            }),
                        },
                    }],
            }), { status: 200 });
        }));
        await expect(interpretRoutePreferences('avoid hills and major roads; no loop, please')).resolves.toEqual({
            constraints: {
                avoidMajorRoads: true,
                preferSidewalks: null,
                preferLoop: false,
                preferCyclingInfrastructure: null,
                avoidHills: true,
            },
            unsupportedPreferences: ['well-lit route'],
        });
    });
    it('retries a transient provider failure only once', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        const fetchMock = vi.fn()
            .mockResolvedValueOnce(new Response('{}', { status: 503 }))
            .mockResolvedValueOnce(new Response(JSON.stringify({
            choices: [{
                    message: {
                        content: JSON.stringify({
                            rankedRouteIds: ['route-a'],
                            candidateReasons: [{ routeId: 'route-a', reason: 'Closest to target.' }],
                            distanceInsight: 'The route matches the requested target.',
                        }),
                    },
                }],
        }), { status: 200 }));
        vi.stubGlobal('fetch', fetchMock);
        const result = await evaluateRouteCandidates('running', 5, {}, [
            { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: true },
        ]);
        expect(fetchMock).toHaveBeenCalledTimes(2);
        expect(result.rankedRouteIds).toEqual(['route-a']);
        expect(getGroqUsageMetrics().retries).toBeGreaterThan(0);
    });
    it('explains unattainable target distances using only measured candidate distances', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        const fetchMock = vi.fn(async (_input, init) => {
            const body = JSON.parse(String(init?.body));
            expect(body.messages.at(-1).content).toContain('[6.1,6.4]');
            expect(body.messages.at(-1).content).not.toContain('coordinates');
            return new Response(JSON.stringify({
                choices: [{
                        message: {
                            content: JSON.stringify({
                                explanation: 'No returned route met the requested tolerance.',
                                suggestions: ['Try a target closer to the available distances.'],
                            }),
                        },
                    }],
            }), { status: 200 });
        });
        vi.stubGlobal('fetch', fetchMock);
        await expect(explainUnavailableDistance('running', 5, 0.5, [6.1, 6.4])).resolves.toEqual({
            explanation: 'No returned route met the requested tolerance.',
            suggestions: ['Try a target closer to the available distances.'],
        });
    });
    it('does not retry a rate-limited response', async () => {
        process.env.GROQ_API_KEY = 'test-groq-key';
        const fetchMock = vi.fn(async () => new Response('{}', { status: 429 }));
        vi.stubGlobal('fetch', fetchMock);
        await expect(rankRouteCandidateIds('running', 5, false, [
            { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: false },
        ])).rejects.toMatchObject({ code: 'RATE_LIMIT' });
        expect(fetchMock).toHaveBeenCalledOnce();
    });
});
