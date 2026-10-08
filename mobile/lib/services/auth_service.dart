import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  String get baseUrl => '${ApiService.baseUrl}/auth';
  
  bool _isAuthenticated = false;
  bool _isGuest = false;
  String? _token;
  String? _userId;
  String? _name;

  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  String? get token => _token;
  String? get userId => _userId;
  String? get name => _name;

  AuthService() {
    _loadAuthStatus();
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
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _token = data['token'];
        _userId = data['userId'];
        _name = data['name'];
        _isAuthenticated = true;
        _isGuest = false;
        await _saveAuthStatus();
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': data['message'], 'needsVerification': data['needsVerification']};
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      return {'success': data['success'], 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _token = data['token'];
        _userId = data['userId'];
        _name = data['name'];
        _isAuthenticated = true;
        _isGuest = false;
        await _saveAuthStatus();
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? 'Verification failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(response.body);
      return {'success': data['success'], 'message': data['message'] ?? 'Failed to resend OTP'};
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
    _isAuthenticated = false;
    _isGuest = false;
    _token = null;
    _userId = null;
    _name = null;
    await _saveAuthStatus();
    notifyListeners();
  }
}
