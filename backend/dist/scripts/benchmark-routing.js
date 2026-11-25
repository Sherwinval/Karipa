import { performance } from 'perf_hooks';
import { generateCandidateRoutes } from '../services/routingService.js';
import { globalRouteQueue } from '../services/routeQueueService.js';
async function runBenchmarkForConcurrency(concurrency) {
    const baseLocation = { latitude: 14.59951, longitude: 120.98421 };
    const requests = Array.from({ length: concurrency }, (_, index) => ({
        id: index + 1,
        activity: 'running',
        targetDistanceKm: 5.0 + (index * 0.1), // slight distance variation to test cache miss
        startLocation: {
            latitude: baseLocation.latitude + (index * 0.0001),
            longitude: baseLocation.longitude + (index * 0.0001),
        },
        preferences: { preferLoop: index % 2 === 0 },
    }));
    const durations = [];
    let successful = 0;
    let failed = 0;
    const startMem = process.memoryUsage().rss / 1024 / 1024;
    console.log(`\n--- Starting Benchmark: ${concurrency} Concurrent Users ---`);
    const tasks = requests.map(async (req) => {
        const startTime = performance.now();
        try {
            await generateCandidateRoutes(req.activity, req.targetDistanceKm, req.preferences, req.startLocation);
            const elapsed = performance.now() - startTime;
            durations.push(elapsed);
            successful++;
        }
        catch (err) {
            const elapsed = performance.now() - startTime;
            durations.push(elapsed);
            failed++;
            console.warn(`Request #${req.id} failed (${elapsed.toFixed(0)}ms): ${err?.message}`);
        }
    });
    await Promise.allSettled(tasks);
    durations.sort((a, b) => a - b);
    const avgResponseTimeMs = durations.length > 0
        ? durations.reduce((a, b) => a + b, 0) / durations.length
        : 0;
    const p95Index = Math.floor(durations.length * 0.95);
    const p95ResponseTimeMs = durations[p95Index] || 0;
    const maxResponseTimeMs = durations[durations.length - 1] || 0;
    const endMem = process.memoryUsage().rss / 1024 / 1024;
    return {
        concurrencyLevel: concurrency,
        totalRequests: concurrency,
        successfulRequests: successful,
        failedRequests: failed,
        avgResponseTimeMs: Math.round(avgResponseTimeMs),
        p95ResponseTimeMs: Math.round(p95ResponseTimeMs),
        maxResponseTimeMs: Math.round(maxResponseTimeMs),
        memoryUsageMb: Math.round(endMem - startMem + endMem),
    };
}
async function main() {
    console.log('=== Karipa Routing Queue Benchmark Suite ===');
    console.log('Configured Queue:', globalRouteQueue.getConfig());
    const levels = [5, 10, 20, 30];
    const summary = [];
    for (const level of levels) {
        const result = await runBenchmarkForConcurrency(level);
        summary.push(result);
    }
    console.log('\n================ BENCHMARK SUMMARY ================');
    console.table(summary);
    console.log('====================================================\n');
}
if (process.argv[1]?.endsWith('benchmark-routing.ts') || process.argv[1]?.endsWith('benchmark-routing.js')) {
    main().catch(console.error);
}
