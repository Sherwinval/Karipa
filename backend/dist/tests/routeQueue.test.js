import { describe, expect, it, vi } from 'vitest';
import { deterministicStringify, haversineDistanceKm, RouteQueueService, } from '../services/routeQueueService.js';
describe('RouteQueueService', () => {
    it('should deterministically stringify objects regardless of key insertion order', () => {
        const objA = { b: 2, a: 1, c: { y: 'test', x: 10 } };
        const objB = { a: 1, c: { x: 10, y: 'test' }, b: 2 };
        expect(deterministicStringify(objA)).toEqual(deterministicStringify(objB));
    });
    it('should generate identical cache keys for equivalent parameters', () => {
        const queue = new RouteQueueService();
        const startLoc = { latitude: 14.59951, longitude: 120.98421 };
        const prefsA = { preferLoop: true, avoidHills: false };
        const prefsB = { avoidHills: false, preferLoop: true };
        const keyA = queue.generateCacheKey('running', 5.0, startLoc, prefsA);
        const keyB = queue.generateCacheKey('running', 5.0, startLoc, prefsB);
        expect(keyA).toBe(keyB);
    });
    it('should validate cached route starting location tolerance (<= 0.5 km)', () => {
        const queue = new RouteQueueService();
        const startLoc = { latitude: 14.5995, longitude: 120.9842 };
        const key = queue.generateCacheKey('running', 5.0, startLoc, {});
        queue.setCachedRoute(key, startLoc, [{ id: 'route-1' }]);
        // Exact location -> hit
        expect(queue.getCachedRoute(key, startLoc)).toEqual([{ id: 'route-1' }]);
        // Location within 100m -> hit
        const nearLoc = { latitude: 14.5999, longitude: 120.9845 };
        expect(haversineDistanceKm([startLoc.latitude, startLoc.longitude], [nearLoc.latitude, nearLoc.longitude])).toBeLessThan(0.5);
        expect(queue.getCachedRoute(key, nearLoc)).toEqual([{ id: 'route-1' }]);
        // Far location (> 0.5km) -> miss
        const farLoc = { latitude: 14.6500, longitude: 120.9842 };
        expect(haversineDistanceKm([startLoc.latitude, startLoc.longitude], [farLoc.latitude, farLoc.longitude])).toBeGreaterThan(0.5);
        expect(queue.getCachedRoute(key, farLoc)).toBeNull();
    });
    it('should throttle execution based on concurrency and delay config', async () => {
        const queue = new RouteQueueService({ concurrency: 1, minDelayMs: 50 });
        const job = queue.createJob();
        const order = [];
        const task1 = queue.enqueue(job.id, async () => {
            order.push(1);
            return 'res1';
        });
        const task2 = queue.enqueue(job.id, async () => {
            order.push(2);
            return 'res2';
        });
        const results = await Promise.all([task1, task2]);
        expect(results).toEqual(['res1', 'res2']);
        expect(order).toEqual([1, 2]);
    });
    it('should parse Retry-After headers and pause queue execution', () => {
        const queue = new RouteQueueService();
        queue.handleRateLimit429('5'); // 5 seconds
        expect(queue.pausedUntilTimestamp).toBeGreaterThan(Date.now());
    });
    it('should cancel job and abort tasks when response closes prematurely without writableEnded', () => {
        const queue = new RouteQueueService();
        const job = queue.createJob();
        const mockRes = {
            writableEnded: false,
            on: vi.fn((event, listener) => {
                if (event === 'close') {
                    listener();
                }
                return mockRes;
            }),
        };
        queue.bindResponseClose(mockRes, job.id);
        const updatedJob = queue.getJob(job.id);
        expect(updatedJob?.status).toBe('cancelled');
    });
    it('should mark jobs as expired if they exceed max wait time', () => {
        const queue = new RouteQueueService({ jobMaxWaitTimeMs: 100 });
        const job = queue.createJob();
        // Manually push creation time back
        job.createdAt = Date.now() - 200;
        const retrieved = queue.getJob(job.id);
        expect(retrieved?.status).toBe('expired');
        expect(retrieved?.error).toContain('expired');
    });
    it('should maintain strict cache separation between different target distances', () => {
        const queue = new RouteQueueService();
        const startLoc = { latitude: 14.5995, longitude: 120.9842 };
        const key5km = queue.generateCacheKey('running', 5.0, startLoc, {});
        const key10km = queue.generateCacheKey('running', 10.0, startLoc, {});
        expect(key5km).not.toBe(key10km);
        queue.setCachedRoute(key5km, startLoc, [{ id: 'route-5km' }]);
        queue.setCachedRoute(key10km, startLoc, [{ id: 'route-10km' }]);
        expect(queue.getCachedRoute(key5km, startLoc)).toEqual([{ id: 'route-5km' }]);
        expect(queue.getCachedRoute(key10km, startLoc)).toEqual([{ id: 'route-10km' }]);
    });
    it('should cancel active job and abort pending tasks when cancelJob is called', () => {
        const queue = new RouteQueueService();
        const job = queue.createJob();
        queue.cancelJob(job.id, 'User changed distance');
        const cancelledJob = queue.getJob(job.id);
        expect(cancelledJob?.status).toBe('cancelled');
        expect(cancelledJob?.error).toBe('User changed distance');
    });
});
