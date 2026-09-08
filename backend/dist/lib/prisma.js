import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
dotenv.config({ path: ['.env', '../.env'] });
export const prisma = new PrismaClient();
