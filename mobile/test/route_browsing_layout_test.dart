import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/models/route_model.dart';
import 'package:karipa/screens/ready_to_start_screen.dart';
import 'package:karipa/screens/recommended_routes_screen.dart';
import 'package:karipa/screens/route_details_screen.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/widgets/route_map_widget.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _technicalName = 'Valhalla Generated out-and-back (0.75x)';
const _reasoning =
    'Distance is 4.097 km. Preferences were considered among suitable candidates '
    'and the route exceeds the requested distance by 0.097 km.';
const _notice =
    'These requests could not be verified from available routing data: street lighting.';

void main() {
  late BuiltInMapCachingProvider tileCache;
  setUpAll(() {
    tileCache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory:
          Directory('build/route-browsing-test-cache').absolute.path,
      maxCacheSize: null,
      readOnly: true,
    );
  });
  tearDownAll(() => tileCache.destroy());

  final sizes = [
    const Size(320, 460),
    const Size(360, 640),
    const Size(365, 810),
    const Size(390, 844),
    const Size(430, 844),
    const Size(640, 320),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('route browsing at $size, text $scale, ${brightness.name}',
            (tester) async {
          final route = _route();
          final settings = await _pumpRoutes(tester,
              routes: [route],
              size: size,
              scale: scale,
              brightness: brightness);

          expect(find.text('Recommended Routes'), findsOneWidget);
          expect(find.text('Running · 4.0 km target'), findsOneWidget);
          expect(find.text('1 route available'), findsOneWidget);
          final view = find.text('View route');
          await tester.scrollUntilVisible(view, 120);
          expect(find.text('Out-and-back route'), findsOneWidget);
          expect(find.text('4.10 km · Est. 49 min'), findsOneWidget);
          expect(
              find.text('0.10 km above your 4.00 km target'), findsOneWidget);
          expect(find.text(_technicalName), findsNothing);
          expect(find.text(_reasoning), findsNothing);
          expect(tester.takeException(), isNull);

          await _tap(tester, view);
          expect(settings.single.name, '/route_details');
          expect(settings.single.arguments, {
            'route': route,
            'activity': 'running',
            'currentLocation': _currentLocation,
          });
          expect(find.text('Route details'), findsOneWidget);
          expect(find.text('Out-and-back route'), findsOneWidget);
          expect(find.text('Target 4.00 km · 0.10 km longer'), findsOneWidget);
          expect(find.text(_technicalName), findsNothing);
          expect(find.text(_reasoning), findsNothing);
          expect(find.text('Map preview unavailable.'), findsOneWidget);
          expect(
              find.text('Route conditions aren’t verified.'), findsOneWidget);

          final action =
              find.widgetWithText(FilledButton, 'Select route & prepare');
          final actionRect = tester.getRect(action);
          expect(actionRect.height, greaterThanOrEqualTo(56));
          expect(actionRect.bottom, lessThanOrEqualTo(size.height - 24));
          expect(action.hitTestable(), findsOneWidget);
          await _tap(tester, find.byTooltip('Route information'));
          await tester.ensureVisible(
              find.textContaining('Map data does not verify sidewalks'));
          await tester.pumpAndSettle();
          expect(find.text(_technicalName), findsOneWidget);
          expect(find.text(_reasoning), findsOneWidget);
          expect(find.text('AI-assisted tie-break'), findsOneWidget);
          expect(find.textContaining('Absolute deviation'), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text(_reasoning), findsNothing);
          expect(tester.getRect(action), actionRect);
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);

          await _tap(tester, action);
          expect(settings.last.name, '/ready_to_start');
          expect(settings.last.arguments, settings.first.arguments);
          expect(find.text('Ready to Start'), findsOneWidget);
          expect(find.text(_technicalName), findsOneWidget);
          expect(find.text('GPS Signal Acquired • High Accuracy Ready'),
              findsOneWidget);
          expect(tester.takeException(), isNull);

          await _tap(tester, find.text('START ACTIVITY'));
          expect(settings.last.name, '/active_tracking');
          expect(settings.last.arguments, {
            'route': route,
            'activity': 'running',
            'initialPosition': _currentLocation,
          });
          expect(find.text('Tracking fixture'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('Recommended Routes'), findsOneWidget);
        });
      }
    }
  }

  testWidgets(
      'ranking disclosure keeps warnings visible and handles imperial units',
      (tester) async {
    const customName =
        'Riverside and neighborhood trail from the old market to the community park';
    final route = _route({
      'name': 'Valhalla Route',
      'distanceKm': 3.9,
      'absoluteDistanceDeviationKm': 0.1,
      'rankingSource': 'deterministic_fallback',
      'isTopRecommendation': false,
      'closeCandidateAvailable': false,
      'preferenceNotice': _notice,
      'features': {'isLoop': false},
      'durationSeconds': null,
    });
    final custom = _route({
      'id': 'custom',
      'name': customName,
      'features': <String, Object?>{},
    });
    final settings = await _pumpRoutes(tester,
        routes: [route, custom], activity: 'cycling', imperial: true);

    expect(find.text('Cycling · 2.5 mi target'), findsOneWidget);
    expect(find.text('2 routes available'), findsOneWidget);
    expect(
        find.text('No route is within 0.31 mi of the target.'), findsOneWidget);
    expect(find.text(_notice), findsOneWidget);
    expect(find.textContaining('Deterministic ranking was used'), findsNothing);
    await _tap(tester, find.text('How routes are ranked'));
    expect(
        find.textContaining('Deterministic ranking was used'), findsOneWidget);
    expect(find.text('Generated route'), findsOneWidget);
    expect(find.text('2.42 mi · Time estimate unavailable'), findsOneWidget);
    expect(find.text('0.06 mi below your 2.49 mi target'), findsOneWidget);

    await tester.scrollUntilVisible(find.text(customName), 220);
    final customCard = find.byKey(const ValueKey('custom'));
    final viewCustom =
        find.descendant(of: customCard, matching: find.text('View route'));
    await _tap(tester, viewCustom);
    expect(settings.single.arguments, {
      'route': custom,
      'activity': 'cycling',
      'currentLocation': _currentLocation,
    });
    expect(find.text(customName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty result with no route actions', (tester) async {
    await _pumpRoutes(tester, routes: [], activity: 'walking');
    expect(find.text('Walking · 4.0 km target'), findsOneWidget);
    expect(find.text('0 routes available'), findsOneWidget);
    expect(find.text('View route'), findsNothing);
    expect(find.text('How routes are ranked'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows matches, preserves map geometry, and recenters the details map',
      (tester) async {
    final tile = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aEOQAAAAASUVORK5CYII=');
    await http.runWithClient(() async {
      final route = _route({
        'name': 'Valhalla Generated loop (1x)',
        'distanceKm': 4.0,
        'absoluteDistanceDeviationKm': 0,
        'features': {
          'isLoop': true,
          'roadTypes': ['residential', 'secondary']
        },
        'geometry': {
          'coordinates': [
            [121.148, 14.082],
            [121.151, 14.085],
            [121.148, 14.082]
          ],
        },
      });
      await _pumpRoutes(tester, routes: [route], activity: 'jogging');
      await _tap(tester, find.text('How routes are ranked'));
      expect(find.textContaining('AI explanations and preference signals'),
          findsOneWidget);
      expect(find.text('Only routes within 0.50 km of the target are shown.'),
          findsOneWidget);
      expect(find.text('Matches your 4.00 km target'), findsOneWidget);
      expect(find.text('Loop route'), findsOneWidget);
      final preview =
          tester.widget<RouteMapWidget>(find.byType(RouteMapWidget));
      expect(preview.routePoints, same(route.coordinates));
      expect(preview.interactive, isFalse);

      await _tap(tester, find.text('View route'));
      final map = tester.widget<RouteMapWidget>(find.byType(RouteMapWidget));
      expect(map.routePoints, same(route.coordinates));
      expect(map.interactive, isTrue);
      expect(map.currentLocation, const LatLng(14.08, 121.147));
      final controller =
          tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
      await _tap(tester, find.byTooltip('Recenter map'));
      expect(controller.camera.center.latitude, closeTo(14.08, 0.00001));
      expect(controller.camera.center.longitude, closeTo(121.147, 0.00001));
      expect(controller.camera.zoom, 16);
      await _tap(tester, find.byTooltip('Route information'));
      expect(find.text('Map labels · residential, secondary'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((_) async => http.Response.bytes(tile, 200,
            headers: {'content-type': 'image/png'})));
  });
}

PathRoute _route([Map<String, Object?> overrides = const {}]) =>
    PathRoute.fromJson({
      'id': 'out-and-back',
      'name': _technicalName,
      'activityType': 'running',
      'distanceKm': 4.097,
      'targetDistanceKm': 4.0,
      'absoluteDistanceDeviationKm': 0.097,
      'percentageDistanceDeviation': 2.43,
      'durationSeconds': 2940,
      'maximumDistanceDeviationKm': 0.5,
      'closeCandidateAvailable': true,
      'rankingSource': 'ai_assisted',
      'isTopRecommendation': true,
      'reasoning': _reasoning,
      'features': {'isLoop': false},
      ...overrides,
    });

final _currentLocation = Position(
  latitude: 14.08,
  longitude: 121.147,
  timestamp: DateTime(2026, 11, 26),
  accuracy: 3,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Future<List<RouteSettings>> _pumpRoutes(
  WidgetTester tester, {
  required List<PathRoute> routes,
  Size size = const Size(390, 844),
  double scale = 1.0,
  Brightness brightness = Brightness.light,
  String activity = 'running',
  bool imperial = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues(
      {if (imperial) 'unitSystem': 'imperial'});

  final visited = <RouteSettings>[];
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => UnitPreferences(),
    child: MaterialApp(
      theme: AppTheme.buildTheme(brightness: brightness, useGoogleFonts: false),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      initialRoute: '/recommendations',
      routes: {
        '/': (_) => const Scaffold(),
        '/recommendations': (_) => RecommendedRoutesScreen(
              routes: routes,
              activity: activity,
              targetDistanceKm: 4,
              currentLocation: _currentLocation,
            ),
      },
      onGenerateRoute: (settings) {
        visited.add(settings);
        final args = settings.arguments as Map<String, Object?>;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => switch (settings.name) {
            '/route_details' => RouteDetailsScreen(
                route: args['route'] as PathRoute,
                activity: args['activity'] as String,
                currentLocation: args['currentLocation'] as Position?,
              ),
            '/ready_to_start' => ReadyToStartScreen(
                route: args['route'] as PathRoute,
                activity: args['activity'] as String,
                currentLocation: args['currentLocation'] as Position?,
              ),
            _ =>
              Scaffold(appBar: AppBar(), body: const Text('Tracking fixture')),
          },
        );
      },
    ),
  ));
  await tester.pumpAndSettle();
  return visited;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
