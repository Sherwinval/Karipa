import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isGuest = false;
  String? _token;
  String? _userId;
  String? _name;
  late final Future<void> initialized;

  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  String? get token => _token;
  String? get userId => _userId;
  String? get name => _name;

  AuthService() {
    initialized = _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _name = prefs.getString('name');
    _isGuest = prefs.getBool('isGuest') ?? false;

    if (_token != null) {
      _isAuthenticated = true;
    } else if (_isGuest && _name == null) {
      _name = 'Guest';
    }
    notifyListeners();
  }

  Future<void> _saveAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('token', _token!);
    } else {
      await prefs.remove('token');
    }
    if (_userId != null) {
      await prefs.setString('userId', _userId!);
    } else {
      await prefs.remove('userId');
    }
    if (_name != null) {
      await prefs.setString('name', _name!);
    } else {
      await prefs.remove('name');
    }
    await prefs.setBool('isGuest', _isGuest);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiConfig.send(
        '/auth/login',
        (uri) => http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        ),
        timeout: const Duration(seconds: 15),
      );

      final dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        return {
          'success': false,
          'message':
              'The login service returned an unexpected response (HTTP ${response.statusCode}). Check that the API URL and backend are available.',
        };
      }

      if (data is! Map) {
        return {
          'success': false,
          'message': 'The login service returned an invalid response.',
        };
      }

      if (response.statusCode == 200 && data['success'] == true) {
        ApiService.clearProfileCache();
        _token = data['token'];
        _userId = data['userId'];
        _name = data['name'];
        _isAuthenticated = true;
        _isGuest = false;
        await _saveAuthStatus();
        notifyListeners();
        return {'success': true};
      }
      return {
        'success': false,
        'message': data['message'],
        'needsVerification': data['needsVerification']
      };
    } on ApiDiscoveryException catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Login timed out. Check your internet connection and confirm the backend and Cloudflare Tunnel are running.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  /// Recovery never changes the current session or persists reset credentials.
  Future<Map<String, dynamic>> recoverPassword(
      String operation, Map<String, String> payload) async {
    if (!const {'request', 'resend', 'verify', 'reset'}.contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }
    try {
      final response = await ApiConfig.send(
        '/auth/password/$operation',
        (uri) => http.post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload)),
      );
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode == 200 && data['success'] == true) {
        final valid = switch (operation) {
          'request' || 'resend' => data['challengeId'] is String &&
              data['expiresIn'] is num &&
              data['resendAfter'] is num,
          'verify' =>
            data['authorization'] is String && data['expiresIn'] is num,
          _ => true,
        };
        if (!valid) throw const FormatException();
      }
      return {
        ...data,
        if (data['message'] is! String)
          'message':
              'Password recovery is temporarily unavailable. Please try again later.',
        'success': response.statusCode == 200 && data['success'] == true,
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'The request timed out. Check your connection and try again. If you requested a code, check your inbox before resending.'
      };
    } on FormatException {
      return {
        'success': false,
        'message':
            'Password recovery is temporarily unavailable. Please try again later.'
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Could not connect. Check your internet connection and try again.'
      };
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    double? heightCm,
    double? weightKg,
  }) async {
    try {
      final response = await ApiConfig.send(
        '/auth/register',
        (uri) => http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            if (heightCm != null) 'heightCm': heightCm,
            if (weightKg != null) 'weightKg': weightKg,
          }),
        ),
      );

      final data = jsonDecode(response.body);
      return {
        'success': data['success'],
        'message': data['message'] ?? 'Registration failed'
      };
    } on ApiDiscoveryException catch (error) {
      return {'success': false, 'message': error.message};
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await ApiConfig.send(
        '/auth/verify-otp',
        (uri) => http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'otp': otp}),
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        ApiService.clearProfileCache();
        _token = data['token'];
        _userId = data['userId'];
        _name = data['name'];
        _isAuthenticated = true;
        _isGuest = false;
        await _saveAuthStatus();
        notifyListeners();
        return {'success': true};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Verification failed'
      };
    } on ApiDiscoveryException catch (error) {
      return {'success': false, 'message': error.message};
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final response = await ApiConfig.send(
        '/auth/resend-otp',
        (uri) => http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        ),
      );
      final data = jsonDecode(response.body);
      return {
        'success': data['success'],
        'message': data['message'] ?? 'Failed to resend OTP'
      };
    } on ApiDiscoveryException catch (error) {
      return {'success': false, 'message': error.message};
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<void> continueAsGuest() async {
    _isGuest = true;
    _isAuthenticated = false;
    _token = null;
    _userId = null;
    _name = 'Guest';
    await _saveAuthStatus();
    notifyListeners();
  }

  Future<void> logout() async {
    ApiService.clearProfileCache();
    _isAuthenticated = false;
    _isGuest = false;
    _token = null;
    _userId = null;
    _name = null;
    await _saveAuthStatus();
    notifyListeners();
  }

  Future<void> updateProfileName(String name) async {
    final profile = await ApiService.updateProfileName(name);
    final savedName = profile['name'];
    if (savedName is! String || savedName.trim().isEmpty) {
      throw Exception('The server returned an invalid profile name');
    }
    _name = savedName;
    await _saveAuthStatus();
    notifyListeners();
  }

  Future<void> syncProfileNameFromServer(String name) async {
    if (_name == name) return;
    _name = name;
    await _saveAuthStatus();
    notifyListeners();
  }
}
