import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/screens/main_navigation_shell.dart';
import 'package:karipa/screens/profile_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/theme_service.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/widgets/main_navigation_bar.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

class _Fixture {
  final routes = _Routes();
  int activities = 0;
  int profiles = 0;
  int leaderboard = 0;
  final navigator = GlobalKey<NavigatorState>();
}

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  bool guest = false,
  double width = 390,
  double height = 844,
  double scale = 1,
  Future<http.Response> Function(http.Request)? respond,
  bool settle = true,
  required Future<void> Function() run,
}) async {
  SharedPreferences.setMockInitialValues(guest
      ? {'isGuest': true}
      : {
          'token': 'fixture-token',
          'userId': 'fixture',
          'name': 'Alex Long Family Name',
        });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  await http.runWithClient(() async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => UnitPreferences()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
        ],
        child: Consumer<ThemeService>(
            builder: (context, theme, _) => MaterialApp(
                  navigatorKey: fixture.navigator,
                  navigatorObservers: [fixture.routes],
                  theme: AppTheme.buildTheme(useGoogleFonts: false),
                  darkTheme: AppTheme.buildTheme(
                      useGoogleFonts: false, brightness: Brightness.dark),
                  themeMode: theme.themeMode,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: const MainNavigationShell(),
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                      settings: settings,
                      builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(settings.name!)),
                          body: const Text('Secondary screen'))),
                ))));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    try {
      await run();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  },
      () => MockClient((request) async {
            if (request.url.path.endsWith('/auth/profile')) {
              fixture.profiles++;
            } else if (request.url.path.endsWith('/leaderboard/weekly')) {
              fixture.leaderboard++;
            } else if (request.url.path.endsWith('/activities')) {
              fixture.activities++;
            }
            if (respond != null) return respond(request);
            if (request.url.path.endsWith('/auth/profile')) {
              return http.Response(
                  '{"success":true,"profile":{"heightCm":176,"weightKg":72}}',
                  200);
            }
            if (request.url.path.endsWith('/leaderboard/weekly')) {
              return http.Response('{"success":true,"entries":[]}', 200);
            }
            return http.Response('{"success":true,"activities":[]}', 200);
          }));
}

Future<void> _tab(WidgetTester tester, int index) async {
  final labels = ['Home', 'Leaderboard', 'History', 'Profile'];
  await tester.tap(find.descendant(
      of: find.byType(MainNavigationBar), matching: find.text(labels[index])));
  await tester.pumpAndSettle();
  expect(find.byType(MainNavigationBar), findsOneWidget);
  expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .currentIndex,
      index);
}

void main() {
  testWidgets('loading and failures keep the shared bar available',
      (tester) async {
    final fixture = _Fixture();
    final pending = Completer<http.Response>();
    await _mount(tester, fixture, settle: false, respond: (request) async {
      if (request.url.path.endsWith('/activities')) return pending.future;
      return http.Response('{"message":"Access restricted"}', 403);
    }, run: () async {
      expect(find.byType(MainNavigationBar), findsOneWidget);
      await _tab(tester, 1);
      expect(find.text('Could not load the leaderboard'), findsOneWidget);
      await _tab(tester, 0);
      expect(fixture.activities, 1);
      pending.complete(http.Response('{"message":"History unavailable"}', 503));
      await tester.pumpAndSettle();
      await _tab(tester, 2);
      expect(find.text('Try Again'), findsOneWidget);
      await _tab(tester, 0);
      expect(fixture.navigator.currentState!.canPop(), false);
    });
  });

  testWidgets(
      'populated History retains detail arguments and refreshes on return',
      (tester) async {
    final fixture = _Fixture();
    await _mount(tester, fixture,
        respond: (_) async => http.Response(
            '{"success":true,"activities":[{"id":"walk","activityType":"walking","distanceKm":1.5,"durationSeconds":900,"startedAt":"2026-11-27T08:00:00Z","calories":null}]}',
            200),
        run: () async {
          await _tab(tester, 2);
          final before = fixture.activities;
          await tester.tap(find.text('WALKING'));
          await tester.pumpAndSettle();
          expect(find.byType(MainNavigationBar), findsNothing);
          fixture.navigator.currentState!.pop(true);
          await tester.pumpAndSettle();
          expect(fixture.activities, before + 1);
          expect(
              tester
                  .widget<MainNavigationBar>(find.byType(MainNavigationBar))
                  .currentIndex,
              2);
          expect(tester.takeException(), isNull);
        });
  });

  testWidgets('one bar and one root route across repeated tab switches',
      (tester) async {
    final fixture = _Fixture();
    await _mount(tester, fixture, run: () async {
      expect(fixture.activities, 1);
      expect(fixture.profiles, 0);
      expect(fixture.leaderboard, 0);
      final barState = tester.element(find.byType(MainNavigationBar));
      for (var pass = 0; pass < 2; pass++) {
        for (final index in [1, 0, 2, 0, 3, 0]) {
          await _tab(tester, index);
          expect(
              tester.element(find.byType(MainNavigationBar)), same(barState));
          expect(find.byType(Scaffold), findsOneWidget);
          expect(find.byTooltip('Back'), findsNothing);
          expect(fixture.navigator.currentState!.canPop(), false);
        }
      }
      expect(fixture.routes.pushes, 1);
      final requests = fixture.activities;
      await _tab(tester, 0);
      expect(fixture.activities, requests);
      expect(fixture.routes.pushes, 1);
      await tester.tap(find.byTooltip('Open profile'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MainNavigationBar>(find.byType(MainNavigationBar))
              .currentIndex,
          3);
      await _tab(tester, 0);
      await tester.ensureVisible(find.text('View all'));
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MainNavigationBar>(find.byType(MainNavigationBar))
              .currentIndex,
          2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MainNavigationBar>(find.byType(MainNavigationBar))
              .currentIndex,
          0);
      expect(fixture.routes.pushes, 1);
    });
  });

  testWidgets('Profile drafts survive switching and inactive polling pauses',
      (tester) async {
    final fixture = _Fixture();
    await _mount(tester, fixture, run: () async {
      await _tab(tester, 3);
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '181');
      final state = tester.state(find.byType(ProfileScreen));
      await _tab(tester, 0);
      final requests = fixture.profiles;
      await tester.pump(const Duration(seconds: 15));
      expect(fixture.profiles, requests);
      await _tab(tester, 3);
      expect(tester.state(find.byType(ProfileScreen)), same(state));
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '181');
      await tester.ensureVisible(find.text('Imperial'));
      await tester.tap(find.text('Imperial'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '5.94');
      await tester.ensureVisible(find.text('Dark mode'));
      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();
      expect(
          Theme.of(tester.element(find.byType(MainNavigationBar))).brightness,
          Brightness.dark);
      await _tab(tester, 0);
      await _tab(tester, 3);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '5.94');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final beforePoll = fixture.profiles;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(fixture.profiles, beforePoll + 1);
    });
  });

  testWidgets('nested routes hide the bar and return to the selected tab',
      (tester) async {
    final fixture = _Fixture();
    await _mount(tester, fixture, run: () async {
      await _tab(tester, 2);
      fixture.navigator.currentState!.pushNamed('/activity_details');
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationBar), findsNothing);
      fixture.navigator.currentState!.pop(true);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MainNavigationBar>(find.byType(MainNavigationBar))
              .currentIndex,
          2);
      await _tab(tester, 3);
      await tester.ensureVisible(find.text('Sign Out'));
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationShell), findsNothing);
      expect(fixture.navigator.currentState!.canPop(), false);
      expect(find.text('/login'), findsOneWidget);
    });
  });

  for (final (width, height, scale) in [
    (320.0, 640.0, 2.0),
    (390.0, 844.0, 1.0),
    (640.0, 360.0, 2.0)
  ]) {
    testWidgets('guest shell fits $width x $height at $scale', (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture,
          guest: true,
          width: width,
          height: height,
          scale: scale, run: () async {
        for (final index in [1, 2, 3, 0]) {
          await _tab(tester, index);
          expect(tester.getRect(find.byType(MainNavigationBar)).bottom,
              lessThanOrEqualTo(height));
          expect(
              find
                  .descendant(
                      of: find.byType(MainNavigationBar),
                      matching: find.text('Home'))
                  .hitTestable(),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await _tab(tester, 3);
        if (height > 500) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Exit Guest Mode'));
        expect(find.text('Exit Guest Mode').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
