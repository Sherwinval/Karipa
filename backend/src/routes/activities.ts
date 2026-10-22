import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAuth, type AuthenticatedRequest } from '../middleware/auth.js';
import {
  validateAndCalculateActivityCalories,
  CalorieEstimateValidationError,
} from '../services/calorieEstimationService.js';
import { getWeeklyLeaderboardPeriod } from '../lib/weeklyLeaderboardPeriod.js';

export const activitySchema = z.object({
  activityType: z.enum(['walking', 'jogging', 'running', 'cycling']),
  recordingMode: z.enum(['plan_route', 'free_recording']).default('plan_route'),
  distanceMeters: z.number().finite().nonnegative(),
  durationSeconds: z.number().int().nonnegative(),
  activeDurationSeconds: z.number().int().nonnegative().optional(),
  totalElapsedSeconds: z.number().int().nonnegative().optional(),
  targetDistanceMeters: z.number().finite().positive().nullable().optional(),
  averagePaceSecondsPerKm: z.number().finite().nonnegative().nullable().optional(),
  averageSpeedKmh: z.number().finite().nonnegative().nullable().optional(),
  calories: z.number().finite().nonnegative().nullable().optional(),
  calorieMetCode: z.string().min(1).nullable().optional(),
  calorieMetValue: z.number().finite().positive().nullable().optional(),
  calorieWeightKg: z.number().finite().positive().nullable().optional(),
  calorieDurationMinutes: z.number().finite().positive().nullable().optional(),
  calorieMethodVersion: z.string().min(1).nullable().optional(),
  startedAt: z.coerce.date(),
  completedAt: z.coerce.date(),
  routeData: z.record(z.unknown()).nullable().optional(),
  gpsData: z.unknown().optional(),
  idempotencyKey: z.string().min(1).max(100).optional(),
  timePerKm: z.array(z.object({ kilometer: z.number().int().positive(), timeSeconds: z.number().int().nonnegative() })).optional(),
}).superRefine((data, context) => {
  if (data.activeDurationSeconds !== undefined &&
      data.activeDurationSeconds !== data.durationSeconds) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['activeDurationSeconds'],
      message: 'Active duration must match durationSeconds.',
    });
  }
  if (data.recordingMode === 'free_recording') {
    if (data.targetDistanceMeters != null) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['targetDistanceMeters'],
        message: 'Free Recording cannot include a target distance.',
      });
    }
    if (data.routeData != null) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['routeData'],
        message: 'Free Recording cannot include planned route data.',
      });
    }
  }
});

function serializeActivity(activity: any) {
  const distanceKm = Number(activity.distance) / 1000;
  return {
    id: activity.id.toString(),
    userId: activity.userId.toString(),
    activityType: activity.activityType,
    recordingMode: activity.recordingMode ?? 'plan_route',
    distanceKm: Number(distanceKm.toFixed(2)),
    durationSeconds: activity.duration,
    activeDurationSeconds: activity.duration,
    totalElapsedSeconds: activity.totalElapsedDuration ?? activity.duration,
    targetDistanceKm: activity.targetDistance === null
      ? null
      : Number((Number(activity.targetDistance) / 1000).toFixed(2)),
    averagePaceMinPerKm: activity.pace === null ? null : Number((Number(activity.pace) / 60).toFixed(2)),
    averageSpeedKmh: activity.speed === null ? null : Number(Number(activity.speed).toFixed(2)),
    timePerKm: activity.splits.map((split: any) => ({ kilometer: split.kilometer, timeSeconds: split.timeSeconds })),
    calories: activity.calories === null ? null : Number(activity.calories),
    calorieMetCode: activity.calorieMetCode,
    calorieMetValue: activity.calorieMetValue === null ? null : Number(activity.calorieMetValue),
    calorieWeightKg: activity.calorieWeightKg === null ? null : Number(activity.calorieWeightKg),
    calorieDurationMinutes: activity.calorieDurationMinutes === null
      ? null
      : Number(activity.calorieDurationMinutes),
    calorieMethodVersion: activity.calorieMethodVersion,
    startedAt: activity.startedAt.toISOString(),
    completedAt: activity.completedAt.toISOString(),
    routeData: activity.routeData,
    gpsData: activity.gpsData,
  };
}

export const activityRouter = Router();
activityRouter.use(requireAuth);

activityRouter.get('/', async (req: AuthenticatedRequest, res) => {
  const activities = await prisma.activity.findMany({
    where: { userId: req.userId },
    include: { splits: { orderBy: { kilometer: 'asc' } } },
    orderBy: { completedAt: 'desc' },
  });
  res.json({ success: true, activities: activities.map(serializeActivity) });
});

activityRouter.get('/leaderboard/weekly', async (req: AuthenticatedRequest, res) => {
  const { periodStart, periodEnd } = getWeeklyLeaderboardPeriod();

  try {
    const entries = await prisma.$queryRaw<
      { userId: bigint; name: string; distanceMeters: number; rank: bigint }[]
    >`
      WITH weekly_distances AS (
        SELECT
          u.id AS user_id,
          u.name,
          COALESCE(SUM(a.distance), 0)::double precision AS distance_meters
        FROM public.tbl_users AS u
        LEFT JOIN public.activities AS a
          ON a.user_id = u.id
          AND a.completed_at >= ${periodStart}
          AND a.completed_at <= ${periodEnd}
          AND a.distance > 0
        WHERE u.is_verified = true
        GROUP BY u.id, u.name
        HAVING COALESCE(SUM(a.distance), 0) > 0
      ),
      ranked AS (
        SELECT
          user_id,
          name,
          distance_meters,
          ROW_NUMBER() OVER (
            ORDER BY distance_meters DESC, LOWER(name) ASC, user_id ASC
          ) AS rank
        FROM weekly_distances
      )
      SELECT
        user_id AS "userId",
        name,
        distance_meters AS "distanceMeters",
        rank
      FROM ranked
      WHERE rank <= 50 OR user_id = ${req.userId!}
      ORDER BY rank ASC
    `;

    res.json({
      success: true,
      periodStart: periodStart.toISOString(),
      periodEnd: periodEnd.toISOString(),
      entries: entries.map((entry) => ({
        rank: Number(entry.rank),
        name: entry.name,
        distanceMeters: Number(entry.distanceMeters),
        isCurrentUser: entry.userId === req.userId,
      })),
    });
  } catch (error) {
    console.error('Weekly leaderboard load error:', error);
    res.status(500).json({ success: false, message: 'Failed to load weekly leaderboard' });
  }
});

activityRouter.post('/', async (req: AuthenticatedRequest, res) => {
  const parsed = activitySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ success: false, message: 'Invalid activity data', errors: parsed.error.flatten() });
    return;
  }

  const data = parsed.data;
  let calorieCalculation: ReturnType<typeof validateAndCalculateActivityCalories>;
  try {
    calorieCalculation = validateAndCalculateActivityCalories(data);
  } catch (error) {
    if (error instanceof CalorieEstimateValidationError) {
      res.status(400).json({ success: false, message: error.message });
      return;
    }
    throw error;
  }

  if (data.idempotencyKey) {
    const existing = await prisma.activity.findUnique({
      where: {
        userId_idempotencyKey: {
          userId: req.userId!,
          idempotencyKey: data.idempotencyKey,
        },
      },
      include: { splits: { orderBy: { kilometer: 'asc' } } },
    });
    if (existing) {
      res.status(200).json({ success: true, alreadySaved: true, activity: serializeActivity(existing) });
      return;
    }
  }

  try {
    const activity = await prisma.activity.create({
      data: {
        userId: req.userId!,
        activityType: data.activityType,
        recordingMode: data.recordingMode,
        distance: data.distanceMeters,
        duration: data.activeDurationSeconds ?? data.durationSeconds,
        totalElapsedDuration: data.totalElapsedSeconds ?? data.durationSeconds,
        targetDistance: data.targetDistanceMeters ?? null,
        pace: data.averagePaceSecondsPerKm,
        speed: data.averageSpeedKmh,
        calories: calorieCalculation.calories,
        calorieMetCode: calorieCalculation.calorieMetCode,
        calorieMetValue: calorieCalculation.calorieMetValue,
        calorieWeightKg: calorieCalculation.calorieWeightKg,
        calorieDurationMinutes: calorieCalculation.calorieDurationMinutes,
        calorieMethodVersion: calorieCalculation.calorieMethodVersion,
        startedAt: data.startedAt,
        completedAt: data.completedAt,
        gpsData: data.gpsData as object | undefined,
        routeData: data.routeData == null
          ? undefined
          : data.routeData as object,
        idempotencyKey: data.idempotencyKey,
        splits: data.timePerKm ? { create: data.timePerKm } : undefined,
      },
      include: { splits: { orderBy: { kilometer: 'asc' } } },
    });
    res.status(201).json({ success: true, activity: serializeActivity(activity) });
  } catch (error) {
    if (data.idempotencyKey && typeof error === 'object' && error !== null && 'code' in error && error.code === 'P2002') {
      const existing = await prisma.activity.findUnique({
        where: {
          userId_idempotencyKey: {
            userId: req.userId!,
            idempotencyKey: data.idempotencyKey,
          },
        },
        include: { splits: { orderBy: { kilometer: 'asc' } } },
      });
      if (existing) {
        res.status(200).json({ success: true, alreadySaved: true, activity: serializeActivity(existing) });
        return;
      }
    }
    console.error('Activity save error:', error);
    res.status(500).json({ success: false, message: 'Failed to save activity' });
  }
});

activityRouter.get('/:id', async (req: AuthenticatedRequest, res) => {
  try {
    const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const activityId = BigInt(String(rawId));
    const activity = await prisma.activity.findFirst({
      where: { id: activityId, userId: req.userId! },
      include: { splits: { orderBy: { kilometer: 'asc' } } },
    });

    if (!activity) {
      res.status(404).json({ success: false, message: 'Activity not found' });
      return;
    }

    res.json({ success: true, activity: serializeActivity(activity) });
  } catch (err) {
    res.status(400).json({ success: false, message: 'Invalid activity id' });
  }
});

activityRouter.delete('/:id', async (req: AuthenticatedRequest, res) => {
  try {
    const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const activityId = BigInt(String(rawId));
    const activity = await prisma.activity.findFirst({
      where: { id: activityId, userId: req.userId! },
    });

    if (!activity) {
      res.status(404).json({ success: false, message: 'Activity not found' });
      return;
    }

    await prisma.activity.delete({ where: { id: activityId } });
    res.json({ success: true, message: 'Activity deleted successfully' });
  } catch (err) {
    res.status(400).json({ success: false, message: 'Invalid activity id' });
  }
});