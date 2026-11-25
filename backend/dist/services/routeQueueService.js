import crypto from 'crypto';
export const ALGORITHM_VERSION = 'v1.0.0';
/**
 * Deterministically stringify an object by recursively sorting its keys.
 */
export function deterministicStringify(obj) {
    if (obj === null || typeof obj !== 'object') {
        return JSON.stringify(obj);
    }
    if (Array.isArray(obj)) {
        return `[${obj.map(deterministicStringify).join(',')}]`;
    }
    const sortedKeys = Object.keys(obj).sort();
    const pairs = sortedKeys.map((key) => `${JSON.stringify(key)}:${deterministicStringify(obj[key])}`);
    return `{${pairs.join(',')}}`;
}
export function haversineDistanceKm([lat1, lon1], [lat2, lon2]) {
    const toRadians = Math.PI / 180;
    const deltaLat = (lat2 - lat1) * toRadians;
    const deltaLon = (lon2 - lon1) * toRadians;
    const a = Math.sin(deltaLat / 2) ** 2 +
        Math.cos(lat1 * toRadians) * Math.cos(lat2 * toRadians) * Math.sin(deltaLon / 2) ** 2;
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
export class RouteQueueService {
    config;
    queue = [];
    activeCount = 0;
    lastDispatchTimestamp = 0;
    pausedUntilTimestamp = 0;
    jobs = new Map();
    cache = new Map();
    constructor(customConfig = {}) {
        this.config = {
            concurrency: Number(process.env.VALHALLA_CONCURRENCY || 1),
            minDelayMs: process.env.VALHALLA_MIN_DELAY_MS !== undefined
                ? Number(process.env.VALHALLA_MIN_DELAY_MS)
                : (process.env.NODE_ENV === 'test' ? 0 : 1000),
            maxQueueSize: Number(process.env.VALHALLA_MAX_QUEUE_SIZE || 50),
            jobMaxWaitTimeMs: Number(process.env.VALHALLA_JOB_MAX_WAIT_TIME_MS || 240000),
            requestTimeoutMs: Number(process.env.VALHALLA_REQUEST_TIMEOUT_MS || 8000),
            syncTimeoutMs: Number(process.env.VALHALLA_SYNC_TIMEOUT_MS || 25000),
            cacheTtlMs: Number(process.env.VALHALLA_CACHE_TTL_MS || 600000), // 10 mins
            cacheMaxEntries: Number(process.env.VALHALLA_CACHE_MAX_ENTRIES || 500),
            ...customConfig,
        };
    }
    getConfig() {
        return { ...this.config };
    }
    getPendingQueueLength() {
        return this.queue.length;
    }
    getActiveCount() {
        return this.activeCount;
    }
    /**
     * Generates a deterministic SHA-256 cache key.
     */
    generateCacheKey(activityType, targetDistanceKm, startLocation, preferences, options = {}) {
        const latRounded = startLocation.latitude.toFixed(5);
        const lonRounded = startLocation.longitude.toFixed(5);
        const serializedPrefs = deterministicStringify(preferences);
        const serializedOptions = deterministicStringify(options);
        const rawKey = `${ALGORITHM_VERSION}:${activityType.toLowerCase()}:${targetDistanceKm.toFixed(2)}:${latRounded},${lonRounded}:${serializedPrefs}:${serializedOptions}`;
        return crypto.createHash('sha256').update(rawKey).digest('hex');
    }
    /**
     * Retrieves a cached value if non-expired and start point matches within tolerance.
     */
    getCachedRoute(cacheKey, requestedStart) {
        const entry = this.cache.get(cacheKey);
        if (!entry)
            return null;
        if (Date.now() - entry.timestamp > this.config.cacheTtlMs) {
            this.cache.delete(cacheKey);
            return null;
        }
        const distKm = haversineDistanceKm([requestedStart.latitude, requestedStart.longitude], entry.startLocation);
        if (distKm > 0.5) {
            return null;
        }
        return entry.value;
    }
    /**
     * Sets a route into the cache with start location validation metadata.
     */
    setCachedRoute(cacheKey, requestedStart, value) {
        if (this.cache.size >= this.config.cacheMaxEntries) {
            // Remove oldest entry
            const firstKey = this.cache.keys().next().value;
            if (firstKey)
                this.cache.delete(firstKey);
        }
        this.cache.set(cacheKey, {
            timestamp: Date.now(),
            startLocation: [requestedStart.latitude, requestedStart.longitude],
            value,
        });
    }
    /**
     * Creates a new Job for tracking status.
     */
    createJob() {
        const jobId = `job_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
        const job = {
            id: jobId,
            status: 'queued',
            createdAt: Date.now(),
            abortController: new AbortController(),
        };
        this.jobs.set(jobId, job);
        return job;
    }
    getJob(jobId) {
        const job = this.jobs.get(jobId);
        if (!job)
            return undefined;
        // Check for expiration
        if ((job.status === 'queued' || job.status === 'processing') &&
            Date.now() - job.createdAt > this.config.jobMaxWaitTimeMs) {
            job.status = 'expired';
            job.error = 'Route generation job expired due to excessive queue delay or provider latency. Please retry.';
            job.abortController.abort();
            this.cancelPendingTasksForJob(jobId);
        }
        return job;
    }
    /**
     * Safely binds an Express response `close` listener to detect premature disconnects.
     * Checks `!res.writableEnded` before cancelling job.
     */
    bindResponseClose(res, jobId) {
        res.on('close', () => {
            if (!res.writableEnded) {
                this.cancelJob(jobId, 'Client disconnected prematurely');
            }
        });
    }
    /**
     * Cancels a job and aborts both pending tasks and in-flight fetch signals.
     */
    cancelJob(jobId, reason = 'Job cancelled') {
        const job = this.jobs.get(jobId);
        if (!job)
            return false;
        if (job.status === 'completed' || job.status === 'failed' || job.status === 'expired' || job.status === 'cancelled') {
            return false;
        }
        job.status = 'cancelled';
        job.error = reason;
        job.completedAt = Date.now();
        job.abortController.abort();
        this.cancelPendingTasksForJob(jobId);
        return true;
    }
    cancelPendingTasksForJob(jobId) {
        this.queue = this.queue.filter((task) => {
            if (task.jobId === jobId) {
                task.reject(new Error('Job cancelled or expired'));
                return false;
            }
            return true;
        });
    }
    /**
     * Enqueues a task for throttled execution.
     */
    enqueue(jobId, fn) {
        const job = this.getJob(jobId);
        if (!job || job.status === 'cancelled' || job.status === 'expired') {
            return Promise.reject(new Error(`Job ${jobId} is not active`));
        }
        if (this.queue.length >= this.config.maxQueueSize) {
            const err = new Error('Route generation queue is full. Please retry in a few moments.');
            err.statusCode = 503;
            err.retryAfterSeconds = 10;
            return Promise.reject(err);
        }
        return new Promise((resolve, reject) => {
            const task = {
                taskId: `task_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
                jobId,
                fn,
                resolve,
                reject,
                abortController: job.abortController,
            };
            this.queue.push(task);
            this.processQueue();
        });
    }
    /**
     * Handles HTTP 429 Retry-After parsing and pauses the queue.
     */
    handleRateLimit429(retryAfterHeader) {
        let pauseMs = 10000; // default 10s backoff if header missing
        if (retryAfterHeader) {
            const seconds = Number(retryAfterHeader);
            if (!isNaN(seconds) && seconds > 0) {
                pauseMs = seconds * 1000;
            }
            else {
                const parsedDate = Date.parse(retryAfterHeader);
                if (!isNaN(parsedDate) && parsedDate > Date.now()) {
                    pauseMs = parsedDate - Date.now();
                }
            }
        }
        this.pausedUntilTimestamp = Math.max(this.pausedUntilTimestamp, Date.now() + pauseMs);
    }
    async processQueue() {
        if (this.activeCount >= this.config.concurrency || this.queue.length === 0) {
            return;
        }
        const now = Date.now();
        // Respect provider 429 Retry-After pause
        if (now < this.pausedUntilTimestamp) {
            const waitTime = this.pausedUntilTimestamp - now;
            setTimeout(() => this.processQueue(), waitTime);
            return;
        }
        // Respect inter-request delay
        const timeSinceLastDispatch = now - this.lastDispatchTimestamp;
        if (timeSinceLastDispatch < this.config.minDelayMs) {
            const waitTime = this.config.minDelayMs - timeSinceLastDispatch;
            setTimeout(() => this.processQueue(), waitTime);
            return;
        }
        const task = this.queue.shift();
        if (!task)
            return;
        const job = this.getJob(task.jobId);
        if (!job || job.status === 'cancelled' || job.status === 'expired') {
            task.reject(new Error('Job was cancelled or expired before execution'));
            this.processQueue();
            return;
        }
        if (job.status === 'queued') {
            job.status = 'processing';
            job.startedAt = Date.now();
        }
        this.activeCount++;
        this.lastDispatchTimestamp = Date.now();
        // Setup task timeout signal
        const timeoutController = new AbortController();
        const timeoutId = setTimeout(() => {
            timeoutController.abort(new Error('Valhalla request timed out'));
        }, this.config.requestTimeoutMs);
        // Combine job abort signal and fetch timeout signal
        const combinedSignal = this.createCombinedSignal([
            task.abortController.signal,
            timeoutController.signal,
        ]);
        try {
            const result = await task.fn(combinedSignal);
            clearTimeout(timeoutId);
            task.resolve(result);
        }
        catch (err) {
            clearTimeout(timeoutId);
            task.reject(err);
        }
        finally {
            this.activeCount--;
            this.processQueue();
        }
    }
    createCombinedSignal(signals) {
        const controller = new AbortController();
        for (const signal of signals) {
            if (signal.aborted) {
                controller.abort(signal.reason);
                return controller.signal;
            }
            signal.addEventListener('abort', () => controller.abort(signal.reason), { once: true });
        }
        return controller.signal;
    }
}
export const globalRouteQueue = new RouteQueueService();
