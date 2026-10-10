import { describe, it, expect } from 'vitest';
import request from 'supertest';
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
dotenv.config({ path: ['.env', '../.env'] });
import { prisma } from '../lib/prisma.js';
import { authRouter } from '../routes/auth.js';
import { activityRouter } from '../routes/activities.js';
import { routeRouter } from '../routes/routes.js';
import { generateCandidateRoutes } from '../services/routingService.js';
import { rankCandidateRoutesWithAi } from '../services/aiRecommendationService.js';
const app = express();
app.use(cors());
app.use(express.json());
app.use('/api/auth', authRouter);
app.use('/api/activities', activityRouter);
app.use('/api/routes', routeRouter);
describe('Routing Service & AI Recommendation', () => {
    it('generates real candidate routes for given coordinates and target distance', async () => {
        // Coordinates in Manila
        const startLocation = { latitude: 14.5995, longitude: 120.9842 };
        const candidates = await generateCandidateRoutes('running', 3.0, { preferLoop: true }, startLocation);
        expect(candidates).toBeDefined();
        expect(Array.isArray(candidates)).toBe(true);
        expect(candidates.length).toBeGreaterThan(0);
        const first = candidates[0];
        expect(first.distanceKm).toBeGreaterThan(0);
        expect(first.geometry).toBeDefined();
        expect(first.geometry.type).toBe('LineString');
        expect(first.geometry.coordinates.length).toBeGreaterThan(1);
        expect(first.features).toBeDefined();
    }, 15000);
    it('ranks candidate routes with AI recommendation logic', async () => {
        const mockCandidates = [
            {
                id: 'route-1',
                name: 'Route Alpha',
                activityType: 'running',
                distanceKm: 5.1,
                distanceMeters: 5100,
                durationSeconds: 1800,
                geometry: { type: 'LineString', coordinates: [[120.98, 14.59], [120.99, 14.60]] },
                features: {
                    distanceDeltaKm: 0.1,
                    isLoop: true,
                    sidewalkRatio: 0.9,
                    majorRoadRatio: 0.05,
                    cyclingLaneRatio: 0.2,
                    roadTypes: ['Parkway', 'Residential'],
                },
            },
            {
                id: 'route-2',
                name: 'Route Beta',
                activityType: 'running',
                distanceKm: 8.5,
                distanceMeters: 8500,
                durationSeconds: 3000,
                geometry: { type: 'LineString', coordinates: [[120.98, 14.59], [121.05, 14.65]] },
                features: {
                    distanceDeltaKm: 3.5,
                    isLoop: false,
                    sidewalkRatio: 0.4,
                    majorRoadRatio: 0.6,
                    cyclingLaneRatio: 0.1,
                    roadTypes: ['Highway'],
                },
            },
        ];
        const ranked = await rankCandidateRoutesWithAi('running', 5.0, { preferLoop: true, avoidMajorRoads: true }, mockCandidates);
        expect(ranked).toBeDefined();
        expect(ranked.length).toBe(2);
        expect(ranked[0].id).toBe('route-1');
        expect(ranked[0].isTopRecommendation).toBe(true);
        expect(ranked[0].score).toBeGreaterThan(ranked[1].score);
        expect(ranked[0].suitability).toBeDefined();
    });
});
describe('Full End-to-End API Suite', () => {
    const testEmail = `test-user-${Date.now()}@pathcraft.local`;
    const testPassword = 'Password123!';
    let authToken = '';
    let createdUserId = '';
    let createdActivityId = '';
    let createdRouteId = '';
    it('registers user, verifies account, and logs in', async () => {
        // 1. Register
        const regRes = await request(app)
            .post('/api/auth/register')
            .send({
            name: 'Test Runner',
            email: testEmail,
            password: testPassword,
        });
        expect(regRes.status).toBe(201);
        expect(regRes.body.success).toBe(true);
        // Direct verify for test runner
        const userInDb = await prisma.user.findUnique({ where: { email: testEmail } });
        expect(userInDb).toBeDefined();
        createdUserId = userInDb.id.toString();
        await prisma.user.update({
            where: { id: userInDb.id },
            data: { isVerified: true, otp: null },
        });
        // 2. Login
        const loginRes = await request(app)
            .post('/api/auth/login')
            .send({
            email: testEmail,
            password: testPassword,
        });
        expect(loginRes.status).toBe(200);
        expect(loginRes.body.success).toBe(true);
        expect(loginRes.body.token).toBeDefined();
        authToken = loginRes.body.token;
        // 3. Check /api/auth/me
        const meRes = await request(app)
            .get('/api/auth/me')
            .set('Authorization', `Bearer ${authToken}`);
        expect(meRes.status).toBe(200);
        expect(meRes.body.user.email).toBe(testEmail);
        expect(meRes.body.user.name).toBe('Test Runner');
    }, 15000);
    it('generates real routes via /api/routes/generate', async () => {
        const genRes = await request(app)
            .post('/api/routes/generate')
            .send({
            activity: 'running',
            targetDistanceKm: 3.5,
            preferences: { preferLoop: true, avoidMajorRoads: true },
            startLocation: { latitude: 14.5995, longitude: 120.9842 },
        });
        expect(genRes.status).toBe(200);
        expect(genRes.body.success).toBe(true);
        expect(genRes.body.routes.length).toBeGreaterThan(0);
        const topRoute = genRes.body.routes[0];
        expect(topRoute.geometry.coordinates.length).toBeGreaterThan(0);
        expect(topRoute.score).toBeGreaterThan(0);
    }, 15000);
    it('saves and retrieves routes', async () => {
        const saveRes = await request(app)
            .post('/api/routes')
            .set('Authorization', `Bearer ${authToken}`)
            .send({
            activityType: 'running',
            distanceKm: 5.2,
            durationSeconds: 1800,
            score: 91.5,
            routeData: { type: 'LineString', coordinates: [[120.98, 14.59], [120.99, 14.60]] },
        });
        expect(saveRes.status).toBe(201);
        createdRouteId = saveRes.body.route.id;
        const listRes = await request(app)
            .get('/api/routes')
            .set('Authorization', `Bearer ${authToken}`);
        expect(listRes.status).toBe(200);
        expect(listRes.body.routes.length).toBeGreaterThan(0);
        const getRes = await request(app).get(`/api/routes/${createdRouteId}`);
        expect(getRes.status).toBe(200);
        expect(getRes.body.route.id).toBe(createdRouteId);
    });
    it('records, retrieves, and deletes an activity', async () => {
        const createRes = await request(app)
            .post('/api/activities')
            .set('Authorization', `Bearer ${authToken}`)
            .send({
            activityType: 'running',
            distanceMeters: 5210,
            durationSeconds: 1820,
            averagePaceSecondsPerKm: 350,
            calories: 345,
            startedAt: new Date(Date.now() - 1820000).toISOString(),
            completedAt: new Date().toISOString(),
            gpsData: [{ latitude: 14.59, longitude: 120.98 }],
        });
        expect(createRes.status).toBe(201);
        expect(createRes.body.success).toBe(true);
        createdActivityId = createRes.body.activity.id;
        // List activities
        const listRes = await request(app)
            .get('/api/activities')
            .set('Authorization', `Bearer ${authToken}`);
        expect(listRes.status).toBe(200);
        expect(listRes.body.activities.some((a) => a.id === createdActivityId)).toBe(true);
        // Get single activity
        const getRes = await request(app)
            .get(`/api/activities/${createdActivityId}`)
            .set('Authorization', `Bearer ${authToken}`);
        expect(getRes.status).toBe(200);
        expect(getRes.body.activity.id).toBe(createdActivityId);
        expect(getRes.body.activity.distanceKm).toBeCloseTo(5.21, 1);
        // Delete activity
        const delRes = await request(app)
            .delete(`/api/activities/${createdActivityId}`)
            .set('Authorization', `Bearer ${authToken}`);
        expect(delRes.status).toBe(200);
        expect(delRes.body.success).toBe(true);
    });
    it('cleans up test user and associated records', async () => {
        if (createdUserId) {
            await prisma.user.delete({ where: { id: BigInt(createdUserId) } });
        }
    });
});
