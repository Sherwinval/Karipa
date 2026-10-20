class CalorieMetMapping {
  final String code;
  final double met;

  const CalorieMetMapping({required this.code, required this.met});
}

class GrossCalorieEstimate {
  final double calories;
  final String metCode;
  final double metValue;
  final double weightKg;
  final double durationMinutes;
  final String methodVersion;

  const GrossCalorieEstimate({
    required this.calories,
    required this.metCode,
    required this.metValue,
    required this.weightKg,
    required this.durationMinutes,
    required this.methodVersion,
  });
}

class CalorieEstimateResult {
  final GrossCalorieEstimate? estimate;
  final String? unavailableReason;

  const CalorieEstimateResult.available(this.estimate)
      : unavailableReason = null;

  const CalorieEstimateResult.unavailable(this.unavailableReason)
      : estimate = null;
}

const proposedMetMappingVersion = 'karipa-proposed-met-v1';
const _kilometersPerMile = 1.609344;

CalorieMetMapping? applicableMetMapping({
  required String activityType,
  required double speedKmh,
  bool levelFirmGroundKnown = false,
  bool leisureCyclingKnown = false,
}) {
  if (!speedKmh.isFinite || speedKmh <= 0) return null;

  switch (activityType.toLowerCase()) {
    case 'walking':
      if (!levelFirmGroundKnown) return null;
      final speedMph = speedKmh / _kilometersPerMile;
      if (speedMph < 2.8 || speedMph > 3.4) return null;
      return const CalorieMetMapping(code: '17190', met: 3.8);
    case 'jogging':
      return const CalorieMetMapping(code: '12020', met: 7.5);
    case 'running':
      final speedMph = speedKmh / _kilometersPerMile;
      if (speedMph < 5.0 || speedMph > 5.2) return null;
      return const CalorieMetMapping(code: '12030', met: 8.5);
    case 'cycling':
      if (!leisureCyclingKnown || speedKmh / _kilometersPerMile >= 10.0) {
        return null;
      }
      return const CalorieMetMapping(code: '01010', met: 4.0);
    default:
      return null;
  }
}

double calculateGrossSessionCalories({
  required double met,
  required double weightKg,
  required double durationMinutes,
}) {
  if (!met.isFinite ||
      met <= 0 ||
      !weightKg.isFinite ||
      weightKg <= 0 ||
      !durationMinutes.isFinite ||
      durationMinutes <= 0) {
    throw ArgumentError(
        'MET, weight, and duration must be positive finite values.');
  }
  return met * weightKg * durationMinutes / 60;
}

CalorieEstimateResult estimateGrossSessionCalories({
  required String activityType,
  required double? weightKg,
  required double distanceMeters,
  required int durationSeconds,
  required int acceptedGpsFixCount,
}) {
  if (weightKg == null || !weightKg.isFinite || weightKg <= 0) {
    return const CalorieEstimateResult.unavailable(
      'A valid profile weight is required for calorie estimation.',
    );
  }
  if (!distanceMeters.isFinite ||
      distanceMeters < 50 ||
      durationSeconds < 5 ||
      acceptedGpsFixCount < 2) {
    return const CalorieEstimateResult.unavailable(
      'At least two accepted GPS fixes and measured movement are required.',
    );
  }

  final durationMinutes = durationSeconds / 60;
  final speedKmh = distanceMeters / 1000 / (durationSeconds / 3600);
  final mapping = applicableMetMapping(
    activityType: activityType,
    speedKmh: speedKmh,
  );
  if (mapping == null) {
    final reason = switch (activityType.toLowerCase()) {
      'walking' =>
        'The available route data does not confirm level, firm ground for the published walking category.',
      'running' =>
        'The measured GPS speed does not match the published 5.0–5.2 mph running category.',
      'cycling' =>
        'The available data does not confirm leisure-cycling context for the published MET category.',
      _ =>
        'No applicable published MET category is available for this activity.',
    };
    return CalorieEstimateResult.unavailable(reason);
  }

  final rawCalories = calculateGrossSessionCalories(
    met: mapping.met,
    weightKg: weightKg,
    durationMinutes: durationMinutes,
  );
  return CalorieEstimateResult.available(
    GrossCalorieEstimate(
      calories: double.parse(rawCalories.toStringAsFixed(2)),
      metCode: mapping.code,
      metValue: mapping.met,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
      methodVersion: proposedMetMappingVersion,
    ),
  );
}
