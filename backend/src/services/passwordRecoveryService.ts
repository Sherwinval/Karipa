import { createHmac, randomInt, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { sendPasswordRecoveryEmail } from './emailService.js';

export const recoveryEmailSchema = z.object({ email: z.string().trim().email().max(254) });
export const recoveryPasswordSchema = z.string().min(8, 'Use at least 8 characters.')
  .refine(value => Buffer.byteLength(value, 'utf8') <= 72, 'This password is too long. Try a shorter password.');
export const recoveryVerifySchema = z.object({
  challengeId: z.string().uuid(), otp: z.string().regex(/^\d{6}$/),
});
export const recoveryResetSchema = z.object({
  challengeId: z.string().uuid(), authorization: z.string().regex(/^[a-f0-9]{64}$/),
  password: recoveryPasswordSchema,
});

export class RecoveryError extends Error {
  constructor(public status: number, message: string, public retryAfter?: number) { super(message); }
}

export function recoveryDigest(value: string): string {
  const secret = process.env.PASSWORD_RECOVERY_SECRET;
  if (!secret || Buffer.byteLength(secret) < 32) throw new Error('Configure PASSWORD_RECOVERY_SECRET (at least 32 bytes)');
  return createHmac('sha256', secret).update(value).digest('hex');
}

// PostgreSQL serializable transactions prevent simultaneous verification, resend,
// and reset from reusing a challenge. Retries contain database operations only.
export async function recoveryTransaction<T>(db: PrismaClient, action: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try { return await db.$transaction(action, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }); }
    catch (error) {
      if (attempt < 3 && error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2034') continue;
      throw error;
    }
  }
}

export class PasswordRecoveryService {
  constructor(
    private db: PrismaClient = prisma,
    private deliver = sendPasswordRecoveryEmail,
    private now = () => new Date(),
  ) {}

  async request(email: string) {
    const now = this.now();
    const emailHash = recoveryDigest(`email:${email.toLowerCase()}`);
    const id = randomUUID();
    const otp = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const expiresAt = new Date(now.getTime() + 600_000);
    await recoveryTransaction(this.db, async tx => {
      const previous = await tx.passwordRecovery.findUnique({ where: { emailHash } });
      if (previous && previous.issuedAt.getTime() + 60_000 > now.getTime()) {
        throw new RecoveryError(429, 'Please wait before requesting another code.',
          Math.ceil((previous.issuedAt.getTime() + 60_000 - now.getTime()) / 1000));
      }
      // Preserve the existing case-sensitive account lookup contract.
      const user = await tx.user.findUnique({ where: { email } });
      const data = { id, userId: user?.id ?? null, otpHash: null, issuedAt: now,
        expiresAt, attempts: 0, resetHash: null, resetExpiresAt: null, consumedAt: null };
      await tx.passwordRecovery.upsert({ where: { emailHash }, create: { ...data, emailHash }, update: data });
    });
    try {
      // Send identical mail for unknown addresses too: neither SMTP failure nor
      // delivery timing reveals account existence. These challenges cannot verify.
      await this.deliver(email, otp);
      await this.db.passwordRecovery.updateMany({ where: { id, consumedAt: null },
        data: { otpHash: recoveryDigest(`otp:${id}:${otp}`) } });
    } catch {
      // Failed deliveries never leave a usable code or pretend to succeed.
      await this.db.passwordRecovery.updateMany({ where: { id }, data: { otpHash: null, consumedAt: this.now() } });
      throw new RecoveryError(503, 'We could not send a recovery email. Please wait a minute and try again.');
    }
    return { success: true, message: 'If an account matches this email, you can use the code to reset its password.',
      challengeId: id, expiresIn: Math.max(0, Math.floor((expiresAt.getTime() - this.now().getTime()) / 1000)),
      resendAfter: Math.max(0, Math.ceil((now.getTime() + 60_000 - this.now().getTime()) / 1000)) };
  }

  async verify(challengeId: string, otp: string) {
    const authorization = randomBytes(32).toString('hex');
    const result = await recoveryTransaction(this.db, async tx => {
      const challenge = await tx.passwordRecovery.findUnique({ where: { id: challengeId } });
      const now = this.now();
      if (!challenge || challenge.consumedAt || challenge.resetHash || !challenge.otpHash) return 'This code is no longer available. Request a new code.';
      if (challenge.expiresAt <= now) return 'This code has expired. Request a new code.';
      if (challenge.attempts >= 5) return 'Too many incorrect attempts. Request a new code.';
      const matches = timingSafeEqual(Buffer.from(challenge.otpHash, 'hex'),
        Buffer.from(recoveryDigest(`otp:${challengeId}:${otp}`), 'hex'));
      // Commit the failed attempt rather than throwing and rolling it back.
      await tx.passwordRecovery.update({ where: { id: challengeId }, data: { attempts: { increment: 1 } } });
      if (!matches || !challenge.userId) return challenge.attempts >= 4
        ? 'Too many incorrect attempts. Request a new code.' : 'The code is incorrect. Check it and try again.';
      await tx.passwordRecovery.update({ where: { id: challengeId }, data: {
        otpHash: null, resetHash: recoveryDigest(`reset:${challengeId}:${authorization}`),
        resetExpiresAt: new Date(now.getTime() + 300_000),
      } });
      return null;
    });
    if (result) throw new RecoveryError(400, result);
    return { success: true, authorization, expiresIn: 300 };
  }

  async reset(challengeId: string, authorization: string, password: string) {
    recoveryPasswordSchema.parse(password);
    const passwordHash = await bcrypt.hash(password, 12);
    await recoveryTransaction(this.db, async tx => {
      const now = this.now();
      const challenge = await tx.passwordRecovery.findUnique({ where: { id: challengeId } });
      const resetHash = recoveryDigest(`reset:${challengeId}:${authorization}`);
      if (!challenge?.userId || challenge.consumedAt || !challenge.resetHash ||
        !challenge.resetExpiresAt || challenge.resetExpiresAt <= now ||
        !timingSafeEqual(Buffer.from(challenge.resetHash, 'hex'), Buffer.from(resetHash, 'hex'))) {
        throw new RecoveryError(400, 'Your reset session is invalid or has expired. Start again to request a new code.');
      }
      const consumed = await tx.passwordRecovery.updateMany({
        where: { id: challengeId, resetHash, consumedAt: null, resetExpiresAt: { gt: now } },
        data: { consumedAt: now, resetHash: null },
      });
      if (consumed.count !== 1) throw new RecoveryError(400, 'This reset session has already been used. Start again.');
      await tx.user.update({ where: { id: challenge.userId }, data: {
        passwordHash, sessionVersion: { increment: 1 }, otp: null, otpExpiresAt: null,
      } });
      await tx.passwordRecovery.updateMany({ where: { userId: challenge.userId },
        data: { consumedAt: now, otpHash: null, resetHash: null } });
    });
    return { success: true, message: 'Your password has been reset. Sign in with your new password.' };
  }
}
