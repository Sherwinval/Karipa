import { afterEach, describe, expect, it, vi } from 'vitest';
import { rankRouteCandidateIds } from '../services/groqService.js';

const originalGroqApiKey = process.env.GROQ_API_KEY;

afterEach(() => {
  vi.unstubAllGlobals();
  if (originalGroqApiKey === undefined) {
    delete process.env.GROQ_API_KEY;
  } else {
    process.env.GROQ_API_KEY = originalGroqApiKey;
  }
});

describe('Groq route ranking', () => {
  it('sends validated candidates to Groq and returns the validated ranking', async () => {
    process.env.GROQ_API_KEY = 'test-groq-key';
    const fetchMock = vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body));
      expect(body.model).toBe('openai/gpt-oss-120b');
      expect(body.response_format).toEqual({ type: 'json_object' });
      expect(body.messages.at(-1).content).toContain('"id":"route-a"');
      return new Response(JSON.stringify({
        choices: [{ message: { content: '{"rankedRouteIds":["route-b","route-a"]}' } }],
      }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetchMock);

    const rankedIds = await rankRouteCandidateIds('running', 5, true, [
      { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: false },
      { id: 'route-b', distanceKm: 5.1, absoluteDeviationKm: 0.1, isLoop: true },
    ]);

    expect(fetchMock).toHaveBeenCalledOnce();
    expect(rankedIds).toEqual(['route-b', 'route-a']);
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
      choices: [{ message: { content: '{"rankedRouteIds":["unknown"]}' } }],
    }), { status: 200 })));

    await expect(rankRouteCandidateIds('running', 5, false, [
      { id: 'route-a', distanceKm: 5, absoluteDeviationKm: 0, isLoop: false },
    ])).rejects.toMatchObject({
      code: 'INVALID_RESPONSE',
    });
  });
});
