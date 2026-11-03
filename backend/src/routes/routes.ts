import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAuth, type AuthenticatedRequest } from '../middleware/auth.js';
import {
  generateCandidateRoutes,
  getMaximumDistanceDeviationKm,
  RoutingServiceError,
  type RoutePreferences,
} from '../services/routingService.js';
import { rankCandidateRoutes } from '../services/routeRankingService.js';
import {
  explainUnavailableDistance,
  interpretRoutePreferences,
  isGroqEnabled,
} from '../services/groqService.js';

export const routeRouter = Router();

const generateSchema = z.object({
  activity: z.enum(['walking', 'jogging', 'running', 'cycling']).optional(),
  activityType: z.enum(['walking', 'jogging', 'running', 'cycling']).optional(),
  targetDistanceKm: z.number().finite().positive(),
  preferences: z.object({
    avoidMajorRoads: z.boolean().optional(),
    preferSidewalks: z.boolean().optional(),
    preferLoop: z.boolean().optional(),
    preferCyclingInfrastructure: z.boolean().optional(),
    avoidHills: z.boolean().optional(),
  }).default({}),
  additionalNotes: z.string().trim().max(500).optional(),
  startLocation: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  }),
}).refine(
  (input) => input.activity !== undefined || input.activityType !== undefined,
  { message: 'Activity is required', path: ['activity'] },
);

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

  const { targetDistanceKm, preferences, startLocation, additionalNotes } = parsed.data;
  const activity = parsed.data.activity ?? parsed.data.activityType;
  if (!activity) {
    res.status(400).json({ success: false, message: 'Select an activity type' });
    return;
  }

  try {
    const effectivePreferences: RoutePreferences = { ...preferences };
    const unsupportedPreferences: string[] = [];
    let notesInterpreted = false;
    if (additionalNotes && isGroqEnabled()) {
      try {
        const interpretation = await interpretRoutePreferences(additionalNotes);
        const interpretedPreferences = interpretation.constraints;
        for (const key of [
          'avoidMajorRoads',
          'preferSidewalks',
          'preferLoop',
          'preferCyclingInfrastructure',
          'avoidHills',
        ] as const) {
          if (effectivePreferences[key] === undefined && interpretedPreferences[key] !== null) {
            effectivePreferences[key] = interpretedPreferences[key];
          }
        }
        unsupportedPreferences.push(...interpretation.unsupportedPreferences);
        notesInterpreted = true;
      } catch (error) {
        const errorCode = typeof error === 'object' && error !== null && 'code' in error
          ? String(error.code)
          : 'PREFERENCE_INTERPRETATION_FAILED';
        console.warn(`Groq route preference interpretation unavailable (${errorCode}); using structured preferences only`);
      }
    }
    if (activity !== 'cycling' && effectivePreferences.avoidMajorRoads) {
      unsupportedPreferences.push(
        'Avoiding major roads cannot currently be verified for pedestrian routes.',
      );
    }
    if (activity !== 'cycling' && effectivePreferences.preferCyclingInfrastructure) {
      unsupportedPreferences.push(
        'Cycling infrastructure preference applies only to cycling routes.',
      );
    }

    // Valhalla is the authority for route geometry, access, and distance.
    const candidates = await generateCandidateRoutes(
      activity,
      targetDistanceKm,
      effectivePreferences,
      startLocation
    );

    const maximumDistanceDeviationKm = getMaximumDistanceDeviationKm();
    const rankedRoutes = await rankCandidateRoutes(
      activity,
      targetDistanceKm,
      effectivePreferences,
      candidates
    );

    if (rankedRoutes.length === 0) {
      let explanation: string | undefined;
      let suggestions: string[] = [];
      if (candidates.length > 0 && isGroqEnabled()) {
        try {
          const insight = await explainUnavailableDistance(
            activity,
            targetDistanceKm,
            maximumDistanceDeviationKm,
            candidates.map((candidate) => candidate.distanceKm),
          );
          explanation = insight.explanation;
          suggestions = insight.suggestions;
        } catch (error) {
          const errorCode = typeof error === 'object' && error !== null && 'code' in error
            ? String(error.code)
            : 'DISTANCE_EXPLANATION_FAILED';
          console.warn(`Groq distance explanation unavailable (${errorCode}); using deterministic guidance`);
        }
      }
      res.status(404).json({
        success: false,
        message: explanation ??
          `No valid route was found within ${maximumDistanceDeviationKm} km of your ${targetDistanceKm} km target. Try a nearby distance or change the loop preference.`,
        suggestions,
        preferencesNotInterpreted: Boolean(additionalNotes) && !notesInterpreted,
        unsupportedPreferences,
        provider: 'valhalla',
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
        maximumDistanceDeviationKm,
        closeCandidateAvailable: true,
        rankingSource: rankedRoutes[0].rankingSource,
        notesInterpreted,
        unsupportedPreferences,
        startLocation,
      },
    });
  } catch (error: unknown) {
    if (error instanceof RoutingServiceError) {
      console.error(`Route generation failed (${error.providerStatus ?? error.statusCode})`);
      res.status(error.statusCode).json({
        success: false,
        message: error.message,
        provider: 'valhalla',
      });
      return;
    }
    console.error('Route generation failed:', error);
    res.status(500).json({
      success: false,
      message: 'Route generation failed unexpectedly. Please retry.',
      provider: 'valhalla',
    });
  }
});

for (const endpoint of ['/evaluate', '/recommend']) {
  routeRouter.post(endpoint, (_req, res) => {
    res.status(410).json({
      success: false,
      message: 'Client-supplied route geometry is no longer accepted. Use POST /api/routes/generate to route and rank candidates through Valhalla.',
      code: 'VALHALLA_GENERATION_REQUIRED',
    });
  });
}

// Save a selected route to user's saved routes
routeRouter.post('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { activityType, distanceKm, durationSeconds, score } = req.body;
    const route = await prisma.route.create({
      data: {
        userId: req.userId!,
        activityType: activityType || 'running',
        distance: Number(distanceKm || 0),
        duration: durationSeconds ? Math.round(Number(durationSeconds)) : null,
        score: score ? Number(score) : null,
        routeData: {},
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
routeRouter.get('/:id', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    if (!/^\d+$/.test(String(rawId))) {
      res.status(400).json({ success: false, message: 'Invalid route id' });
      return;
    }
    const routeId = BigInt(String(rawId));
    const route = await prisma.route.findFirst({
      where: { id: routeId, userId: req.userId! },
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
