import type { Prisma } from '@prisma/client';
import { prisma } from '../lib/prisma.js';
import {
  decryptLocationData,
  encryptLocationData,
  hasLocationData,
  isEncryptedLocationData,
} from '../lib/locationEncryption.js';

const BATCH_SIZE = 100;

async function encryptActivityLocationData(): Promise<number> {
  let cursor: bigint | undefined;
  let updatedCount = 0;

  while (true) {
    const activities = await prisma.activity.findMany({
      ...(cursor === undefined ? {} : { where: { id: { gt: cursor } } }),
      orderBy: { id: 'asc' },
      take: BATCH_SIZE,
      select: { id: true, gpsData: true, routeData: true },
    });
    if (activities.length === 0) break;

    const updates = activities.flatMap((activity) => {
      const data: Prisma.ActivityUpdateInput = {};
      if (isEncryptedLocationData(activity.gpsData)) {
        decryptLocationData(activity.gpsData);
      } else if (hasLocationData(activity.gpsData)) {
        data.gpsData = encryptLocationData(activity.gpsData);
      }
      if (isEncryptedLocationData(activity.routeData)) {
        decryptLocationData(activity.routeData);
      } else if (hasLocationData(activity.routeData)) {
        data.routeData = encryptLocationData(activity.routeData);
      }
      if (Object.keys(data).length === 0) return [];
      return [prisma.activity.update({ where: { id: activity.id }, data })];
    });

    if (updates.length > 0) {
      await prisma.$transaction(updates);
      updatedCount += updates.length;
    }
    cursor = activities[activities.length - 1].id;
  }

  return updatedCount;
}

async function encryptSavedRouteData(): Promise<number> {
  let cursor: bigint | undefined;
  let updatedCount = 0;

  while (true) {
    const routes = await prisma.route.findMany({
      ...(cursor === undefined ? {} : { where: { id: { gt: cursor } } }),
      orderBy: { id: 'asc' },
      take: BATCH_SIZE,
      select: { id: true, routeData: true },
    });
    if (routes.length === 0) break;

    for (const route of routes) {
      if (isEncryptedLocationData(route.routeData)) {
        decryptLocationData(route.routeData);
      }
    }

    const updates = routes
      .filter((route) =>
        !isEncryptedLocationData(route.routeData) &&
        hasLocationData(route.routeData))
      .map((route) =>
        prisma.route.update({
          where: { id: route.id },
          data: { routeData: encryptLocationData(route.routeData) },
        }),
      );
    if (updates.length > 0) {
      await prisma.$transaction(updates);
      updatedCount += updates.length;
    }
    cursor = routes[routes.length - 1].id;
  }

  return updatedCount;
}

try {
  encryptLocationData({});
  const activityCount = await encryptActivityLocationData();
  const routeCount = await encryptSavedRouteData();
  console.log(
    `Encrypted location data in ${activityCount} activities and ${routeCount} saved routes.`,
  );
} catch (error) {
  console.error('Location-data encryption failed:', error);
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
