import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _discoveryUrl = String.fromEnvironment('API_DISCOVERY_URL');
  static String get _cachedBaseUrlKey =>
      'discoveredApiBaseUrl:${Uri.encodeComponent(_discoveryUrl.trim())}';
  static const _discoveryTimeout = Duration(seconds: 6);
  static String? _cachedBaseUrl;
  static Future<String>? _discoveryInFlight;
  static Future<void>? _cacheLoad;

  static String get baseUrl {
    final configuredBaseUrl = _configuredBaseUrl.trim();
    if (configuredBaseUrl.isNotEmpty) {
      return normalizeBaseUrl(configuredBaseUrl);
    }

    if (kIsWeb) return normalizeBaseUrl('http://localhost:3000');
    if (Platform.isAndroid) return normalizeBaseUrl('http://10.0.2.2:3000');
    return normalizeBaseUrl('http://localhost:3000');
  }

  static bool get _hasDiscovery =>
      _configuredBaseUrl.trim().isEmpty && _discoveryUrl.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (!_hasDiscovery) return;
    try {
      await _resolveBaseUrl();
    } on ApiDiscoveryException catch (error) {
      debugPrint(error.message);
    }
  }

  static Future<http.Response> send(
    String path,
    Future<http.Response> Function(Uri uri) request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final baseUrl = await _resolveBaseUrl();
    late final http.Response response;
    try {
      response = await _sendOnce(baseUrl, path, request, timeout);
    } on IOException catch (error, stackTrace) {
      return _retryAfterConnectionFailure(
        baseUrl,
        path,
        request,
        timeout,
        error,
        stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      return _retryAfterConnectionFailure(
        baseUrl,
        path,
        request,
        timeout,
        error,
        stackTrace,
      );
    } on TimeoutException catch (error, stackTrace) {
      return _retryAfterConnectionFailure(
        baseUrl,
        path,
        request,
        timeout,
        error,
        stackTrace,
      );
    }
    if (!_hasDiscovery || response.statusCode < 502) return response;

    final refreshedBaseUrl = await _discover();
    if (refreshedBaseUrl == baseUrl) return response;
    return _sendOnce(refreshedBaseUrl, path, request, timeout);
  }

  static Future<http.Response> _retryAfterConnectionFailure(
    String baseUrl,
    String path,
    Future<http.Response> Function(Uri uri) request,
    Duration timeout,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (!_hasDiscovery) Error.throwWithStackTrace(error, stackTrace);
    final refreshedBaseUrl = await _discover();
    if (refreshedBaseUrl == baseUrl) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return _sendOnce(refreshedBaseUrl, path, request, timeout);
  }

  static Future<String> _resolveBaseUrl() async {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(_configuredBaseUrl);
    }
    if (!_hasDiscovery) return baseUrl;

    await (_cacheLoad ??= _loadCachedBaseUrl());
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    return _discover();
  }

  static Future<void> _loadCachedBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString(_cachedBaseUrlKey);
    if (cached == null) return;
    try {
      final normalized = normalizeBaseUrl(cached);
      final uri = Uri.parse(normalized);
      if (uri.scheme == 'https' && uri.host.endsWith('.trycloudflare.com')) {
        _cachedBaseUrl = normalized;
      } else {
        await preferences.remove(_cachedBaseUrlKey);
      }
    } on FormatException {
      await preferences.remove(_cachedBaseUrlKey);
    } on ArgumentError {
      await preferences.remove(_cachedBaseUrlKey);
    }
  }

  static Future<String> _discover() {
    if (_discoveryInFlight != null) return _discoveryInFlight!;
    final future = _fetchDiscoveredBaseUrl();
    _discoveryInFlight = future;
    return future.whenComplete(() {
      _discoveryInFlight = null;
    });
  }

  static Future<String> _fetchDiscoveredBaseUrl() async {
    final endpoint = Uri.tryParse(_discoveryUrl.trim());
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw const ApiDiscoveryException(
        'API discovery is not configured with a valid HTTPS URL.',
      );
    }

    late final http.Response response;
    try {
      response = await http.get(
        endpoint,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache'
        },
      ).timeout(_discoveryTimeout);
    } on IOException {
      throw const ApiDiscoveryException(
        'The API discovery service is unreachable. Check your internet connection.',
      );
    } on http.ClientException {
      throw const ApiDiscoveryException(
        'The API discovery service is unreachable. Check your internet connection.',
      );
    } on TimeoutException {
      throw const ApiDiscoveryException(
        'API tunnel discovery timed out. Check your internet connection and try again.',
      );
    }
    if (response.statusCode != 200) {
      throw ApiDiscoveryException(
        'Could not discover the current API tunnel (HTTP ${response.statusCode}). '
        'Check that the backend, tunnel, and discovery service are running.',
      );
    }

    final dynamic payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      throw const ApiDiscoveryException(
        'The API discovery service returned invalid JSON.',
      );
    }
    if (payload is! Map ||
        payload['success'] != true ||
        payload['url'] is! String) {
      throw const ApiDiscoveryException(
        'The API discovery service did not return an active tunnel URL.',
      );
    }

    final String discoveredBaseUrl;
    try {
      discoveredBaseUrl = normalizeBaseUrl(payload['url'] as String);
    } on FormatException {
      throw const ApiDiscoveryException(
        'The discovery service returned an invalid tunnel URL.',
      );
    } on ArgumentError {
      throw const ApiDiscoveryException(
        'The discovery service returned an invalid tunnel URL.',
      );
    }
    final discoveredUri = Uri.parse(discoveredBaseUrl);
    if (discoveredUri.scheme != 'https' ||
        !discoveredUri.host.endsWith('.trycloudflare.com')) {
      throw const ApiDiscoveryException(
        'The discovery service returned an invalid Cloudflare Quick Tunnel URL.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cachedBaseUrlKey, discoveredBaseUrl);
    _cachedBaseUrl = discoveredBaseUrl;
    return discoveredBaseUrl;
  }

  static Future<http.Response> _sendOnce(
    String baseUrl,
    String path,
    Future<http.Response> Function(Uri uri) request,
    Duration timeout,
  ) {
    final uri = Uri.parse('$baseUrl$path');
    return request(uri).timeout(timeout);
  }

  @visibleForTesting
  static void resetForTesting() {
    _cachedBaseUrl = null;
    _discoveryInFlight = null;
    _cacheLoad = null;
  }

  static String normalizeBaseUrl(String value) {
    final uri = Uri.parse(value.trim());
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        value,
        'API_BASE_URL',
        'Expected an HTTP(S) origin with an optional /api path.',
      );
    }

    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final pathWithoutApiSuffix =
        path.replaceFirst(RegExp(r'(?:/api)+$', caseSensitive: false), '');
    return uri.replace(path: '$pathWithoutApiSuffix/api').toString();
  }
}

class ApiDiscoveryException implements Exception {
  final String message;

  const ApiDiscoveryException(this.message);

  @override
  String toString() => message;
}
