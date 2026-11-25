import { Router, type RequestHandler } from 'express';
import { prisma } from '../lib/prisma.js';
import { PasswordRecoveryService, RecoveryError, recoveryDigest, recoveryEmailSchema,
  recoveryVerifySchema, recoveryResetSchema } from '../services/passwordRecoveryService.js';

export const passwordRecoveryRouter = Router();
const service = new PasswordRecoveryService();

// Shared database buckets work across processes/restarts. Never trust forwarded
// IP headers directly; Express trust proxy must be restricted to the real proxy.
export const recoveryRateLimit: RequestHandler = async (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  try {
    const operation = req.path === '/resend' ? '/request' : req.path;
    const limits: [string, number][] = [[`ip:${req.ip ?? req.socket.remoteAddress}`, 30]];
    if (typeof req.body?.email === 'string') limits.push([`email:${req.body.email.trim().toLowerCase()}`, 5]);
    if (typeof req.body?.challengeId === 'string') limits.push([`challenge:${req.body.challengeId}`, 10]);
    for (const [identity, limit] of limits) {
      const key = recoveryDigest(`rate:${operation}:${identity}`);
      const rows = await prisma.$queryRaw<{ count: number; expires_at: Date }[]>`
        INSERT INTO recovery_rate_limits (key, count, expires_at)
        VALUES (${key}, 1, NOW() + INTERVAL '15 minutes')
        ON CONFLICT (key) DO UPDATE SET
          count = CASE WHEN recovery_rate_limits.expires_at <= NOW() THEN 1 ELSE recovery_rate_limits.count + 1 END,
          expires_at = CASE WHEN recovery_rate_limits.expires_at <= NOW() THEN NOW() + INTERVAL '15 minutes' ELSE recovery_rate_limits.expires_at END
        RETURNING count, expires_at
      `;
      if (rows[0].count > limit) {
        const seconds = Math.max(1, Math.ceil((rows[0].expires_at.getTime() - Date.now()) / 1000));
        res.setHeader('Retry-After', seconds);
        res.status(429).json({ success: false, message: 'Too many recovery attempts. Please try again later.', retryAfter: seconds });
        return;
      }
    }
    next();
  } catch {
    res.status(503).json({ success: false, message: 'Password recovery is temporarily unavailable. Please try again later.' });
  }
};

passwordRecoveryRouter.use(recoveryRateLimit);
for (const path of ['/request', '/resend', '/verify', '/reset']) {
  passwordRecoveryRouter.post(path, async (req, res) => {
    try {
      if (path === '/request' || path === '/resend') {
        const parsed = recoveryEmailSchema.safeParse(req.body);
        if (!parsed.success) { res.status(400).json({ success: false, message: 'Enter a valid email address.' }); return; }
        res.json(await service.request(parsed.data.email));
      } else if (path === '/verify') {
        const parsed = recoveryVerifySchema.safeParse(req.body);
        if (!parsed.success) { res.status(400).json({ success: false, message: 'Enter the six-digit code or request a new one.' }); return; }
        res.json(await service.verify(parsed.data.challengeId, parsed.data.otp));
      } else {
        const parsed = recoveryResetSchema.safeParse(req.body);
        if (!parsed.success) { res.status(400).json({ success: false, message: 'Use a valid reset session and a password of at least 8 characters. If your password is long, try a shorter password.' }); return; }
        res.json(await service.reset(parsed.data.challengeId, parsed.data.authorization, parsed.data.password));
      }
    } catch (error) {
      if (error instanceof RecoveryError) {
        if (error.retryAfter) res.setHeader('Retry-After', error.retryAfter);
        res.status(error.status).json({ success: false, message: error.message, retryAfter: error.retryAfter });
      } else {
        // Deliberately omit provider/database errors: they may contain secrets.
        res.status(503).json({ success: false, message: 'Password recovery is temporarily unavailable. Please try again later.' });
      }
    }
  });
}
