import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/services/location_service.dart';

void main() {
  test('counts a valid GPS segment using its observed coordinates', () {
    final previous = RecordedPoint(
      latitude: 14.5995,
      longitude: 120.9842,
      timestamp: DateTime.utc(2026, 10, 20, 7),
      accuracy: 5,
    );
    final current = RecordedPoint(
      latitude: 14.6005,
      longitude: 120.9842,
      timestamp: DateTime.utc(2026, 10, 20, 7, 0, 10),
      accuracy: 5,
    );

    expect(
        GpsSegmentDistance.acceptedMeters(previous, current), greaterThan(100));
  });

  test('rejects stale gaps and movement below the existing distance filter',
      () {
    final previous = RecordedPoint(
      latitude: 14.5995,
      longitude: 120.9842,
      timestamp: DateTime.utc(2026, 10, 20, 7),
      accuracy: 5,
    );
    final stale = RecordedPoint(
      latitude: 14.6015,
      longitude: 120.9842,
      timestamp: DateTime.utc(2026, 10, 20, 7, 0, 31),
      accuracy: 5,
    );
    final tinyMove = RecordedPoint(
      latitude: 14.5995001,
      longitude: 120.9842,
      timestamp: DateTime.utc(2026, 10, 20, 7, 0, 1),
      accuracy: 5,
    );

    expect(GpsSegmentDistance.acceptedMeters(previous, stale), 0);
    expect(GpsSegmentDistance.acceptedMeters(previous, tinyMove), 0);
  });
}
