import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/services/calorie_estimation_service.dart';

void main() {
  test('reproduces the documented gross-session arithmetic example', () {
    expect(
      calculateGrossSessionCalories(
        met: 3.8,
        weightKg: 60,
        durationMinutes: 30,
      ),
      114,
    );
  });

  test('estimates jogging with its published general self-selected category',
      () {
    final result = estimateGrossSessionCalories(
      activityType: 'jogging',
      weightKg: 60,
      distanceMeters: 3000,
      durationSeconds: 1800,
      acceptedGpsFixCount: 2,
    );

    expect(result.estimate?.metCode, '12020');
    expect(result.estimate?.metValue, 7.5);
    expect(result.estimate?.calories, 225);
    expect(result.estimate?.methodVersion, proposedMetMappingVersion);
  });

  test('uses the running category only within its documented speed range', () {
    final result = estimateGrossSessionCalories(
      activityType: 'running',
      weightKg: 60,
      distanceMeters: 8200,
      durationSeconds: 3600,
      acceptedGpsFixCount: 2,
    );
    final tooFast = estimateGrossSessionCalories(
      activityType: 'running',
      weightKg: 60,
      distanceMeters: 10000,
      durationSeconds: 3600,
      acceptedGpsFixCount: 2,
    );

    expect(result.estimate?.metCode, '12030');
    expect(result.estimate?.metValue, 8.5);
    expect(result.estimate?.calories, 510);
    expect(tooFast.estimate, isNull);
  });

  test('requires the documented route context for walking and cycling', () {
    expect(
      estimateGrossSessionCalories(
        activityType: 'walking',
        weightKg: 60,
        distanceMeters: 1500,
        durationSeconds: 1800,
        acceptedGpsFixCount: 2,
      ).estimate,
      isNull,
    );
    expect(
      estimateGrossSessionCalories(
        activityType: 'cycling',
        weightKg: 60,
        distanceMeters: 5000,
        durationSeconds: 1800,
        acceptedGpsFixCount: 2,
      ).estimate,
      isNull,
    );

    expect(
      applicableMetMapping(
        activityType: 'walking',
        speedKmh: 3 * 1.609344,
        levelFirmGroundKnown: true,
      )?.code,
      '17190',
    );
    expect(
      applicableMetMapping(
        activityType: 'cycling',
        speedKmh: 9 * 1.609344,
        leisureCyclingKnown: true,
      )?.code,
      '01010',
    );
  });

  test('missing weight leaves calorie estimation unavailable', () {
    final result = estimateGrossSessionCalories(
      activityType: 'jogging',
      weightKg: null,
      distanceMeters: 1000,
      durationSeconds: 600,
      acceptedGpsFixCount: 2,
    );

    expect(result.estimate, isNull);
    expect(result.unavailableReason, contains('profile weight'));
  });
}
