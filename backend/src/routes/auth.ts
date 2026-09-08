import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';

const credentialsSchema = z.object({ name: z.string().min(1).optional(), email: z.string().email(), password: z.string().min(8) });
export const authRouter = Router();

authRouter.post('/register', async (req, res) => {
  const parsed = credentialsSchema.extend({ name: z.string().min(1) }).safeParse(req.body);
  if (!parsed.success) { res.status(400).json({ success: false, message: 'Invalid registration data' }); return; }
  const passwordHash = await bcrypt.hash(parsed.data.password, 12);
  const user = await prisma.user.create({ data: { name: parsed.data.name, email: parsed.data.email, passwordHash } });
  res.status(201).json({ success: true, userId: user.id.toString() });
});

authRouter.post('/login', async (req, res) => {
  const parsed = credentialsSchema.omit({ name: true }).safeParse(req.body);
  if (!parsed.success) { res.status(400).json({ success: false, message: 'Invalid login data' }); return; }
  const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
  if (!user || !(await bcrypt.compare(parsed.data.password, user.passwordHash))) { res.status(401).json({ success: false, message: 'Invalid credentials' }); return; }
  const token = jwt.sign({}, process.env.JWT_SECRET!, { subject: user.id.toString(), expiresIn: '7d' });
  res.json({ success: true, token, userId: user.id.toString() });
});