import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/models/activity_model.dart';

void main() {
  test('parses recording mode and separate active and elapsed durations', () {
    final activity = ActivityModel.fromJson({
      'id': '42',
      'userId': '7',
      'activityType': 'cycling',
      'recordingMode': 'free_recording',
      'distanceKm': 3.25,
      'durationSeconds': 1200,
      'activeDurationSeconds': 1200,
      'totalElapsedSeconds': 1500,
      'startedAt': '2026-10-20T07:00:00.000Z',
      'completedAt': '2026-10-20T07:25:00.000Z',
      'gpsData': [],
      'routeData': null,
      'targetDistanceKm': null,
    });

    expect(activity.recordingMode, 'free_recording');
    expect(activity.durationSeconds, 1200);
    expect(activity.totalElapsedSeconds, 1500);
    expect(activity.targetDistanceKm, isNull);
    expect(activity.routeData, isNull);
  });

  test('older records retain plan mode and use saved duration as elapsed time',
      () {
    final activity = ActivityModel.fromJson({
      'id': '41',
      'userId': '7',
      'activityType': 'running',
      'distanceKm': 2,
      'durationSeconds': 600,
      'startedAt': '2026-10-19T07:00:00.000Z',
      'completedAt': '2026-10-19T07:10:00.000Z',
      'gpsData': [],
    });

    expect(activity.recordingMode, 'plan_route');
    expect(activity.totalElapsedSeconds, 600);
  });
}
