import { describe, expect, it } from 'vitest';
import { activitySchema } from '../routes/activities.js';

const validActivity = {
  activityType: 'walking',
  distanceMeters: 1200,
  durationSeconds: 900,
  startedAt: '2026-10-20T07:00:00.000Z',
  completedAt: '2026-10-20T07:15:00.000Z',
};

describe('activity recording-mode validation', () => {
  it('keeps legacy activity requests as planned-route recordings', () => {
    const result = activitySchema.safeParse(validActivity);

    expect(result.success).toBe(true);
    if (result.success) expect(result.data.recordingMode).toBe('plan_route');
  });

  it('ignores obsolete heart-rate fields', () => {
    const result = activitySchema.safeParse({
      ...validActivity,
      averageHeartRate: 120,
      maximumHeartRate: 150,
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data).not.toHaveProperty('averageHeartRate');
      expect(result.data).not.toHaveProperty('maximumHeartRate');
    }
  });

  it('accepts Free Recording without a target or planned route', () => {
    const result = activitySchema.safeParse({
      ...validActivity,
      recordingMode: 'free_recording',
      durationSeconds: 800,
      activeDurationSeconds: 800,
      totalElapsedSeconds: 900,
      targetDistanceMeters: null,
      routeData: null,
    });

    expect(result.success).toBe(true);
  });

  it('rejects Free Recording with route-planning information', () => {
    for (const planningFields of [
      { targetDistanceMeters: 5000 },
      { routeData: { id: 'planned-route' } },
    ]) {
      const result = activitySchema.safeParse({
        ...validActivity,
        recordingMode: 'free_recording',
        ...planningFields,
      });
      expect(result.success).toBe(false);
    }
  });

  it('rejects conflicting active-duration representations', () => {
    const result = activitySchema.safeParse({
      ...validActivity,
      activeDurationSeconds: 800,
      durationSeconds: 900,
    });
    expect(result.success).toBe(false);
  });
});
