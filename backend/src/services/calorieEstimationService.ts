import { z } from 'zod';

export const CALORIE_METHOD_VERSION = 'karipa-proposed-met-v1';

const MET_MAPPINGS: Record<string, { code: string; value: number }> = {
  jogging: { code: '12020', value: 7.5 },
  running: { code: '12030', value: 8.5 },
};

const calorieMetadataSchema = z.object({
  calorieMetCode: z.string().min(1).nullable().optional(),
  calorieMetValue: z.number().finite().positive().nullable().optional(),
  calorieWeightKg: z.number().finite().positive().nullable().optional(),
  calorieDurationMinutes: z.number().finite().positive().nullable().optional(),
  calorieMethodVersion: z.string().min(1).nullable().optional(),
  calories: z.number().finite().nonnegative().nullable().optional(),
});

export type CalorieMetadataInput = z.infer<typeof calorieMetadataSchema>;

export class CalorieEstimateValidationError extends Error {}

export function calculateGrossSessionCalories(
  metValue: number,
  weightKg: number,
  durationMinutes: number,
): number {
  if (
    !Number.isFinite(metValue) || metValue <= 0 ||
    !Number.isFinite(weightKg) || weightKg <= 0 ||
    !Number.isFinite(durationMinutes) || durationMinutes <= 0
  ) {
    throw new CalorieEstimateValidationError(
      'MET, weight, and counted duration must be positive finite values',
    );
  }
  return Number((metValue * weightKg * durationMinutes / 60).toFixed(2));
}

export function validateAndCalculateActivityCalories(
  activity: {
    activityType: string;
    distanceMeters: number;
    durationSeconds: number;
    averageSpeedKmh?: number | null;
    gpsData?: unknown;
  } & CalorieMetadataInput,
): {
  calories: number | null;
  calorieMetCode: string | null;
  calorieMetValue: number | null;
  calorieWeightKg: number | null;
  calorieDurationMinutes: number | null;
  calorieMethodVersion: string | null;
} {
  const parsed = calorieMetadataSchema.safeParse(activity);
  if (!parsed.success) {
    throw new CalorieEstimateValidationError('Invalid calorie estimate metadata');
  }

  const metadata = parsed.data;
  const metadataValues = [
    metadata.calorieMetCode,
    metadata.calorieMetValue,
    metadata.calorieWeightKg,
    metadata.calorieDurationMinutes,
    metadata.calorieMethodVersion,
  ];
  const hasMetadata = metadataValues.some((value) => value !== undefined && value !== null);
  const hasCompleteMetadata = metadataValues.every((value) => value !== undefined && value !== null);
  if (!hasMetadata && (metadata.calories === undefined || metadata.calories === null)) {
    return {
      calories: null,
      calorieMetCode: null,
      calorieMetValue: null,
      calorieWeightKg: null,
      calorieDurationMinutes: null,
      calorieMethodVersion: null,
    };
  }
  if (!hasCompleteMetadata || metadata.calories === undefined || metadata.calories === null) {
    throw new CalorieEstimateValidationError(
      'A calorie estimate requires its complete calculation basis',
    );
  }

  const mapping = MET_MAPPINGS[activity.activityType];
  if (
    !mapping ||
    metadata.calorieMetCode !== mapping.code ||
    metadata.calorieMetValue !== mapping.value ||
    metadata.calorieMethodVersion !== CALORIE_METHOD_VERSION
  ) {
    throw new CalorieEstimateValidationError(
      'The submitted MET mapping is not supported for this activity',
    );
  }

  const expectedDurationMinutes = activity.durationSeconds / 60;
  if (
    activity.distanceMeters <= 0 ||
    activity.durationSeconds <= 0 ||
    !Number.isFinite(activity.averageSpeedKmh) ||
    activity.averageSpeedKmh! <= 0 ||
    !Array.isArray(activity.gpsData) ||
    activity.gpsData.length < 2 ||
    Math.abs(metadata.calorieDurationMinutes! - expectedDurationMinutes) > 0.000001
  ) {
    throw new CalorieEstimateValidationError(
      'A calorie estimate requires measured GPS movement and the counted activity duration',
    );
  }

  const speedFromActivity = activity.distanceMeters / 1000 / (activity.durationSeconds / 3600);
  if (Math.abs(activity.averageSpeedKmh! - speedFromActivity) > 0.01) {
    throw new CalorieEstimateValidationError(
      'Calorie estimate speed does not match the recorded activity metrics',
    );
  }
  if (activity.activityType === 'running') {
    const speedMph = speedFromActivity / 1.609344;
    if (speedMph < 5 || speedMph > 5.2) {
      throw new CalorieEstimateValidationError(
        'The measured speed does not match the published running MET category',
      );
    }
  }

  const calculatedCalories = calculateGrossSessionCalories(
    metadata.calorieMetValue!,
    metadata.calorieWeightKg!,
    metadata.calorieDurationMinutes!,
  );
  if (Math.abs(metadata.calories - calculatedCalories) > 0.01) {
    throw new CalorieEstimateValidationError(
      'Submitted calories do not match the documented gross-session calculation',
    );
  }

  return {
    calories: calculatedCalories,
    calorieMetCode: metadata.calorieMetCode!,
    calorieMetValue: metadata.calorieMetValue!,
    calorieWeightKg: metadata.calorieWeightKg!,
    calorieDurationMinutes: metadata.calorieDurationMinutes!,
    calorieMethodVersion: metadata.calorieMethodVersion!,
  };
}
