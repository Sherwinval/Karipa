import 'package:flutter_test/flutter_test.dart';
import 'package:pathcraft_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guest activities are saved locally, listed, and deletable', () async {
    final startedAt = DateTime.utc(2026, 10, 12, 12);
    final completedAt = startedAt.add(const Duration(minutes: 20));

    final saveResult = await ApiService.saveActivity(
      activityType: 'walking',
      distanceMeters: 1250,
      durationSeconds: 1200,
      averagePaceSecondsPerKm: 960,
      calories: 80,
      startedAt: startedAt,
      completedAt: completedAt,
      gpsData: const [],
      routeData: const {},
    );

    expect(saveResult['success'], isTrue);
    expect(saveResult['localOnly'], isTrue);

    final activities = await ApiService.getActivities();
    expect(activities, hasLength(1));
    expect(activities.single.id, startsWith('local-'));
    expect(activities.single.activityType, 'walking');
    expect(activities.single.distanceKm, 1.25);
    expect(activities.single.averagePaceMinPerKm, 16);

    expect(await ApiService.deleteActivity(activities.single.id), isTrue);
    expect(await ApiService.getActivities(), isEmpty);
  });
}
