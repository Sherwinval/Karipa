import jwt from 'jsonwebtoken';
import type { NextFunction, Request, Response } from 'express';
import { prisma } from '../lib/prisma.js';

export type AuthenticatedRequest = Request & { userId?: bigint };

export async function requireAuth(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  const header = req.header('authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;

  if (!token || !process.env.JWT_SECRET) {
    res.status(401).json({ success: false, message: 'Authentication required' });
    return;
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (typeof payload !== 'object' || payload === null || typeof payload.sub !== 'string') {
      throw new Error('Invalid token subject');
    }
    req.userId = BigInt(payload.sub);
    const user = await prisma.user.findUnique({ where: { id: req.userId }, select: { sessionVersion: true } });
    if (!user || (payload.sessionVersion ?? 0) !== user.sessionVersion) throw new Error('Revoked session');
    next();
  } catch {
    res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
}
