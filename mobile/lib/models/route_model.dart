import 'package:latlong2/latlong.dart';

class PathRoute {
  final String id;
  final String name;
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double score;
  final double targetDistanceKm;
  final double absoluteDistanceDeviationKm;
  final double percentageDistanceDeviation;
  final double? maximumDistanceDeviationKm;
  final bool? closeCandidateAvailable;
  final String rankingSource;
  final int rank;
  final bool isTopRecommendation;
  final String suitability;
  final String matchLabel;
  final String reasoning;
  final List<LatLng> coordinates;
  final Map<String, dynamic> features;
  final Map<String, dynamic> rawJson;

  PathRoute({
    required this.id,
    required this.name,
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.score,
    required this.targetDistanceKm,
    required this.absoluteDistanceDeviationKm,
    required this.percentageDistanceDeviation,
    this.maximumDistanceDeviationKm,
    this.closeCandidateAvailable,
    required this.rankingSource,
    required this.rank,
    required this.isTopRecommendation,
    required this.suitability,
    required this.matchLabel,
    required this.reasoning,
    required this.coordinates,
    required this.features,
    required this.rawJson,
  });

  factory PathRoute.fromJson(Map<String, dynamic> json) {
    List<LatLng> coords = [];
    if (json['geometry'] != null && json['geometry']['coordinates'] != null) {
      final rawCoords = json['geometry']['coordinates'] as List;
      for (var item in rawCoords) {
        if (item is List && item.length >= 2) {
          // GeoJSON is [lon, lat] -> convert to LatLng(lat, lon)
          final lon = (item[0] as num).toDouble();
          final lat = (item[1] as num).toDouble();
          coords.add(LatLng(lat, lon));
        }
      }
    }

    return PathRoute(
      id: json['id']?.toString() ??
          'route-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] ?? 'Valhalla Route',
      activityType: json['activityType'] ?? json['activity'] ?? 'running',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble() ?? 0.0,
      absoluteDistanceDeviationKm:
          (json['absoluteDistanceDeviationKm'] as num?)?.toDouble() ??
              (((json['distanceKm'] as num?)?.toDouble() ?? 0) -
                      ((json['targetDistanceKm'] as num?)?.toDouble() ?? 0))
                  .abs(),
      percentageDistanceDeviation:
          (json['percentageDistanceDeviation'] as num?)?.toDouble() ?? 0.0,
      maximumDistanceDeviationKm:
          (json['maximumDistanceDeviationKm'] as num?)?.toDouble(),
      closeCandidateAvailable: json['closeCandidateAvailable'] as bool?,
      rankingSource:
          json['rankingSource']?.toString() ?? 'deterministic_fallback',
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      isTopRecommendation: json['isTopRecommendation'] ?? false,
      suitability: json['suitability'] ?? 'Good match',
      matchLabel: json['matchLabel'] ?? 'Recommended',
      reasoning: json['reasoning'] ?? 'Optimal for activity',
      coordinates: coords,
      features: (json['features'] as Map<String, dynamic>?) ?? {},
      rawJson: json,
    );
  }

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }
}
