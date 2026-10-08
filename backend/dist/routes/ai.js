import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { handleRouteRecommendation, handleFitnessInsights, handleAiHealth, } from '../controllers/aiController.js';
export const aiRouter = Router();
// Health check — no auth required
aiRouter.get('/health', handleAiHealth);
// Authenticated endpoints
aiRouter.post('/route-recommendation', requireAuth, handleRouteRecommendation);
aiRouter.post('/fitness-insights', requireAuth, handleFitnessInsights);
