import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAuth, type AuthenticatedRequest } from '../middleware/auth.js';
import {
  getRouteRecommendation,
  getFitnessInsights,
  checkHealth,
  GeminiServiceError,
  type ActivitySummary,
} from '../services/geminiService.js';
import type { Response } from 'express';

// ---------------------------------------------------------------------------
// Request validation schemas
// ---------------------------------------------------------------------------

const routeRecommendationSchema = z.object({
  activityType: z.enum(['walking', 'jogging', 'running', 'cycling']),
  targetDistanceKm: z.number().positive().optional(),
  routePreferences: z
    .object({
      avoidHills: z.boolean().optional(),
      preferScenic: z.boolean().optional(),
      preferShade: z.boolean().optional(),
      preferLoop: z.boolean().optional(),
      preferredTerrain: z.string().max(100).optional(),
    })
    .optional(),
  startLocation: z
    .object({
      lat: z.number().min(-90).max(90),
      lng: z.number().min(-180).max(180),
    })
    .optional(),
  additionalNotes: z.string().max(500).optional(),
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const MAX_HISTORY_ACTIVITIES = 10;

/**
 * Fetch the user's most recent activities and convert them to the summary
 * format the Gemini service expects.
 */
async function fetchActivityHistory(userId: bigint): Promise<ActivitySummary[]> {
  const activities = await prisma.activity.findMany({
    where: { userId },
    orderBy: { completedAt: 'desc' },
    take: MAX_HISTORY_ACTIVITIES,
  });

  return activities.map((a) => ({
    activityType: a.activityType,
    distanceKm: Number((Number(a.distance) / 1000).toFixed(2)),
    durationSeconds: a.duration,
    averagePaceMinPerKm: a.pace !== null ? Number((Number(a.pace) / 60).toFixed(2)) : null,
    averageSpeedKmh: a.speed !== null ? Number(Number(a.speed).toFixed(2)) : null,
    averageHeartRate: a.averageHeartRate,
    calories: a.calories !== null ? Number(a.calories) : null,
    date: a.completedAt.toISOString().slice(0, 10),
  }));
}

/**
 * Standard error response helper.
 */
function sendError(res: Response, error: unknown) {
  if (error instanceof GeminiServiceError) {
    res.status(error.statusCode).json({
      success: false,
      message: error.message,
      code: error.code,
    });
    return;
  }

  console.error('Unexpected AI controller error:', error);
  res.status(500).json({
    success: false,
    message: 'An unexpected error occurred while processing the AI request',
    code: 'INTERNAL_ERROR',
  });
}

// ---------------------------------------------------------------------------
// Route recommendation handler
// ---------------------------------------------------------------------------

export async function handleRouteRecommendation(req: AuthenticatedRequest, res: Response) {
  // Validate request body
  const parsed = routeRecommendationSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      message: 'Invalid request data',
      errors: parsed.error.flatten(),
    });
    return;
  }

  try {
    // Fetch user activity history from the database
    const activities = await fetchActivityHistory(req.userId!);

    // Call the Gemini service
    const recommendation = await getRouteRecommendation(parsed.data, activities);

    res.json({
      success: true,
      recommendation,
    });
  } catch (error) {
    sendError(res, error);
  }
}

// ---------------------------------------------------------------------------
// Fitness insights handler
// ---------------------------------------------------------------------------

export async function handleFitnessInsights(req: AuthenticatedRequest, res: Response) {
  try {
    const activities = await fetchActivityHistory(req.userId!);

    if (activities.length === 0) {
      res.status(404).json({
        success: false,
        message: 'No activity history found. Complete some activities first to get fitness insights.',
        code: 'NO_ACTIVITY_DATA',
      });
      return;
    }

    const insights = await getFitnessInsights(activities);

    res.json({
      success: true,
      insights,
    });
  } catch (error) {
    sendError(res, error);
  }
}

// ---------------------------------------------------------------------------
// Health check handler
// ---------------------------------------------------------------------------

export async function handleAiHealth(_req: AuthenticatedRequest, res: Response) {
  const result = await checkHealth();

  const statusCode = result.ok ? 200 : 503;
  res.status(statusCode).json({
    success: result.ok,
    message: result.ok ? 'Gemini AI service is operational' : 'Gemini AI service is unavailable',
    model: result.model,
    ...(result.error && { error: result.error }),
  });
}
