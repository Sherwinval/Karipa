import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/config/api_config.dart';

void main() {
  group('ApiConfig.normalizeBaseUrl', () {
    test('adds the API prefix to an origin', () {
      expect(
        ApiConfig.normalizeBaseUrl(
            'https://canvas-moss-greeting-reynolds.trycloudflare.com'),
        'https://canvas-moss-greeting-reynolds.trycloudflare.com/api',
      );
    });

    test('does not duplicate an existing API prefix', () {
      expect(
        ApiConfig.normalizeBaseUrl('http://192.168.1.25:3000/api/'),
        'http://192.168.1.25:3000/api',
      );
      expect(
        ApiConfig.normalizeBaseUrl('https://api.example.com/api/api'),
        'https://api.example.com/api',
      );
    });

    test('rejects unsupported or incomplete URLs', () {
      expect(
        () => ApiConfig.normalizeBaseUrl('ftp://api.example.com'),
        throwsArgumentError,
      );
      expect(
        () => ApiConfig.normalizeBaseUrl('https://api.example.com?key=value'),
        throwsArgumentError,
      );
    });
  });
}
