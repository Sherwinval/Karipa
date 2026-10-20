import { describe, expect, it } from 'vitest';
import { getWeeklyLeaderboardPeriod } from '../lib/weeklyLeaderboardPeriod.js';
describe('weekly leaderboard calendar period', () => {
    it('starts on Sunday at midnight in Philippine time', () => {
        const now = new Date('2026-06-24T04:30:00.000Z');
        const { periodStart, periodEnd } = getWeeklyLeaderboardPeriod(now);
        expect(periodStart.toISOString()).toBe('2026-06-20T16:00:00.000Z');
        expect(periodEnd).toBe(now);
    });
    it('resets at the Sunday midnight Philippine-time boundary', () => {
        const justBeforeReset = getWeeklyLeaderboardPeriod(new Date('2026-06-20T15:59:59.999Z'));
        const atReset = getWeeklyLeaderboardPeriod(new Date('2026-06-20T16:00:00.000Z'));
        expect(justBeforeReset.periodStart.toISOString()).toBe('2026-06-13T16:00:00.000Z');
        expect(atReset.periodStart.toISOString()).toBe('2026-06-20T16:00:00.000Z');
    });
});
