import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { prisma } from './lib/prisma.js';
import { activityRouter } from './routes/activities.js';
import { authRouter } from './routes/auth.js';
import { aiRouter } from './routes/ai.js';
import { routeRouter } from './routes/routes.js';

dotenv.config({ path: ['.env', '../.env'] });

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json());
app.use('/api/auth', authRouter);
app.use('/api/activities', activityRouter);
app.use('/api/ai', aiRouter);
app.use('/api/routes', routeRouter);

app.get('/api/health', (_req, res) => {
  res.status(200).json({
    success: true,
    message: 'Karipa API is running',
  });
});

app.get('/api/health/database', async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({
      success: true,
      message: 'Database connection is healthy',
    });
  } catch (error) {
    console.error('Database health check failed', error);
    res.status(503).json({
      success: false,
      message: 'Database connection is unavailable',
    });
  }
});

app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
  });
});

app.listen(port, () => {
  console.log(`Karipa backend listening on port ${port}`);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
});

process.on('SIGINT', async () => {
  await prisma.$disconnect();
});

export default app;
