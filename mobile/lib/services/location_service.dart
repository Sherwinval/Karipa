import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  lowAccuracy,
  error,
}

class RecordedPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;

  RecordedPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'accuracy': accuracy,
  };
}

class LocationService {
  static Future<LocationStatus> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationStatus.permissionDeniedForever;
    }

    return LocationStatus.ready;
  }

  /// Obtains the current device location
  static Future<Position?> getCurrentPosition() async {
    final status = await checkAndRequestPermission();
    if (status != LocationStatus.ready) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      // Fallback to last known position if current times out
      return await Geolocator.getLastKnownPosition();
    }
  }

  /// Creates a filtered position stream for live activity tracking
  static Stream<RecordedPoint> getTrackingStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // Update every 3 meters
    );

    Position? previousPos;

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .where((pos) {
          // 1. Filter out points with poor accuracy (> 30 meters)
          if (pos.accuracy > 30.0) return false;

          // 2. Filter out unrealistic GPS teleport jumps
          if (previousPos != null) {
            final distance = Geolocator.distanceBetween(
              previousPos!.latitude,
              previousPos!.longitude,
              pos.latitude,
              pos.longitude,
            );
            final timeSeconds = (pos.timestamp.difference(previousPos!.timestamp).inMilliseconds) / 1000.0;
            if (timeSeconds > 0) {
              final speedMs = distance / timeSeconds;
              // If speed > 35 m/s (~126 km/h) for human fitness, ignore jump noise
              if (speedMs > 35.0) return false;
            }
          }

          previousPos = pos;
          return true;
        })
        .map((pos) => RecordedPoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          timestamp: pos.timestamp,
          accuracy: pos.accuracy,
        ));
  }
}
