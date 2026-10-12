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

  /// Generate real candidate routes with OSRM and AI ranking
  static Future<List<PathRoute>> generateRoutes({
    required String activity,
    required double targetDistanceKm,
    required Map<String, dynamic> preferences,
    required double latitude,
    required double longitude,
  }) async {
    final headers = await _headers();
    final response = await http.post(
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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['routes'] is List) {
        return (data['routes'] as List)
            .map((r) => PathRoute.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    }

    final errData = jsonDecode(response.body);
    throw Exception(errData['message'] ?? 'Failed to generate routes. Check network connection.');
  }

  /// Save route to backend
  static Future<bool> saveRoute(PathRoute route) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return false;

    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/routes'),
      headers: headers,
      body: jsonEncode({
        'activityType': route.activityType,
        'distanceKm': route.distanceKm,
        'durationSeconds': route.durationSeconds,
        'score': route.score,
        'routeData': route.rawJson,
      }),
    );
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
    required double distanceMeters,
    required int durationSeconds,
    double? averagePaceSecondsPerKm,
    double? averageSpeedKmh,
    double? calories,
    required DateTime startedAt,
    required DateTime completedAt,
    List<Map<String, dynamic>>? gpsData,
    Map<String, dynamic>? routeData,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final activities = prefs.getStringList(_localActivitiesKey) ?? [];
      final localActivity = <String, dynamic>{
        'id': 'local-${completedAt.microsecondsSinceEpoch}',
        'userId': '',
        'activityType': activityType.toLowerCase(),
        'distanceKm': distanceMeters / 1000,
        'durationSeconds': durationSeconds,
        'averagePaceMinPerKm': averagePaceSecondsPerKm == null
            ? null
            : averagePaceSecondsPerKm / 60,
        'averageSpeedKmh': averageSpeedKmh,
        'calories': calories,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': completedAt.toUtc().toIso8601String(),
        'gpsData': gpsData ?? [],
        'routeData': routeData,
      };
      activities.add(jsonEncode(localActivity));
      await prefs.setStringList(_localActivitiesKey, activities);
      return {'success': true, 'localOnly': true};
    }

    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/activities'),
      headers: headers,
      body: jsonEncode({
        'activityType': activityType.toLowerCase(),
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
        'averageSpeedKmh': averageSpeedKmh,
        'calories': calories,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': completedAt.toUtc().toIso8601String(),
        'gpsData': gpsData,
        'routeData': routeData,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'activity': data['activity']};
    }
    return {
      'success': false,
      'message': _responseMessage(response, 'Failed to save activity'),
    };
  }
}
