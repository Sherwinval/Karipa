import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/screens/leaderboard_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/unit_preferences.dart';

Future<void> mountLeaderboard(
    WidgetTester tester, MockClient client) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'token': 'test-token',
    'userId': '2',
    'name': 'Alex Runner',
  });
  await http.runWithClient(
    () async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider(create: (_) => UnitPreferences()),
          ],
          child: const MaterialApp(home: LeaderboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
    },
    () => client,
  );
}

void main() {
  testWidgets('shows weekly ranks using preferred distance units',
      (tester) async {
    await mountLeaderboard(
      tester,
      MockClient((request) async {
        expect(request.url.path, '/api/activities/leaderboard/weekly');
        return http.Response(
          jsonEncode({
            'success': true,
            'periodStart': '2026-10-17T16:00:00.000Z',
            'periodEnd': '2026-10-20T00:00:00.000Z',
            'entries': [
              {
                'rank': 1,
                'name': 'Alex Runner',
                'distanceMeters': 12000,
                'isCurrentUser': true,
              },
              {
                'rank': 2,
                'name': 'Jordan Athlete',
                'distanceMeters': 9000,
                'isCurrentUser': false,
              },
            ],
          }),
          200,
        );
      }),
    );

    expect(find.text('Weekly Leaderboard'), findsOneWidget);
    expect(find.text('Your weekly rank'), findsOneWidget);
    expect(find.text('#1 · 12.00 km'), findsOneWidget);
    expect(find.text('Jordan Athlete'), findsOneWidget);
    expect(find.text('Only display names and total distances are shown. Activity details are private.'),
        findsOneWidget);
  });

  testWidgets('shows a retry action when leaderboard loading fails',
      (tester) async {
    await mountLeaderboard(
      tester,
      MockClient((_) async =>
          http.Response(jsonEncode({'message': 'Leaderboard unavailable'}), 503)),
    );

    expect(find.text('Could not load the leaderboard'), findsOneWidget);
    expect(find.text('Leaderboard unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
