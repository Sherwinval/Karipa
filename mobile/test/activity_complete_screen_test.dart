import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/models/route_model.dart';
import 'package:karipa/screens/activity_complete_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/widgets/route_map_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Free Recording is reviewed and saved only after confirmation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'token': 'test-token'});

    Map<String, dynamic>? submitted;
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthService()),
              ChangeNotifierProvider(create: (_) => UnitPreferences()),
            ],
            child: MaterialApp(
              home: ActivityCompleteScreen(
                activityType: 'walking',
                recordingMode: 'free_recording',
                distanceKm: 1.2,
                durationSeconds: 600,
                totalElapsedSeconds: 720,
                startedAt: DateTime.utc(2026, 10, 20, 7),
                completedAt: DateTime.utc(2026, 10, 20, 7, 12),
                paceOrSpeed: '08:20 min/km',
                averagePaceSecondsPerKm: 500,
                calories: null,
                calorieUnavailableReason: 'Weight is not set.',
                route: null,
                gpsPoints: const [],
                gpsData: const [],
                idempotencyKey: 'session-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Walking · Free recording'), findsOneWidget);
        expect(find.text('Not saved yet'), findsOneWidget);
        expect(find.text('Planned route'), findsNothing);
        expect(submitted, isNull);

        final save = find.widgetWithText(FilledButton, 'Save activity');
        final saveRect = tester.getRect(save);
        await tester.tap(save);
        await tester.pump();
        final saving = find.widgetWithText(FilledButton, 'Saving…');
        expect(tester.getRect(saving), saveRect);
        expect(tester.widget<FilledButton>(saving).onPressed, isNull);
        expect(
          tester
              .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Discard activity'))
              .onPressed,
          isNull,
        );
        response.complete(http.Response(
          jsonEncode({
            'success': true,
            'activity': {'id': '1'}
          }),
          201,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Saved to your account'), findsOneWidget);
        expect(find.text('Not saved yet'), findsNothing);
        expect(find.text('Back to Home').hitTestable(), findsOneWidget);
        expect(
            find.text('View Activity History').hitTestable(), findsOneWidget);
        expect(submitted?['recordingMode'], 'free_recording');
        expect(submitted?['distanceMeters'], 1200);
        expect(submitted?['durationSeconds'], 600);
        expect(submitted?['totalElapsedSeconds'], 720);
        expect(submitted?['targetDistanceMeters'], isNull);
        expect(submitted?['routeData'], isNull);
        expect(submitted?['idempotencyKey'], 'session-1');
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/activities');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return response.future;
      }),
    );
  });

  testWidgets('failed saves can retry with the same idempotency key',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'token': 'test-token'});

    final submittedKeys = <String>[];
    var requestCount = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthService()),
              ChangeNotifierProvider(create: (_) => UnitPreferences()),
            ],
            child: MaterialApp(
              home: ActivityCompleteScreen(
                activityType: 'cycling',
                recordingMode: 'free_recording',
                distanceKm: 0,
                durationSeconds: 0,
                totalElapsedSeconds: 0,
                startedAt: DateTime.utc(2026, 10, 20, 7),
                completedAt: DateTime.utc(2026, 10, 20, 7),
                paceOrSpeed: 'Unavailable',
                calories: null,
                route: null,
                gpsPoints: const [],
                idempotencyKey: 'same-session',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save activity'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Temporarily unavailable').hitTestable(),
            findsOneWidget);
        expect(find.text('Retry save').hitTestable(), findsOneWidget);

        await tester.tap(find.text('Retry save'));
        await tester.pumpAndSettle();
        expect(find.text('Saved to your account'), findsOneWidget);
        expect(requestCount, 2);
        expect(submittedKeys, ['same-session', 'same-session']);
      },
      () => MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        submittedKeys.add(body['idempotencyKey'] as String);
        if (requestCount == 1) {
          return http.Response(
              jsonEncode(
                  {'success': false, 'message': 'Temporarily unavailable'}),
              503);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'activity': {'id': '2'}
          }),
          200,
        );
      }),
    );
  });

  testWidgets('metric rows stay aligned and actions respect the safe area',
      (tester) async {
    await _pumpReview(tester, size: const Size(390, 844));
    final gpsCard = find.bySemanticsLabel('GPS distance: 12.50 km');
    final durationCard = find.bySemanticsLabel('Active duration: 10:00');
    expect(tester.getTopLeft(gpsCard).dy, tester.getTopLeft(durationCard).dy);
    expect(tester.getSize(gpsCard), tester.getSize(durationCard));
    expect(tester.getTopLeft(find.text('12.50')).dy,
        tester.getTopLeft(find.text('10:00')).dy);
    expect(find.byType(RouteMapWidget), findsNothing);

    final save = find.widgetWithText(FilledButton, 'Save activity');
    final discard = find.widgetWithText(TextButton, 'Discard activity');
    final saveRect = tester.getRect(save);
    final discardRect = tester.getRect(discard);
    expect(saveRect.height, greaterThanOrEqualTo(48));
    expect(discardRect.height, greaterThanOrEqualTo(48));
    expect(discardRect.bottom, lessThanOrEqualTo(844 - 24));
    expect(saveRect.width, discardRect.width);
    final reason = find.text('Weight is not set.');
    await tester.ensureVisible(reason);
    expect(reason.hitTestable(), findsOneWidget);
    expect(tester.getRect(save), saveRect);
    expect(tester.takeException(), isNull);
  });

  for (final (size, brightness) in [
    (const Size(320, 640), Brightness.light),
    (const Size(640, 320), Brightness.dark),
  ]) {
    testWidgets('review and discard remain reachable at $size and 200% text',
        (tester) async {
      await _pumpReview(tester,
          size: size, textScale: 2, brightness: brightness, planned: true);
      expect(find.text('Cycling · Planned route'), findsOneWidget);
      expect(find.text('Average speed'), findsOneWidget);
      expect(find.text('mph'), findsOneWidget);
      expect(find.text('102:03:04'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.textContaining('Network distance 9.32 mi'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Active duration')).dy,
          greaterThan(tester.getTopLeft(find.text('GPS distance')).dy));
      expect(find.text('Save activity').hitTestable(), findsNothing);

      final discard = find.widgetWithText(TextButton, 'Discard activity');
      await tester.ensureVisible(discard);
      await tester.pumpAndSettle();
      expect(find.text('Save activity').hitTestable(), findsOneWidget);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(find.text('Discard activity?'), findsOneWidget);
      final keep = find.widgetWithText(TextButton, 'Keep reviewing');
      final confirm = find.widgetWithText(FilledButton, 'Discard activity');
      expect(tester.getSize(keep).width, tester.getSize(confirm).width);
      expect(tester.getSize(keep).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(keep);
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(find.text('Not saved yet'), findsOneWidget);
      expect(find.text('Discard activity?'), findsNothing);

      await tester.tap(discard);
      await tester.pumpAndSettle();
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Home fixture'), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {'unitSystem'});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('guest save confirms device storage and opens history',
      (tester) async {
    await _pumpReview(tester, size: const Size(640, 320), textScale: 2);
    final save = find.text('Save activity');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device').hitTestable(), findsOneWidget);
    expect(find.text('Saved to your account'), findsNothing);
    await tester.tap(find.text('View Activity History'));
    await tester.pumpAndSettle();
    expect(find.text('History fixture'), findsOneWidget);
  });
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool planned = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues(
      {if (planned) 'unitSystem': 'imperial'});

  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => UnitPreferences(),
    child: MaterialApp(
      theme: AppTheme.buildTheme(brightness: brightness, useGoogleFonts: false),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ActivityCompleteScreen(
        activityType: planned ? 'cycling' : 'running',
        recordingMode: planned ? 'plan_route' : 'free_recording',
        distanceKm: 12.5,
        durationSeconds: planned ? 367384 : 600,
        totalElapsedSeconds: planned ? 370000 : 720,
        paceOrSpeed: planned ? '14.8 mph' : '08:20 /km',
        calories: null,
        calorieUnavailableReason: 'Weight is not set.',
        gpsPoints: const [],
        idempotencyKey: 'guest-session',
        route: planned
            ? PathRoute.fromJson({
                'id': 'planned-route',
                'distanceKm': 15,
                'targetDistanceKm': 14,
              })
            : null,
      ),
      routes: {
        '/home': (_) => const Scaffold(body: Text('Home fixture')),
        '/activity_history': (_) =>
            const Scaffold(body: Text('History fixture')),
      },
    ),
  ));
  await tester.pumpAndSettle();
}
