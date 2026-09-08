import { prisma } from '../lib/prisma.js';

const testEmail = `pathcraft-crud-${Date.now()}@example.test`;

try {
  const user = await prisma.user.create({
    data: {
      name: 'PathCraft CRUD Test',
      email: testEmail,
      passwordHash: 'test-only-hash',
    },
  });

  const activity = await prisma.activity.create({
    data: {
      userId: user.id,
      activityType: 'walking',
      distance: 2500,
      duration: 1800,
      startedAt: new Date('2026-01-01T10:00:00Z'),
      completedAt: new Date('2026-01-01T10:30:00Z'),
    },
  });

  const route = await prisma.route.create({
    data: {
      userId: user.id,
      activityType: 'walking',
      distance: 2500,
      duration: 1800,
      score: 82,
      routeData: { type: 'LineString', coordinates: [] },
    },
  });

  const readUser = await prisma.user.findUnique({
    where: { id: user.id },
    include: { activities: true, routes: true },
  });

  await prisma.user.update({
    where: { id: user.id },
    data: { name: 'PathCraft CRUD Test Updated' },
  });

  await prisma.user.delete({ where: { id: user.id } });

  console.log(JSON.stringify({
    success: true,
    userId: user.id.toString(),
    activityId: activity.id.toString(),
    routeId: route.id.toString(),
    readBack: readUser !== null,
    deleted: true,
  }));
} finally {
  await prisma.$disconnect();
}