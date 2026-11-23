import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const discoveryEndpoint = String.fromEnvironment('API_DISCOVERY_URL');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.resetForTesting();
  });

  test('reports an unavailable tunnel response instead of a JSON error',
      () async {
    final auth = AuthService();
    await auth.initialized;

    final result = await http.runWithClient(
      () => auth.login('user@example.com', 'password123'),
      () => MockClient((request) async {
        if (discoveryEndpoint.isNotEmpty &&
            request.url.toString() == discoveryEndpoint) {
          return http.Response(
            jsonEncode({
              'success': true,
              'url': 'https://test-tunnel.trycloudflare.com',
            }),
            200,
          );
        }
        expect(request.url.path, '/api/auth/login');
        return http.Response('<html>Cloudflare Tunnel error</html>', 530);
      }),
    );

    expect(result['success'], isFalse);
    expect(result['message'], contains('HTTP 530'));
    expect(auth.isAuthenticated, isFalse);
  });

  test('persists a successful login response', () async {
    final auth = AuthService();
    await auth.initialized;

    final result = await http.runWithClient(
      () => auth.login('user@example.com', 'password123'),
      () => MockClient((request) async {
        if (discoveryEndpoint.isNotEmpty &&
            request.url.toString() == discoveryEndpoint) {
          return http.Response(
            jsonEncode({
              'success': true,
              'url': 'https://test-tunnel.trycloudflare.com',
            }),
            200,
          );
        }
        expect(request.url.path, '/api/auth/login');
        expect(jsonDecode(request.body), {
          'email': 'user@example.com',
          'password': 'password123',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'saved-token',
            'userId': 'user-123',
            'name': 'Karipa User',
          }),
          200,
        );
      }),
    );

    expect(result['success'], isTrue);
    expect(auth.isAuthenticated, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('token'), 'saved-token');
  });
}
