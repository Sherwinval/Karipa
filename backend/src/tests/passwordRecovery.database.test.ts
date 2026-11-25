import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import bcrypt from 'bcryptjs';
import { prisma } from '../lib/prisma.js';
import { PasswordRecoveryService } from '../services/passwordRecoveryService.js';

// Explicit opt-in: creates one isolated fixture account and deletes only that
// account and its cascading recovery challenges. Never sends real mail.
describe.skipIf(process.env.RUN_RECOVERY_DB_TESTS !== 'true')('PostgreSQL recovery transactions', () => {
  const email = `karipa-recovery-test-${randomUUID()}@example.invalid`;
  let userId: bigint;
  let otp = '';
  const originalSecret = process.env.PASSWORD_RECOVERY_SECRET;
  const service = new PasswordRecoveryService(prisma, async (_email, code) => { otp = code; });
  beforeAll(async () => {
    process.env.PASSWORD_RECOVERY_SECRET = 'isolated-database-test-recovery-secret-32-bytes';
    const user = await prisma.user.create({ data: { name: 'Recovery transaction fixture', email,
      passwordHash: await bcrypt.hash('original-test-password', 12), isVerified: true } });
    userId = user.id;
  });
  afterAll(async () => {
    if (userId) await prisma.user.delete({ where: { id: userId } });
    if (originalSecret === undefined) delete process.env.PASSWORD_RECOVERY_SECRET;
    else process.env.PASSWORD_RECOVERY_SECRET = originalSecret;
    await prisma.$disconnect();
  });
  it('allows exactly one concurrent reset, preserves the winner, and invalidates all challenges', async () => {
    const { challengeId } = await service.request(email);
    const { authorization } = await service.verify(challengeId, otp);
    await prisma.passwordRecovery.create({ data: { id: randomUUID(), emailHash: randomUUID(),
      userId, otpHash: 'a'.repeat(64), issuedAt: new Date(), expiresAt: new Date(Date.now() + 600_000) } });
    const results = await Promise.allSettled([
      service.reset(challengeId, authorization, 'first-test-password'),
      service.reset(challengeId, authorization, 'second-test-password'),
    ]);
    expect(results.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const winner = results[0].status === 'fulfilled' ? 'first-test-password' : 'second-test-password';
    expect(await bcrypt.compare(winner, user.passwordHash)).toBe(true);
    expect(await bcrypt.compare('original-test-password', user.passwordHash)).toBe(false);
    expect(user.sessionVersion).toBe(1);
    expect(await prisma.passwordRecovery.count({ where: { userId, consumedAt: null } })).toBe(0);
    await expect(service.reset(challengeId, authorization, 'third-test-password')).rejects.toThrow();
  }, 30_000);
});
