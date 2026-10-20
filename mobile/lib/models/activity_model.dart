import 'package:latlong2/latlong.dart';

class ActivityModel {
  final String id;
  final String userId;
  final String activityType;
  final String recordingMode;
  final double distanceKm;
  final int durationSeconds;
  final int totalElapsedSeconds;
  final double? targetDistanceKm;
  final double? averagePaceMinPerKm;
  final double? averageSpeedKmh;
  final double? calories;
  final String? calorieMetCode;
  final double? calorieMetValue;
  final double? calorieWeightKg;
  final double? calorieDurationMinutes;
  final String? calorieMethodVersion;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<LatLng> gpsPoints;
  final Map<String, dynamic>? routeData;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.activityType,
    this.recordingMode = 'plan_route',
    required this.distanceKm,
    required this.durationSeconds,
    int? totalElapsedSeconds,
    this.targetDistanceKm,
    this.averagePaceMinPerKm,
    this.averageSpeedKmh,
    this.calories,
    this.calorieMetCode,
    this.calorieMetValue,
    this.calorieWeightKg,
    this.calorieDurationMinutes,
    this.calorieMethodVersion,
    required this.startedAt,
    required this.completedAt,
    required this.gpsPoints,
    this.routeData,
  }) : totalElapsedSeconds = totalElapsedSeconds ?? durationSeconds;

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    List<LatLng> points = [];
    if (json['gpsData'] != null && json['gpsData'] is List) {
      for (var p in (json['gpsData'] as List)) {
        if (p is Map && p['latitude'] != null && p['longitude'] != null) {
          points.add(LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          ));
        }
      }
    }

    return ActivityModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      activityType: json['activityType'] ?? 'running',
      recordingMode: json['recordingMode']?.toString() ?? 'plan_route',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      totalElapsedSeconds: (json['totalElapsedSeconds'] as num?)?.toInt(),
      targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble(),
      averagePaceMinPerKm: (json['averagePaceMinPerKm'] as num?)?.toDouble(),
      averageSpeedKmh: (json['averageSpeedKmh'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toDouble(),
      calorieMetCode: json['calorieMetCode'] as String?,
      calorieMetValue: (json['calorieMetValue'] as num?)?.toDouble(),
      calorieWeightKg: (json['calorieWeightKg'] as num?)?.toDouble(),
      calorieDurationMinutes:
          (json['calorieDurationMinutes'] as num?)?.toDouble(),
      calorieMethodVersion: json['calorieMethodVersion'] as String?,
      startedAt: DateTime.tryParse(json['startedAt'] ?? '') ?? DateTime.now(),
      completedAt:
          DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
      gpsPoints: points,
      routeData: json['routeData'] is Map
          ? (json['routeData'] as Map<String, dynamic>)
          : null,
    );
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    final h = m ~/ 60;
    final remM = m % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (averagePaceMinPerKm == null || averagePaceMinPerKm == 0) return '--:--';
    final totalSec = (averagePaceMinPerKm! * 60).round();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} /km';
  }
}
