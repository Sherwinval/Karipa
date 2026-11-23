import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { sendOtpEmail } from '../services/emailService.js';
import crypto from 'crypto';
import { requireAuth, type AuthenticatedRequest } from '../middleware/auth.js';

const credentialsSchema = z.object({ 
  name: z.string().min(1).optional(), 
  email: z.string().email(), 
  password: z.string().min(8) 
});

export const registrationSchema = credentialsSchema.extend({
  name: z.string().min(1),
  heightCm: z.number().finite().positive('Height must be greater than zero').optional(),
  weightKg: z.number().finite().positive('Weight must be greater than zero').optional(),
}).strict();

export const authRouter = Router();

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET is not configured');
  return secret;
}

const generateOtp = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

authRouter.post('/register', async (req, res) => {
  const parsed = registrationSchema.safeParse(req.body);
  if (!parsed.success) { 
    res.status(400).json({ success: false, message: 'Invalid registration data' }); 
    return; 
  }
  
  try {
    const existingUser = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    
    const otp = generateOtp();
    const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    
    if (existingUser) {
      if (existingUser.isVerified) {
        res.status(409).json({ success: false, message: 'Email already registered' });
        return;
      }
      
      // Update unverified user with new OTP and password
      const passwordHash = await bcrypt.hash(parsed.data.password, 12);
      await prisma.user.update({
        where: { email: parsed.data.email },
        data: {
          name: parsed.data.name,
          passwordHash,
          otp,
          otpExpiresAt,
          ...(parsed.data.heightCm !== undefined && { heightCm: parsed.data.heightCm }),
          ...(parsed.data.weightKg !== undefined && { weightKg: parsed.data.weightKg }),
        }
      });
      
      await sendOtpEmail(parsed.data.email, otp);
      res.status(200).json({ success: true, message: 'OTP sent to email', userId: existingUser.id.toString() });
      return;
    }
    
    const passwordHash = await bcrypt.hash(parsed.data.password, 12);
    const user = await prisma.user.create({ 
      data: { 
        name: parsed.data.name, 
        email: parsed.data.email, 
        passwordHash,
        otp,
        otpExpiresAt,
        isVerified: false,
        heightCm: parsed.data.heightCm,
        weightKg: parsed.data.weightKg,
      } 
    });
    
    await sendOtpEmail(parsed.data.email, otp);
    res.status(201).json({ success: true, message: 'OTP sent to email', userId: user.id.toString() });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

authRouter.post('/verify-otp', async (req, res) => {
  const schema = z.object({ email: z.string().email(), otp: z.string().length(6) });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) { 
    res.status(400).json({ success: false, message: 'Invalid request data' }); 
    return; 
  }
  
  try {
    const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    if (!user) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }
    
    if (user.isVerified) {
      res.status(400).json({ success: false, message: 'User already verified' });
      return;
    }
    
    if (user.otp !== parsed.data.otp || !user.otpExpiresAt || user.otpExpiresAt < new Date()) {
      res.status(401).json({ success: false, message: 'Invalid or expired OTP' });
      return;
    }
    
    const updatedUser = await prisma.user.update({
      where: { id: user.id },
      data: { isVerified: true, otp: null, otpExpiresAt: null }
    });
    
    const token = jwt.sign({}, getJwtSecret(), { subject: updatedUser.id.toString(), expiresIn: '7d' });
    res.json({ success: true, message: 'Email verified successfully', token, userId: updatedUser.id.toString(), name: updatedUser.name });
  } catch (error) {
    console.error('OTP Verification error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

authRouter.post('/resend-otp', async (req, res) => {
  const schema = z.object({ email: z.string().email() });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) { 
    res.status(400).json({ success: false, message: 'Invalid request data' }); 
    return; 
  }
  
  try {
    const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    if (!user) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }
    
    if (user.isVerified) {
      res.status(400).json({ success: false, message: 'User already verified' });
      return;
    }
    
    // Cooldown check (optional: restrict to 1 request per minute)
    if (user.otpExpiresAt && user.otpExpiresAt.getTime() - Date.now() > 14 * 60 * 1000) {
       res.status(429).json({ success: false, message: 'Please wait before requesting another OTP' });
       return;
    }
    
    const otp = generateOtp();
    const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    
    await prisma.user.update({
      where: { id: user.id },
      data: { otp, otpExpiresAt }
    });
    
    await sendOtpEmail(user.email, otp);
    res.json({ success: true, message: 'New OTP sent to email' });
  } catch (error) {
    console.error('Resend OTP error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

authRouter.post('/login', async (req, res) => {
  const parsed = credentialsSchema.omit({ name: true }).safeParse(req.body);
  if (!parsed.success) { res.status(400).json({ success: false, message: 'Invalid login data' }); return; }
  
  try {
    const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    if (!user || !(await bcrypt.compare(parsed.data.password, user.passwordHash))) { 
      res.status(401).json({ success: false, message: 'Invalid email or password' }); 
      return; 
    }
    
    if (!user.isVerified) {
      res.status(403).json({ success: false, message: 'Please verify your email to login', needsVerification: true });
      return;
    }
    
    const token = jwt.sign({}, getJwtSecret(), { subject: user.id.toString(), expiresIn: '7d' });
    res.json({ success: true, token, userId: user.id.toString(), name: user.name });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

authRouter.get('/me', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
      select: { id: true, name: true, email: true, createdAt: true },
    });
    if (!user) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }
    res.json({
      success: true,
      user: {
        id: user.id.toString(),
        name: user.name,
        email: user.email,
        createdAt: user.createdAt.toISOString(),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

export const profileUpdateSchema = z.object({
  name: z.string().trim().min(1, 'Name cannot be empty').max(80).optional(),
  heightCm: z.number().finite().positive('Height must be greater than zero').nullable().optional(),
  weightKg: z.number().finite().positive('Weight must be greater than zero').nullable().optional(),
  photoData: z.string()
    .max(3_500_000)
    .regex(/^data:image\/(?:jpeg|png|webp);base64,[A-Za-z0-9+/]+={0,2}$/, 'Profile photo must be a supported base64 image')
    .nullable()
    .optional(),
}).strict().refine(
  (profile) => profile.name !== undefined || profile.heightCm !== undefined ||
    profile.weightKg !== undefined || profile.photoData !== undefined,
  { message: 'Provide a profile name, photo, height, or weight' },
);

authRouter.get('/profile', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
      select: { name: true, heightCm: true, weightKg: true, photoData: true },
    });
    if (!user) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }
    res.json({
      success: true,
      profile: {
        name: user.name,
        heightCm: user.heightCm === null ? null : Number(user.heightCm),
        weightKg: user.weightKg === null ? null : Number(user.weightKg),
        photoData: user.photoData,
      },
    });
  } catch (error) {
    console.error('Profile load error:', error);
    res.status(500).json({ success: false, message: 'Failed to load profile measurements' });
  }
});

authRouter.patch('/profile', requireAuth, async (req: AuthenticatedRequest, res) => {
  const parsed = profileUpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      message: 'Enter a valid profile name or positive height in cm or weight in kg.',
      errors: parsed.error.flatten(),
    });
    return;
  }

  try {
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: {
        ...(parsed.data.name !== undefined && { name: parsed.data.name }),
        ...(parsed.data.heightCm !== undefined && { heightCm: parsed.data.heightCm }),
        ...(parsed.data.weightKg !== undefined && { weightKg: parsed.data.weightKg }),
        ...(parsed.data.photoData !== undefined && { photoData: parsed.data.photoData }),
      },
      select: { name: true, heightCm: true, weightKg: true, photoData: true },
    });
    res.json({
      success: true,
      profile: {
        name: user.name,
        heightCm: user.heightCm === null ? null : Number(user.heightCm),
        weightKg: user.weightKg === null ? null : Number(user.weightKg),
        ...(parsed.data.photoData !== undefined && { photoData: user.photoData }),
      },
    });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ success: false, message: 'Failed to save profile' });
  }
});