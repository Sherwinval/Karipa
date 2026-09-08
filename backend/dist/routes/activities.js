import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';
const activitySchema = z.object({
    activityType: z.enum(['walking', 'jogging', 'running', 'cycling']),
    distanceMeters: z.number().nonnegative(),
    durationSeconds: z.number().int().nonnegative(),
    averagePaceSecondsPerKm: z.number().nonnegative().optional(),
    averageSpeedKmh: z.number().nonnegative().optional(),
    averageHeartRate: z.number().int().positive().optional(),
    maximumHeartRate: z.number().int().positive().optional(),
    calories: z.number().nonnegative().optional(),
    startedAt: z.coerce.date(),
    completedAt: z.coerce.date(),
    routeData: z.unknown().optional(),
    gpsData: z.unknown().optional(),
    timePerKm: z.array(z.object({ kilometer: z.number().int().positive(), timeSeconds: z.number().int().nonnegative() })).optional(),
});
function serializeActivity(activity) {
    const distanceKm = Number(activity.distance) / 1000;
    return {
        id: activity.id.toString(),
        userId: activity.userId.toString(),
        activityType: activity.activityType,
        distanceKm: Number(distanceKm.toFixed(2)),
        durationSeconds: activity.duration,
        averagePaceMinPerKm: activity.pace === null ? null : Number((Number(activity.pace) / 60).toFixed(2)),
        averageSpeedKmh: activity.speed === null ? null : Number(Number(activity.speed).toFixed(2)),
        timePerKm: activity.splits.map((split) => ({ kilometer: split.kilometer, timeSeconds: split.timeSeconds })),
        averageHeartRate: activity.averageHeartRate,
        maximumHeartRate: activity.maximumHeartRate,
        calories: activity.calories === null ? null : Number(activity.calories),
        startedAt: activity.startedAt.toISOString(),
        completedAt: activity.completedAt.toISOString(),
        routeData: activity.routeData,
        gpsData: activity.gpsData,
    };
}
export const activityRouter = Router();
activityRouter.use(requireAuth);
activityRouter.get('/', async (req, res) => {
    const activities = await prisma.activity.findMany({
        where: { userId: req.userId },
        include: { splits: { orderBy: { kilometer: 'asc' } } },
        orderBy: { completedAt: 'desc' },
    });
    res.json({ success: true, activities: activities.map(serializeActivity) });
});
activityRouter.post('/', async (req, res) => {
    const parsed = activitySchema.safeParse(req.body);
    if (!parsed.success) {
        res.status(400).json({ success: false, message: 'Invalid activity data', errors: parsed.error.flatten() });
        return;
    }
    const data = parsed.data;
    const activity = await prisma.activity.create({
        data: {
            userId: req.userId,
            activityType: data.activityType,
            distance: data.distanceMeters,
            duration: data.durationSeconds,
            pace: data.averagePaceSecondsPerKm,
            speed: data.averageSpeedKmh,
            averageHeartRate: data.averageHeartRate,
            maximumHeartRate: data.maximumHeartRate,
            calories: data.calories,
            startedAt: data.startedAt,
            completedAt: data.completedAt,
            routeData: data.routeData,
            gpsData: data.gpsData,
            splits: data.timePerKm ? { create: data.timePerKm } : undefined,
        },
        include: { splits: { orderBy: { kilometer: 'asc' } } },
    });
    res.status(201).json({ success: true, activity: serializeActivity(activity) });
});
