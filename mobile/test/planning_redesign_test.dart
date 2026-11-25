import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/screens/route_planning_screen.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/utils/planning_duration.dart';

Future<void> mount(WidgetTester tester,
    {String activity = 'running',
    double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.light,
    double keyboard = 0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(brightness: brightness, useGoogleFonts: false),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: child!),
      home: RoutePlanningScreen(activity: activity)));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

double distance(WidgetTester tester) => double.parse(tester
    .getSemantics(find.bySemanticsLabel('Selected distance'))
    .getSemanticsData()
    .value
    .split(' ')
    .first);

void main() {
  testWidgets('location failure is revealed and generation can be retried',
      (tester) async {
    const gps = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(gps, (_) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(gps, null));
    await mount(tester);
    await tap(tester, 'Generate Routes');
    final error = find.text(
        'Location services are turned off on your device. Please enable GPS in your device settings.');
    expect(error, findsOneWidget);
    expect(tester.getRect(error).bottom,
        lessThan(tester.getRect(find.byType(ElevatedButton)).top));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
  for (final activity in ['walking', 'jogging', 'running', 'cycling']) {
    testWidgets(
        '$activity submits actual custom distance and preferences once and returns from results',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const gps = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          gps,
          (call) async => switch (call.method) {
                'isLocationServiceEnabled' => true,
                'checkPermission' => 2,
                'getCurrentPosition' => {
                    'latitude': 0.0,
                    'longitude': 0.0,
                    'timestamp': 1700000000000,
                    'accuracy': 5.0,
                    'altitude': 0.0,
                    'heading': 0.0,
                    'speed': 0.0,
                    'speed_accuracy': 0.0
                  },
                _ => null,
              });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(gps, null));
      final response = Completer<http.Response>();
      final requests = <http.Request>[];
      RouteSettings? destination;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            home: RoutePlanningScreen(activity: activity),
            onGenerateRoute: (settings) {
              destination = settings;
              return MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Route results fixture')));
            }));
        await tester.pumpAndSettle();
        await tap(tester, 'Enter a custom distance');
        await tester.enterText(find.byType(TextField), '42.5');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Avoid Major Roads'));
        await tester.tap(find.text('Avoid Major Roads'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Generate Routes'));
        await tester.tap(find.text('Generate Routes'));
        for (int i = 0; i < 10 && requests.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(requests.length, 1);
        await tester.pump();
        final payload =
            jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(payload['activity'], activity);
        expect(payload['targetDistanceKm'], 42.5);
        expect(payload['preferences'], {
          'preferLoop': true,
          'avoidMajorRoads': false,
          'preferSidewalks': true,
          'preferCyclingInfrastructure': activity == 'cycling'
        });
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNull);
        response.complete(http.Response(
            jsonEncode({
              'success': true,
              'routes': [
                {'id': 'fixture', 'distanceKm': 42.5}
              ]
            }),
            200));
        await tester.pumpAndSettle();
        expect(destination?.name, '/recommended_routes');
        expect((destination!.arguments as Map)['targetDistanceKm'], 42.5);
        expect((destination!.arguments as Map)['activity'], activity);
        Navigator.pop(tester.element(find.text('Route results fixture')));
        await tester.pumpAndSettle();
        expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '42.5');
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNotNull);
      },
          () => MockClient((request) {
                requests.add(request);
                return response.future;
              }));
    });
  }
  test('duration references differ by activity and format longer sessions', () {
    expect(planningDuration('walking', 5).duration, '~1 hr');
    expect(planningDuration('jogging', 5).duration, '~40 min');
    expect(planningDuration('running', 5).duration, '~30 min');
    expect(planningDuration('cycling', 25).duration, '~1 hr 15 min');
    expect(planningDuration('unknown', 5).duration, 'Unavailable');
    expect(planningDuration('walking', double.nan).duration, 'Unavailable');
  });
  testWidgets(
      'presets, custom target, standard slider and estimates stay synchronized',
      (tester) async {
    await mount(tester);
    final semantics = tester.ensureSemantics();
    await tap(tester, '5K');
    expect(distance(tester), 5);
    expect(find.text('~30 min'), findsOneWidget);
    await tap(tester, '~42.5K');
    expect(distance(tester), 42.5);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 5);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    await tap(tester, 'Return to standard slider');
    expect(distance(tester), 5);
    expect(find.byType(TextField), findsNothing);
    await tap(tester, 'Half 21K');
    expect(distance(tester), 21);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(22.5);
    await tester.pumpAndSettle();
    expect(distance(tester), 22.5);
    expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((chip) => chip.selected),
        isEmpty);
    semantics.dispose();
  });
  for (final activity in ['walking', 'jogging', 'running', 'cycling']) {
    testWidgets('$activity preserves limits, defaults and title',
        (tester) async {
      await mount(tester, activity: activity);
      expect(
          find.text(
              'Plan ${activity[0].toUpperCase()}${activity.substring(1)}'),
          findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 3);
      expect(slider.max, 30);
      expect(slider.divisions, 54);
      final switches =
          tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(switches.length, activity == 'cycling' ? 4 : 3);
      expect(switches.every((tile) => tile.value), true);
      expect(find.byType(TextField), findsNothing);
      if (activity == 'cycling') {
        await tap(tester, '50 km');
        expect(find.text('~2 hr 30 min'), findsOneWidget);
      }
    });
  }
  for (final width in [320.0, 360.0, 375.0, 390.0, 414.0, 430.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          '$width $brightness expanded custom at 200% text with keyboard',
          (tester) async {
        await mount(tester,
            width: width, brightness: brightness, scale: 2, keyboard: 220);
        await tap(tester, 'Enter a custom distance');
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '30.25');
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNull);
        await tester.enterText(find.byType(TextField), '100');
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNotNull);
        await tester.ensureVisible(find.text('Prioritize Sidewalks & Trails'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byType(ElevatedButton)).bottom,
            lessThanOrEqualTo(844 - 220));
        expect(
            tester.getRect(find.text('Prioritize Sidewalks & Trails')).bottom,
            lessThan(tester.getRect(find.byType(ElevatedButton)).top));
      });
    }
  }
}
