import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/screens/activity_complete_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/unit_preferences.dart';
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
        expect(find.textContaining('FREE RECORDING'), findsOneWidget);
        expect(find.textContaining('Planned route:'), findsNothing);

        await tester.tap(find.text('Save Activity'));
        await tester.pumpAndSettle();

        expect(
            find.text(
                'The server confirmed this activity was saved to your account.'),
            findsOneWidget);
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
        return http.Response(
          jsonEncode({
            'success': true,
            'activity': {'id': '1'}
          }),
          201,
        );
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
        await tester.tap(find.text('Save Activity'));
        await tester.pumpAndSettle();
        expect(find.text('Retry Save'), findsOneWidget);

        await tester.ensureVisible(find.text('Retry Save'));
        await tester.tap(find.text('Retry Save'));
        await tester.pumpAndSettle();
        expect(find.text('Activity saved'), findsOneWidget);
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
}
