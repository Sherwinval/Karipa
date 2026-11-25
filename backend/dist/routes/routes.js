import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { decryptLocationData, encryptLocationData } from '../lib/locationEncryption.js';
import { requireAuth } from '../middleware/auth.js';
import { globalRouteQueue } from '../services/routeQueueService.js';
import { generateCandidateRoutes, getMaximumDistanceDeviationKm, RoutingServiceError, } from '../services/routingService.js';
import { rankCandidateRoutes } from '../services/routeRankingService.js';
import { explainUnavailableDistance, interpretRoutePreferences, isGroqEnabled, } from '../services/groqService.js';
export const routeRouter = Router();
const generateSchema = z.object({
    activity: z.enum(['walking', 'jogging', 'running', 'cycling']).optional(),
    activityType: z.enum(['walking', 'jogging', 'running', 'cycling']).optional(),
    targetDistanceKm: z.number().finite().positive(),
    targetDistanceToleranceKm: z.number().finite().positive().optional(),
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
}).refine((input) => input.activity !== undefined || input.activityType !== undefined, { message: 'Activity is required', path: ['activity'] });
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
    const job = globalRouteQueue.createJob();
    globalRouteQueue.bindResponseClose(res, job.id);
    try {
        const effectivePreferences = { ...preferences };
        const unsupportedPreferences = [];
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
                ]) {
                    if (effectivePreferences[key] === undefined && interpretedPreferences[key] !== null) {
                        effectivePreferences[key] = interpretedPreferences[key];
                    }
                }
                unsupportedPreferences.push(...interpretation.unsupportedPreferences);
                notesInterpreted = true;
            }
            catch (error) {
                const errorCode = typeof error === 'object' && error !== null && 'code' in error
                    ? String(error.code)
                    : 'PREFERENCE_INTERPRETATION_FAILED';
                console.warn(`Groq route preference interpretation unavailable (${errorCode}); using structured preferences only`);
            }
        }
        if (activity !== 'cycling' && effectivePreferences.avoidMajorRoads) {
            unsupportedPreferences.push('Avoiding major roads cannot currently be verified for pedestrian routes.');
        }
        if (activity !== 'cycling' && effectivePreferences.preferCyclingInfrastructure) {
            unsupportedPreferences.push('Cycling infrastructure preference applies only to cycling routes.');
        }
        const { targetDistanceToleranceKm } = parsed.data;
        // Valhalla is the authority for route geometry, access, and distance.
        const candidates = await generateCandidateRoutes(activity, targetDistanceKm, effectivePreferences, startLocation, { jobId: job.id, targetDistanceToleranceKm });
        const maximumDistanceDeviationKm = getMaximumDistanceDeviationKm(targetDistanceToleranceKm);
        const rankedRoutes = await rankCandidateRoutes(activity, targetDistanceKm, effectivePreferences, candidates, undefined, targetDistanceToleranceKm);
        if (rankedRoutes.length === 0) {
            let explanation;
            let suggestions = [];
            if (candidates.length > 0 && isGroqEnabled()) {
                try {
                    const insight = await explainUnavailableDistance(activity, targetDistanceKm, maximumDistanceDeviationKm, candidates.map((candidate) => candidate.distanceKm));
                    explanation = insight.explanation;
                    suggestions = insight.suggestions;
                }
                catch (error) {
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
        job.status = 'completed';
        job.result = rankedRoutes;
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
                jobId: job.id,
            },
        });
    }
    catch (error) {
        if (error && typeof error === 'object' && error.statusCode === 503) {
            if (error.retryAfterSeconds) {
                res.setHeader('Retry-After', String(error.retryAfterSeconds));
            }
            res.status(503).json({
                success: false,
                message: error.message || 'Route generation queue is full. Please try again later.',
                provider: 'valhalla',
            });
            return;
        }
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
// Asynchronous route generation endpoint (returns 202 Accepted with jobId)
routeRouter.post('/generate-async', async (req, res) => {
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
    const job = globalRouteQueue.createJob();
    // Process job asynchronously in background
    (async () => {
        try {
            const effectivePreferences = { ...preferences };
            const unsupportedPreferences = [];
            let notesInterpreted = false;
            if (additionalNotes && isGroqEnabled()) {
                try {
                    const interpretation = await interpretRoutePreferences(additionalNotes);
                    for (const key of [
                        'avoidMajorRoads',
                        'preferSidewalks',
                        'preferLoop',
                        'preferCyclingInfrastructure',
                        'avoidHills',
                    ]) {
                        if (effectivePreferences[key] === undefined && interpretation.constraints[key] !== null) {
                            effectivePreferences[key] = interpretation.constraints[key];
                        }
                    }
                    unsupportedPreferences.push(...interpretation.unsupportedPreferences);
                    notesInterpreted = true;
                }
                catch (error) {
                    console.warn('Groq route preference interpretation unavailable; using structured preferences only');
                }
            }
            if (activity !== 'cycling' && effectivePreferences.avoidMajorRoads) {
                unsupportedPreferences.push('Avoiding major roads cannot currently be verified for pedestrian routes.');
            }
            if (activity !== 'cycling' && effectivePreferences.preferCyclingInfrastructure) {
                unsupportedPreferences.push('Cycling infrastructure preference applies only to cycling routes.');
            }
            const candidates = await generateCandidateRoutes(activity, targetDistanceKm, effectivePreferences, startLocation, { jobId: job.id, targetDistanceToleranceKm: parsed.data.targetDistanceToleranceKm });
            if (job.status === 'cancelled')
                return;
            const rankedRoutes = await rankCandidateRoutes(activity, targetDistanceKm, effectivePreferences, candidates, undefined, parsed.data.targetDistanceToleranceKm);
            if (job.status === 'cancelled')
                return;
            const maximumDistanceDeviationKm = getMaximumDistanceDeviationKm(parsed.data.targetDistanceToleranceKm);
            job.status = 'completed';
            job.result = {
                success: true,
                routes: rankedRoutes,
                meta: {
                    totalGenerated: candidates.length,
                    activity,
                    targetDistanceKm,
                    maximumDistanceDeviationKm,
                    closeCandidateAvailable: rankedRoutes.length > 0,
                    rankingSource: rankedRoutes[0]?.rankingSource,
                    notesInterpreted,
                    unsupportedPreferences,
                    startLocation,
                    jobId: job.id,
                },
            };
            job.completedAt = Date.now();
        }
        catch (err) {
            if (job.status === 'cancelled')
                return;
            job.status = 'failed';
            job.error = err?.message || 'Asynchronous route generation failed';
            job.completedAt = Date.now();
        }
    })();
    res.status(202).json({
        success: true,
        jobId: job.id,
        status: job.status,
        message: 'Route generation job queued successfully',
    });
});
// Check status of asynchronous route generation job
routeRouter.get('/jobs/:jobId', (req, res) => {
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = globalRouteQueue.getJob(jobId);
    if (!job) {
        res.status(404).json({
            success: false,
            message: 'Job not found or expired',
        });
        return;
    }
    res.json({
        success: true,
        job: {
            id: job.id,
            status: job.status,
            result: job.result,
            error: job.error,
            createdAt: job.createdAt,
            completedAt: job.completedAt,
        },
    });
});
// Cancel an active or queued route generation job
const handleCancelJob = (req, res) => {
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = globalRouteQueue.getJob(jobId);
    if (!job) {
        res.status(404).json({
            success: false,
            message: 'Job not found or already completed/expired',
        });
        return;
    }
    const cancelled = globalRouteQueue.cancelJob(jobId, 'Cancelled by user request');
    if (!cancelled) {
        res.status(409).json({
            success: false,
            message: `Job ${jobId} is already ${job.status} and cannot be cancelled`,
            jobId,
            status: job.status,
        });
        return;
    }
    res.json({
        success: true,
        message: `Job ${jobId} cancelled successfully`,
        jobId,
        status: 'cancelled',
    });
};
routeRouter.delete('/jobs/:jobId', handleCancelJob);
routeRouter.post('/jobs/:jobId/cancel', handleCancelJob);
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
routeRouter.post('/', requireAuth, async (req, res) => {
    try {
        const { activityType, distanceKm, durationSeconds, score } = req.body;
        const route = await prisma.route.create({
            data: {
                userId: req.userId,
                activityType: activityType || 'running',
                distance: Number(distanceKm || 0),
                duration: durationSeconds ? Math.round(Number(durationSeconds)) : null,
                score: score ? Number(score) : null,
                routeData: encryptLocationData({}),
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
                routeData: decryptLocationData(route.routeData),
                createdAt: route.createdAt.toISOString(),
            },
        });
    }
    catch (error) {
        console.error('Route save error:', error);
        res.status(500).json({ success: false, message: 'Failed to save route' });
    }
});
// Get user's saved routes
routeRouter.get('/', requireAuth, async (req, res) => {
    try {
        const routes = await prisma.route.findMany({
            where: { userId: req.userId },
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
                routeData: decryptLocationData(r.routeData),
                createdAt: r.createdAt.toISOString(),
            })),
        });
    }
    catch (error) {
        console.error('Saved routes load error:', error);
        res.status(500).json({ success: false, message: 'Failed to load routes' });
    }
});
// Get specific route by id
routeRouter.get('/:id', requireAuth, async (req, res) => {
    const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    if (!/^\d+$/.test(String(rawId))) {
        res.status(400).json({ success: false, message: 'Invalid route id' });
        return;
    }
    try {
        const routeId = BigInt(String(rawId));
        const route = await prisma.route.findFirst({
            where: { id: routeId, userId: req.userId },
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
                routeData: decryptLocationData(route.routeData),
                createdAt: route.createdAt.toISOString(),
            },
        });
    }
    catch (error) {
        console.error('Saved route load error:', error);
        res.status(500).json({ success: false, message: 'Failed to load route' });
    }
});
