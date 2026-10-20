import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_model.dart';
import '../models/activity_model.dart';

class ApiService {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _localActivitiesKey = 'guestActivities';

  static String get baseUrl {
    final configuredBaseUrl = _configuredBaseUrl.trim();
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static String _responseMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    } on FormatException {
      // Use the status code when the server did not return JSON.
    }
    return '$fallback (HTTP ${response.statusCode})';
  }

  static Future<List<ActivityModel>> _getLocalActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList(_localActivitiesKey) ?? [];
    return activities
        .map((activity) => ActivityModel.fromJson(
            jsonDecode(activity) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// Generate routes from the routing service and return distance-first rankings.
  static Future<List<PathRoute>> generateRoutes({
    required String activity,
    required double targetDistanceKm,
    required Map<String, dynamic> preferences,
    required double latitude,
    required double longitude,
  }) async {
    final headers = await _headers();
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/routes/generate'),
            headers: headers,
            body: jsonEncode({
              'activity': activity.toLowerCase(),
              'targetDistanceKm': targetDistanceKm,
              'preferences': preferences,
              'startLocation': {
                'latitude': latitude,
                'longitude': longitude,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on http.ClientException {
      throw Exception(
          'Unable to connect to the route service. Check your internet connection and retry.');
    } on SocketException {
      throw Exception(
          'Unable to connect to the route service. Check your internet connection and retry.');
    } on TimeoutException {
      throw Exception(
          'The route service took too long to respond. Please retry.');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['routes'] is List) {
          final meta = data['meta'] is Map
              ? Map<String, dynamic>.from(data['meta'] as Map)
              : <String, dynamic>{};
          return (data['routes'] as List)
              .map((r) => PathRoute.fromJson({
                    ...Map<String, dynamic>.from(r as Map),
                    'maximumDistanceDeviationKm':
                        meta['maximumDistanceDeviationKm'],
                    'closeCandidateAvailable': meta['closeCandidateAvailable'],
                  }))
              .toList();
        }
      } on FormatException {
        throw Exception(
            'The route service returned an unreadable response. Please retry.');
      }
      throw Exception(
          'The route service returned an invalid response. Please retry.');
    }

    throw Exception(_responseMessage(response, 'Failed to generate routes'));
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return {'heightCm': null, 'weightKg': null};
    }

    final response = await http
        .get(
          Uri.parse('$baseUrl/auth/profile'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
          _responseMessage(response, 'Failed to load profile measurements'));
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['success'] != true || data['profile'] is! Map) {
      throw Exception('The server returned an invalid profile response');
    }
    return Map<String, dynamic>.from(data['profile'] as Map);
  }

  static Future<Map<String, dynamic>> updateProfile({
    required double? heightCm,
    required double? weightKg,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sign in to save profile measurements.');
    }

    final response = await http
        .patch(
          Uri.parse('$baseUrl/auth/profile'),
          headers: await _headers(),
          body: jsonEncode({'heightCm': heightCm, 'weightKg': weightKg}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
          _responseMessage(response, 'Failed to save profile measurements'));
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['success'] != true || data['profile'] is! Map) {
      throw Exception('The server returned an invalid profile response');
    }
    return Map<String, dynamic>.from(data['profile'] as Map);
  }

  /// Save route to backend
  static Future<bool> saveRoute(PathRoute route) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return false;

    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$baseUrl/routes'),
          headers: headers,
          body: jsonEncode({
            'activityType': route.activityType,
            'distanceKm': route.distanceKm,
            'durationSeconds': route.durationSeconds,
            'score': route.score,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return response.statusCode == 201;
  }

  /// Get user's saved activities
  static Future<List<ActivityModel>> getActivities() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return _getLocalActivities();

    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/activities'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
          _responseMessage(response, 'Failed to load activity history'));
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['success'] == true && data['activities'] is List) {
      return (data['activities'] as List)
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    throw Exception('The server returned an invalid activity history response');
  }

  static Future<Map<String, dynamic>> getWeeklyLeaderboard() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sign in to view the weekly leaderboard.');
    }

    final response = await http
        .get(
          Uri.parse('$baseUrl/activities/leaderboard/weekly'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(_responseMessage(response, 'Failed to load leaderboard'));
    }

    final data = jsonDecode(response.body);
    if (data is! Map || data['success'] != true || data['entries'] is! List) {
      throw Exception('The server returned an invalid leaderboard response');
    }
    return Map<String, dynamic>.from(data);
  }

  /// Get single activity by ID
  static Future<ActivityModel?> getActivity(String id) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return null;

    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/activities/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['activity'] != null) {
        return ActivityModel.fromJson(data['activity'] as Map<String, dynamic>);
      }
    }
    return null;
  }

  /// Delete activity by ID
  static Future<bool> deleteActivity(String id) async {
    if (id.startsWith('local-')) {
      final prefs = await SharedPreferences.getInstance();
      final activities = prefs.getStringList(_localActivitiesKey) ?? [];
      activities.removeWhere((activity) {
        final data = jsonDecode(activity) as Map<String, dynamic>;
        return data['id'] == id;
      });
      await prefs.setStringList(_localActivitiesKey, activities);
      return true;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) return false;

    final headers = await _headers();
    final response = await http.delete(
      Uri.parse('$baseUrl/activities/$id'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  /// Record completed activity
  static Future<Map<String, dynamic>> saveActivity({
    required String activityType,
    String recordingMode = 'plan_route',
    required double distanceMeters,
    required int durationSeconds,
    int? totalElapsedSeconds,
    double? targetDistanceMeters,
    Map<String, dynamic>? routeData,
    double? averagePaceSecondsPerKm,
    double? averageSpeedKmh,
    double? calories,
    String? calorieMetCode,
    double? calorieMetValue,
    double? calorieWeightKg,
    double? calorieDurationMinutes,
    String? calorieMethodVersion,
    required String idempotencyKey,
    required DateTime startedAt,
    required DateTime completedAt,
    List<Map<String, dynamic>>? gpsData,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final activities = prefs.getStringList(_localActivitiesKey) ?? [];
      final localId = 'local-$idempotencyKey';
      if (activities.any((activity) =>
          (jsonDecode(activity) as Map<String, dynamic>)['id'] == localId)) {
        return {'success': true, 'localOnly': true};
      }
      final localActivity = <String, dynamic>{
        'id': localId,
        'userId': '',
        'activityType': activityType.toLowerCase(),
        'recordingMode': recordingMode,
        'distanceKm': distanceMeters / 1000,
        'durationSeconds': durationSeconds,
        'activeDurationSeconds': durationSeconds,
        'totalElapsedSeconds': totalElapsedSeconds ?? durationSeconds,
        'targetDistanceKm':
            targetDistanceMeters == null ? null : targetDistanceMeters / 1000,
        'routeData': routeData,
        'averagePaceMinPerKm': averagePaceSecondsPerKm == null
            ? null
            : averagePaceSecondsPerKm / 60,
        'averageSpeedKmh': averageSpeedKmh,
        'calories': calories,
        'calorieMetCode': calorieMetCode,
        'calorieMetValue': calorieMetValue,
        'calorieWeightKg': calorieWeightKg,
        'calorieDurationMinutes': calorieDurationMinutes,
        'calorieMethodVersion': calorieMethodVersion,
        'idempotencyKey': idempotencyKey,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': completedAt.toUtc().toIso8601String(),
        'gpsData': gpsData ?? [],
      };
      activities.add(jsonEncode(localActivity));
      await prefs.setStringList(_localActivitiesKey, activities);
      return {'success': true, 'localOnly': true};
    }

    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$baseUrl/activities'),
          headers: headers,
          body: jsonEncode({
            'activityType': activityType.toLowerCase(),
            'recordingMode': recordingMode,
            'distanceMeters': distanceMeters,
            'durationSeconds': durationSeconds,
            'activeDurationSeconds': durationSeconds,
            'totalElapsedSeconds': totalElapsedSeconds ?? durationSeconds,
            'targetDistanceMeters': targetDistanceMeters,
            'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
            'averageSpeedKmh': averageSpeedKmh,
            'calories': calories,
            'calorieMetCode': calorieMetCode,
            'calorieMetValue': calorieMetValue,
            'calorieWeightKg': calorieWeightKg,
            'calorieDurationMinutes': calorieDurationMinutes,
            'calorieMethodVersion': calorieMethodVersion,
            'idempotencyKey': idempotencyKey,
            'startedAt': startedAt.toUtc().toIso8601String(),
            'completedAt': completedAt.toUtc().toIso8601String(),
            'gpsData': gpsData,
            'routeData': routeData,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 201 || response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['activity'] is Map) {
          return {
            'success': true,
            'activity': data['activity'],
            'alreadySaved': data['alreadySaved'] == true
          };
        }
      } on FormatException {
        return {
          'success': false,
          'message': 'The server returned an invalid save confirmation.',
        };
      }
      return {
        'success': false,
        'message': 'The server did not confirm that the activity was saved.',
      };
    }
    return {
      'success': false,
      'message': _responseMessage(response, 'Failed to save activity'),
    };
  }
}
