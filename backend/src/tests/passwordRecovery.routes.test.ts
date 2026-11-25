import express from 'express';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ query: vi.fn(), user: vi.fn() }));
vi.mock('../lib/prisma.js', () => ({ prisma: { $queryRaw: mocks.query, user: { findUnique: mocks.user } } }));
import { passwordRecoveryRouter } from '../routes/passwordRecovery.js';
import { PasswordRecoveryService } from '../services/passwordRecoveryService.js';
import { requireAuth } from '../middleware/auth.js';

const app = express(); app.use(express.json());
app.use('/password', passwordRecoveryRouter);
app.get('/protected', requireAuth, (_req, res) => { res.json({ success: true }); });

beforeEach(() => {
  vi.restoreAllMocks(); mocks.query.mockReset(); mocks.user.mockReset();
  process.env.JWT_SECRET = 'test-only-jwt-secret';
  process.env.PASSWORD_RECOVERY_SECRET = 'test-only-recovery-secret-at-least-32-bytes';
  const buckets = new Map<string, number>();
  mocks.query.mockImplementation(async (_sql, key: string) => {
    const count = (buckets.get(key) ?? 0) + 1; buckets.set(key, count);
    return [{ count, expires_at: new Date(Date.now() + 900_000) }];
  });
});

describe('recovery endpoints', () => {
  it('shares request/resend account rate limits and supplies Retry-After', async () => {
    const send = vi.spyOn(PasswordRecoveryService.prototype, 'request').mockResolvedValue({
      success: true, message: 'If an account matches', challengeId: '00000000-0000-4000-8000-000000000000', expiresIn: 600, resendAfter: 60 });
    for (let n = 0; n < 5; n++) {
      expect((await request(app).post(`/password/${n % 2 ? 'resend' : 'request'}`).send({ email: 'alex@example.com' })).status).toBe(200);
    }
    const response = await request(app).post('/password/request').send({ email: 'alex@example.com' });
    expect(response.status).toBe(429); expect(response.headers['retry-after']).toBeDefined();
    expect(response.headers['cache-control']).toBe('no-store'); expect(send).toHaveBeenCalledTimes(5);
  });

  for (const operation of ['verify', 'reset']) {
    it(`rate limits ${operation} attempts and rejects malformed payloads`, async () => {
      for (let n = 0; n < 10; n++) {
        expect((await request(app).post(`/password/${operation}`).send({ challengeId: 'invalid' })).status).toBe(400);
      }
      expect((await request(app).post(`/password/${operation}`).send({ challengeId: 'invalid' })).status).toBe(429);
    });
  }
  it('fails closed if the shared rate-limit database is unavailable', async () => {
    mocks.query.mockRejectedValue(new Error('database unavailable'));
    expect((await request(app).post('/password/request').send({ email: 'alex@example.com' })).status).toBe(503);
  });
  it('never accepts an email alone as reset authorization', async () => {
    expect((await request(app).post('/password/reset').send({ email: 'alex@example.com', password: 'new-password' })).status).toBe(400);
  });
});

describe('session revocation', () => {
  it('accepts existing legacy tokens until their account is reset', async () => {
    const token = jwt.sign({}, process.env.JWT_SECRET!, { subject: '91', expiresIn: '7d' });
    mocks.user.mockResolvedValue({ sessionVersion: 0 });
    expect((await request(app).get('/protected').auth(token, { type: 'bearer' })).status).toBe(200);
    mocks.user.mockResolvedValue({ sessionVersion: 1 });
    expect((await request(app).get('/protected').auth(token, { type: 'bearer' })).status).toBe(401);
  });
  it('accepts the current session version and rejects a revoked version', async () => {
    mocks.user.mockResolvedValue({ sessionVersion: 2 });
    for (const version of [1, 2]) {
      const token = jwt.sign({ sessionVersion: version }, process.env.JWT_SECRET!, { subject: '91', expiresIn: '7d' });
      expect((await request(app).get('/protected').auth(token, { type: 'bearer' })).status).toBe(version === 2 ? 200 : 401);
    }
  });
});
