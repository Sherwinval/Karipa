import { beforeEach, describe, expect, it, vi } from 'vitest';
import bcrypt from 'bcryptjs';
import type { PasswordRecovery, PrismaClient } from '@prisma/client';
import { PasswordRecoveryService, recoveryPasswordSchema } from '../services/passwordRecoveryService.js';

// Stateful database double exercises the production service; database concurrency
// is covered separately by the opt-in PostgreSQL integration test.
function fixture() {
  let now = new Date('2026-11-25T12:00:00Z');
  let row: PasswordRecovery | null = null;
  let accountExists = true;
  const user = { id: 91n, passwordHash: 'old-hash', sessionVersion: 0, otp: null, otpExpiresAt: null };
  const delivery = vi.fn(async (_email: string, _otp: string) => {});
  const matches = (where: Record<string, unknown>) => row &&
    Object.entries(where).every(([key, value]) => {
      const current = row![key as keyof PasswordRecovery];
      if (value && typeof value === 'object' && 'gt' in value) return current instanceof Date && current > (value as { gt: Date }).gt;
      return current === value;
    });
  const tx = {
    user: {
      findUnique: vi.fn(async () => accountExists ? user : null),
      update: vi.fn(async ({ data }) => {
        Object.assign(user, data, { sessionVersion: user.sessionVersion + 1 });
        return user;
      }),
    },
    passwordRecovery: {
      findUnique: vi.fn(async ({ where }) => matches(where) ? { ...row! } : null),
      upsert: vi.fn(async ({ create }) => { row = { ...create }; return row; }),
      update: vi.fn(async ({ data }) => {
        const attempts = typeof data.attempts === 'object' ? row!.attempts + data.attempts.increment : row!.attempts;
        Object.assign(row!, data, { attempts }); return row;
      }),
      updateMany: vi.fn(async ({ where, data }) => {
        if (!matches(where)) return { count: 0 };
        Object.assign(row!, data); return { count: 1 };
      }),
    },
  };
  const db = { ...tx, $transaction: vi.fn(async (action) => action(tx)) } as unknown as PrismaClient;
  const service = new PasswordRecoveryService(db, delivery, () => now);
  return { service, delivery, user, tx, get row() { return row!; },
    advance: (ms: number) => { now = new Date(now.getTime() + ms); },
    missingAccount: () => { accountExists = false; },
    code: () => delivery.mock.calls.at(-1)![1],
  };
}

beforeEach(() => { process.env.PASSWORD_RECOVERY_SECRET = 'test-only-recovery-secret-at-least-32-bytes'; });

describe('password recovery', () => {
  it('subtracts email delivery time from the displayed expiry and resend interval', async () => {
    const f = fixture();
    f.delivery.mockImplementationOnce(async () => { f.advance(20_000); });
    const result = await f.service.request('alex@example.com');
    expect(result.expiresIn).toBe(580);
    expect(result.resendAfter).toBe(40);
  });

  it('uses six digits, stores only a keyed hash, and expires after ten minutes', async () => {
    const f = fixture(); const result = await f.service.request('alex@example.com');
    expect(f.code()).toMatch(/^\d{6}$/);
    expect(f.row.otpHash).toMatch(/^[a-f0-9]{64}$/);
    expect(f.row.otpHash).not.toBe(f.code());
    expect(result.expiresIn).toBe(600);
    f.advance(600_000);
    await expect(f.service.verify(result.challengeId, f.code())).rejects.toThrow('expired');
  });

  it('enforces cooldown, replaces the challenge, and rejects the previous code', async () => {
    const f = fixture(); const first = await f.service.request('alex@example.com');
    const oldCode = f.code();
    await expect(f.service.request('alex@example.com')).rejects.toMatchObject({ status: 429, retryAfter: 60 });
    f.advance(60_000);
    const second = await f.service.request('alex@example.com');
    expect(second.challengeId).not.toBe(first.challengeId);
    await expect(f.service.verify(first.challengeId, oldCode)).rejects.toThrow('no longer available');
    expect((await f.service.verify(second.challengeId, f.code())).success).toBe(true);
  });

  it('commits failed attempts and locks the challenge after five failures', async () => {
    const f = fixture(); const { challengeId } = await f.service.request('alex@example.com');
    const wrong = f.code() === '111111' ? '222222' : '111111';
    for (let i = 0; i < 5; i++) await expect(f.service.verify(challengeId, wrong)).rejects.toThrow();
    expect(f.row.attempts).toBe(5);
    await expect(f.service.verify(challengeId, f.code())).rejects.toThrow('Too many');
    expect(f.row.attempts).toBe(5);
  });

  it('returns the same request shape for unknown accounts and never authorizes them', async () => {
    const f = fixture(); f.missingAccount();
    const result = await f.service.request('missing@example.com');
    expect(result.success).toBe(true); expect(f.delivery).toHaveBeenCalledOnce();
    expect(result.message).toContain('If an account');
    await expect(f.service.verify(result.challengeId, f.code())).rejects.toThrow('incorrect');
    expect(f.row.resetHash).toBeNull();
  });

  it('fails closed on email delivery errors and leaves no usable challenge', async () => {
    const f = fixture(); f.delivery.mockRejectedValueOnce(new Error('SMTP failed'));
    await expect(f.service.request('alex@example.com')).rejects.toMatchObject({ status: 503 });
    expect(f.row.otpHash).toBeNull(); expect(f.row.consumedAt).not.toBeNull();
  });

  it('requires verification and binds the authorization to its challenge', async () => {
    const f = fixture(); const { challengeId } = await f.service.request('alex@example.com');
    await expect(f.service.reset(challengeId, 'a'.repeat(64), 'new-password')).rejects.toThrow('invalid');
    const { authorization } = await f.service.verify(challengeId, f.code());
    expect(f.row.resetHash).not.toBe(authorization); expect(f.row.otpHash).toBeNull();
    await expect(f.service.verify(challengeId, f.code())).rejects.toThrow();
    await expect(f.service.reset('00000000-0000-4000-8000-000000000000', authorization, 'new-password')).rejects.toThrow();
    await expect(f.service.reset(challengeId, 'b'.repeat(64), 'new-password')).rejects.toThrow();
    expect(f.user.passwordHash).toBe('old-hash');
  });

  it('changes the bcrypt password, revokes sessions, consumes authorization, and prevents replay', async () => {
    const f = fixture(); const { challengeId } = await f.service.request('alex@example.com');
    const { authorization } = await f.service.verify(challengeId, f.code());
    await f.service.reset(challengeId, authorization, 'new-password');
    expect(await bcrypt.compare('new-password', f.user.passwordHash)).toBe(true);
    expect(f.user.sessionVersion).toBe(1);
    expect(f.row.resetHash).toBeNull(); expect(f.row.consumedAt).not.toBeNull();
    await expect(f.service.reset(challengeId, authorization, 'replayed-password')).rejects.toThrow();
    expect(await bcrypt.compare('new-password', f.user.passwordHash)).toBe(true);
  });

  it('expires reset authorization after five minutes', async () => {
    const f = fixture(); const { challengeId } = await f.service.request('alex@example.com');
    const { authorization } = await f.service.verify(challengeId, f.code()); f.advance(300_000);
    await expect(f.service.reset(challengeId, authorization, 'new-password')).rejects.toThrow('expired');
  });

  it('resending invalidates a previously verified reset authorization', async () => {
    const f = fixture(); const { challengeId } = await f.service.request('alex@example.com');
    const { authorization } = await f.service.verify(challengeId, f.code()); f.advance(60_000);
    await f.service.request('alex@example.com');
    await expect(f.service.reset(challengeId, authorization, 'new-password')).rejects.toThrow('invalid');
  });

  it('validates the existing minimum and bcrypt byte limit', () => {
    expect(recoveryPasswordSchema.safeParse('short').success).toBe(false);
    expect(recoveryPasswordSchema.safeParse('long-enough').success).toBe(true);
    expect(recoveryPasswordSchema.safeParse('x'.repeat(73)).success).toBe(false);
    expect(recoveryPasswordSchema.safeParse('😀'.repeat(19)).success).toBe(false);
  });
});
