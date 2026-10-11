import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAuth, type AuthenticatedRequest } from '../middleware/auth.js';
import { generateCandidateRoutes } from '../services/routingService.js';
import { rankCandidateRoutes } from '../services/routeRankingService.js';

export const routeRouter = Router();

const generateSchema = z.object({
  activity: z.enum(['walking', 'jogging', 'running', 'cycling']).optional(),
  activityType: z.enum(['walking', 'jogging', 'running', 'cycling']).optional(),
  targetDistanceKm: z.number().min(0.5).max(100),
  preferences: z.object({
    avoidMajorRoads: z.boolean().optional(),
    preferSidewalks: z.boolean().optional(),
    preferLoop: z.boolean().optional(),
    preferCyclingInfrastructure: z.boolean().optional(),
    avoidHills: z.boolean().optional(),
  }).default({}),
  startLocation: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  }),
});

// Generate and rank routes (can be accessed by authenticated user or guest)
routeRouter.post('/generate', async (req, res) => {
  const parsed = generateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      message: 'Invalid route generation parameters',
      errors: parsed.error.flatten(),
    });
    return;
  }

  const { targetDistanceKm, preferences, startLocation } = parsed.data;
  const activity = parsed.data.activity || parsed.data.activityType || 'running';

  try {
    // 1. Generate real OSRM candidate routes
    const candidates = await generateCandidateRoutes(
      activity,
      targetDistanceKm,
      preferences,
      startLocation
    );

    if (candidates.length === 0) {
      res.status(404).json({
        success: false,
        message: `Could not generate a valid route within 2 km of the requested ${targetDistanceKm} km distance. Try adjusting the target distance or route preferences.`,
      });
      return;
    }

    // 2. Rank only distance-valid candidates deterministically
    const rankedRoutes = await rankCandidateRoutes(
      activity,
      targetDistanceKm,
      preferences,
      candidates
    );

    if (rankedRoutes.length === 0) {
      res.status(404).json({
        success: false,
        message: `Could not generate a valid route within 2 km of the requested ${targetDistanceKm} km distance. Try adjusting the target distance or route preferences.`,
      });
      return;
    }

    res.json({
      success: true,
      routes: rankedRoutes,
      meta: {
        totalGenerated: candidates.length,
        activity,
        targetDistanceKm,
        startLocation,
      },
    });
  } catch (error: any) {
    console.error('Route generation failed:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate routes. Please check connection to routing service.',
    });
  }
});

// Evaluate route features
routeRouter.post('/evaluate', async (req, res) => {
  const { routes, targetDistanceKm } = req.body;
  if (!Array.isArray(routes)) {
    res.status(400).json({ success: false, message: 'Routes array required' });
    return;
  }
  res.json({ success: true, evaluated: routes });
});

// Recommend routes
routeRouter.post('/recommend', async (req, res) => {
  const { activity, targetDistanceKm, preferences, routes } = req.body;
  if (!Array.isArray(routes)) {
    res.status(400).json({ success: false, message: 'Routes array required' });
    return;
  }

  const target = Number(targetDistanceKm ?? 5);
  if (!Number.isFinite(target) || target < 0.5 || target > 100) {
    res.status(400).json({ success: false, message: 'Target distance must be between 0.5 and 100 km' });
    return;
  }

  const ranked = await rankCandidateRoutes(
    activity || 'running',
    target,
    preferences || {},
    routes
  );
  res.json({ success: true, rankedRoutes: ranked });
});

// Save a selected route to user's saved routes
routeRouter.post('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { activityType, distanceKm, durationSeconds, score, routeData } = req.body;
    const route = await prisma.route.create({
      data: {
        userId: req.userId!,
        activityType: activityType || 'running',
        distance: Number(distanceKm || 0),
        duration: durationSeconds ? Math.round(Number(durationSeconds)) : null,
        score: score ? Number(score) : null,
        routeData: routeData || {},
      },
    });

    res.status(201).json({
      success: true,
      route: {
        id: route.id.toString(),
        userId: route.userId?.toString(),
        activityType: route.activityType,
        distanceKm: Number(route.distance),
        durationSeconds: route.duration,
        score: route.score ? Number(route.score) : null,
        routeData: route.routeData,
        createdAt: route.createdAt.toISOString(),
      },
    });
  } catch (err: any) {
    res.status(500).json({ success: false, message: 'Failed to save route' });
  }
});

// Get user's saved routes
routeRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const routes = await prisma.route.findMany({
      where: { userId: req.userId! },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      success: true,
      routes: routes.map((r) => ({
        id: r.id.toString(),
        userId: r.userId?.toString(),
        activityType: r.activityType,
        distanceKm: Number(r.distance),
        durationSeconds: r.duration,
        score: r.score ? Number(r.score) : null,
        routeData: r.routeData,
        createdAt: r.createdAt.toISOString(),
      })),
    });
  } catch (err: any) {
    res.status(500).json({ success: false, message: 'Failed to load routes' });
  }
});

// Get specific route by id
routeRouter.get('/:id', async (req, res) => {
  try {
    const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const routeId = BigInt(String(rawId));
    const route = await prisma.route.findUnique({
      where: { id: routeId },
    });

    if (!route) {
      res.status(404).json({ success: false, message: 'Route not found' });
      return;
    }

    res.json({
      success: true,
      route: {
        id: route.id.toString(),
        userId: route.userId?.toString(),
        activityType: route.activityType,
        distanceKm: Number(route.distance),
        durationSeconds: route.duration,
        score: route.score ? Number(route.score) : null,
        routeData: route.routeData,
        createdAt: route.createdAt.toISOString(),
      },
    });
  } catch (err: any) {
    res.status(400).json({ success: false, message: 'Invalid route id' });
  }
});
