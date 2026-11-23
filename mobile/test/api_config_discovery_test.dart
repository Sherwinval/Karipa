import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const discoveryEndpoint = String.fromEnvironment('API_DISCOVERY_URL');
String get cachedBaseUrlKey =>
    'discoveredApiBaseUrl:${Uri.encodeComponent(discoveryEndpoint)}';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.resetForTesting();
  });

  test('discovers and caches the current tunnel before API requests',
      skip: discoveryEndpoint.isEmpty
          ? 'Run with --dart-define=API_DISCOVERY_URL to test discovery'
          : false, () async {
    final apiHosts = <String>[];
    var discoveryRequests = 0;

    await http.runWithClient(
      () async {
        final response = await ApiConfig.send(
          '/auth/login',
          (uri) async {
            apiHosts.add(uri.host);
            return http.Response('{"success":true}', 200);
          },
        );
        expect(response.statusCode, 200);
        final cachedResponse = await ApiConfig.send(
          '/auth/profile',
          (uri) async {
            apiHosts.add(uri.host);
            return http.Response('{"success":true}', 200);
          },
        );
        expect(cachedResponse.statusCode, 200);
      },
      () => MockClient((request) async {
        discoveryRequests++;
        expect(request.url.toString(), discoveryEndpoint);
        return http.Response(
          jsonEncode({
            'success': true,
            'url': 'https://first-tunnel.trycloudflare.com',
          }),
          200,
        );
      }),
    );

    expect(discoveryRequests, 1);
    expect(apiHosts, [
      'first-tunnel.trycloudflare.com',
      'first-tunnel.trycloudflare.com',
    ]);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(cachedBaseUrlKey),
      'https://first-tunnel.trycloudflare.com/api',
    );
  });

  test('refreshes a stale cached tunnel and retries the same API request',
      skip: discoveryEndpoint.isEmpty
          ? 'Run with --dart-define=API_DISCOVERY_URL to test discovery'
          : false, () async {
    SharedPreferences.setMockInitialValues({
      cachedBaseUrlKey: 'https://old-tunnel.trycloudflare.com/api',
    });
    ApiConfig.resetForTesting();
    final apiHosts = <String>[];
    var discoveryRequests = 0;

    await http.runWithClient(
      () async {
        final response = await ApiConfig.send(
          '/activities',
          (uri) async {
            apiHosts.add(uri.host);
            return uri.host == 'old-tunnel.trycloudflare.com'
                ? http.Response('Tunnel unavailable', 530)
                : http.Response('{"success":true}', 200);
          },
        );
        expect(response.statusCode, 200);
      },
      () => MockClient((request) async {
        discoveryRequests++;
        expect(request.url.toString(), discoveryEndpoint);
        return http.Response(
          jsonEncode({
            'success': true,
            'url': 'https://new-tunnel.trycloudflare.com',
          }),
          200,
        );
      }),
    );

    expect(discoveryRequests, 1);
    expect(apiHosts, [
      'old-tunnel.trycloudflare.com',
      'new-tunnel.trycloudflare.com',
    ]);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(cachedBaseUrlKey),
      'https://new-tunnel.trycloudflare.com/api',
    );
  });

  test('re-discovers after a cached tunnel connection fails',
      skip: discoveryEndpoint.isEmpty
          ? 'Run with --dart-define=API_DISCOVERY_URL to test discovery'
          : false, () async {
    SharedPreferences.setMockInitialValues({
      cachedBaseUrlKey: 'https://old-tunnel.trycloudflare.com/api',
    });
    ApiConfig.resetForTesting();
    final apiHosts = <String>[];

    await http.runWithClient(
      () async {
        final response = await ApiConfig.send(
          '/auth/register',
          (uri) async {
            apiHosts.add(uri.host);
            if (uri.host == 'old-tunnel.trycloudflare.com') {
              throw http.ClientException('Tunnel is gone', uri);
            }
            return http.Response('{"success":true}', 200);
          },
        );
        expect(response.statusCode, 200);
      },
      () => MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'url': 'https://restarted-tunnel.trycloudflare.com',
            }),
            200,
          )),
    );

    expect(apiHosts, [
      'old-tunnel.trycloudflare.com',
      'restarted-tunnel.trycloudflare.com',
    ]);
  });

  test('reports discovery service outages without sending to a fallback host',
      skip: discoveryEndpoint.isEmpty
          ? 'Run with --dart-define=API_DISCOVERY_URL to test discovery'
          : false, () async {
    final apiRequests = <Uri>[];

    await http.runWithClient(
      () async {
        await expectLater(
          ApiConfig.send(
            '/auth/login',
            (uri) async {
              apiRequests.add(uri);
              return http.Response('unexpected', 200);
            },
          ),
          throwsA(isA<ApiDiscoveryException>()),
        );
      },
      () => MockClient((request) async => http.Response(
            '{"success":false,"message":"No active tunnel"}',
            503,
          )),
    );

    expect(apiRequests, isEmpty);
  });
}
