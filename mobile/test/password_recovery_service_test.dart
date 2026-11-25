import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/config/api_config.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthService auth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.resetForTesting();
    auth = AuthService();
    await auth.initialized;
  });
  test('uses the recovery endpoint and never persists reset authorization',
      () async {
    final result = await http.runWithClient(
      () => auth.recoverPassword(
          'verify', {'challengeId': 'challenge', 'otp': '123456'}),
      () => MockClient((request) async {
        expect(request.url.path, '/api/auth/password/verify');
        expect(jsonDecode(request.body),
            {'challengeId': 'challenge', 'otp': '123456'});
        return http.Response(
            jsonEncode({
              'success': true,
              'authorization': 'test-authorization',
              'expiresIn': 300
            }),
            200);
      }),
    );
    expect(result['success'], true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(auth.isAuthenticated, false);
  });
  test('retains server rate-limit guidance and retry interval', () async {
    final result = await http.runWithClient(
      () => auth.recoverPassword('request', {'email': 'alex@example.com'}),
      () => MockClient((_) async => http.Response(
          jsonEncode(
              {'success': false, 'message': 'Please wait.', 'retryAfter': 60}),
          429)),
    );
    expect(result['success'], false);
    expect(result['retryAfter'], 60);
  });
  test('handles non-JSON and incomplete successful responses', () async {
    for (final body in ['<html>unavailable</html>', '{"success":true}']) {
      final result = await http.runWithClient(
        () => auth.recoverPassword('request', {'email': 'alex@example.com'}),
        () => MockClient((_) async => http.Response(body, 200)),
      );
      expect(result['success'], false);
      expect(result['message'], contains('temporarily unavailable'));
    }
  });
  test('provides actionable timeout and network feedback', () async {
    for (final error in [
      TimeoutException('test'),
      http.ClientException('test')
    ]) {
      final result = await http.runWithClient(
        () => auth.recoverPassword('request', {'email': 'alex@example.com'}),
        () => MockClient((_) async => throw error),
      );
      expect(result['success'], false);
      expect(result['message'], contains('connection'));
    }
  });
}
