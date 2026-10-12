import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathcraft_mobile/models/activity_model.dart';
import 'package:pathcraft_mobile/screens/home_screen.dart';
import 'package:pathcraft_mobile/services/auth_service.dart';
import 'package:pathcraft_mobile/theme/app_theme.dart';
import 'package:pathcraft_mobile/theme/design_tokens.dart';
import 'package:pathcraft_mobile/widgets/home_dashboard.dart';
import 'package:pathcraft_mobile/widgets/karipa_feedback.dart';

// Test-only data. Production Home continues to fetch through ApiService.
final records = [
  {
    'id': 'walk',
    'activityType': 'walking',
    'distanceKm': 1.5,
    'durationSeconds': 900,
    'calories': 120
  },
  {
    'id': 'cycle',
    'activityType': 'cycling',
    'distanceKm': 10.0,
    'durationSeconds': 1800,
    'calories': 250
  },
  {
    'id': 'jog',
    'activityType': 'jogging',
    'distanceKm': 3.0,
    'durationSeconds': 1200,
    'calories': null
  },
  {
    'id': 'run',
    'activityType': 'running',
    'distanceKm': 2.5,
    'durationSeconds': 900,
    'calories': 200
  },
]
    .map((data) => {
          ...data,
          'startedAt': '2026-10-09T08:00:00',
          'completedAt': '2026-10-09T08:30:00'
        })
    .toList();

class RouteRecorder extends NavigatorObserver {
  final pushes = <RouteSettings>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route.settings);
}

Future<void> mountHome(
  WidgetTester tester, {
  double width = 360,
  double scale = 1,
  double height = 900,
  RouteRecorder? observer,
  bool guest = false,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  SharedPreferences.setMockInitialValues(guest
      ? {'isGuest': true}
      : {
          'token': 'test-only-token',
          'name': 'Alexandria Long Family Name',
          'userId': 'test-only-user'
        });
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AuthService(),
    child: MaterialApp(
      theme: AppTheme.buildTheme(useGoogleFonts: false, brightness: brightness),
      navigatorObservers: [if (observer != null) observer],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: child!,
      ),
      home: const HomeScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
            body: Center(
                child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Return to Home'),
        ))),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> scrollThroughHome(WidgetTester tester) async {
  final scroll = find.descendant(
      of: find.byKey(const ValueKey('home-scroll')),
      matching: find.byType(Scrollable));
  final position = tester.state<ScrollableState>(scroll).position;
  for (double offset = 0; offset < position.maxScrollExtent; offset += 400) {
    position.jumpTo(offset);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void resetView(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final state in ['populated', 'empty', 'loading']) {
        testWidgets(
            'Home ${width.toInt()}px ${scale * 100}% $state has no overflow',
            (tester) async {
          resetView(tester);
          final pending = Completer<http.Response>();
          await http.runWithClient(() async {
            await mountHome(tester, width: width, scale: scale);
            if (state != 'loading') await tester.pumpAndSettle();
            await scrollThroughHome(tester);
            expect(find.text('Make your\nnext move.'), findsOneWidget);
            expect(find.text('Hello, Alexandria Long Family Name'),
                findsOneWidget);
            final home =
                tester.widget<HomeDashboard>(find.byType(HomeDashboard));
            expect(home.isLoading, state == 'loading');
            if (state == 'empty') {
              expect(find.text('Your first move awaits'), findsOneWidget);
            }
            if (state == 'populated') {
              expect(find.byType(HomeRecentActivityCard), findsNWidgets(3));
            }
            if (state == 'loading') {
              expect(find.byType(KaripaProgress), findsNWidgets(2));
              pending.complete(http.Response(
                  jsonEncode({'success': true, 'activities': []}), 200));
              await tester.pumpAndSettle();
            }
          },
              () => MockClient((request) async => state == 'loading'
                  ? await pending.future
                  : http.Response(
                      jsonEncode({
                        'success': true,
                        'activities': state == 'populated' ? records : []
                      }),
                      200)));
        });
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'real screen binds totals and recent records with global $brightness theme',
        (tester) async {
      resetView(tester);
      await http.runWithClient(() async {
        await mountHome(tester, brightness: brightness);
        await tester.pumpAndSettle();
        final home = tester.widget<HomeDashboard>(find.byType(HomeDashboard));
        expect(home.distance, '17.0');
        expect(home.activityCount, '4');
        expect(home.activeTime, '1h 20m');
        expect(home.calories, '570');
        final cards = tester
            .widgetList<HomeRecentActivityCard>(
                find.byType(HomeRecentActivityCard))
            .toList();
        expect(cards.map((card) => card.activity),
            ['WALKING', 'CYCLING', 'JOGGING']);
        expect(cards.first.date, '9 Oct 2026');
        expect(cards.first.duration, '15:00');
        expect(
            cards.last.calories, '0'); // Preserves the existing null fallback.
        expect(Theme.of(tester.element(find.byType(HomeDashboard))).brightness,
            brightness);
        expect(
            tester
                .widget<MaterialApp>(find.byType(MaterialApp))
                .theme!
                .brightness,
            brightness);
      },
          () => MockClient((request) async {
                expect(request.method, 'GET');
                expect(request.url.path, '/api/activities');
                return http.Response(
                    jsonEncode({'success': true, 'activities': records}), 200);
              }));
    });
  }

  testWidgets(
      'guest keeps existing empty data flow without making authenticated requests',
      (tester) async {
    resetView(tester);
    var requests = 0;
    await http.runWithClient(() async {
      await mountHome(tester, guest: true, width: 320, scale: 2);
      await tester.pumpAndSettle();
      await scrollThroughHome(tester);
      expect(find.text('Hello, Guest'), findsOneWidget);
      expect(find.text('Your first move awaits'), findsOneWidget);
      expect(requests, 0);
    },
        () => MockClient((request) async {
              requests++;
              return http.Response('{}', 500);
            }));
  });

  testWidgets(
      'original destinations, arguments and refresh-on-return behavior are preserved',
      (tester) async {
    resetView(tester);
    final observer = RouteRecorder();
    var requests = 0;
    await http.runWithClient(() async {
      await mountHome(tester, observer: observer);
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.tap(find.text('Start activity'));
      await tester.pumpAndSettle();
      expect(observer.pushes.last.name, '/activity_selection');
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.tap(find.byTooltip('Open profile'));
      await tester.pumpAndSettle();
      expect(observer.pushes.last.name, '/profile');
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(observer.pushes.last.name, '/activity_history');
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(requests, 3);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(observer.pushes.last.name, '/profile');
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(requests, 4);
      final count = observer.pushes.length;
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(observer.pushes.length, count);
      await tester.ensureVisible(find.text('View all'));
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(observer.pushes.last.name, '/activity_history');
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(requests, 4); // View all did not refresh in the original screen.
      await tester.ensureVisible(find.byType(HomeRecentActivityCard).first);
      await tester.tap(find.byType(HomeRecentActivityCard).first);
      await tester.pumpAndSettle();
      expect(observer.pushes.last.name, '/activity_details');
      final args = observer.pushes.last.arguments! as Map<String, dynamic>;
      expect(args.keys, ['activity']);
      expect((args['activity'] as ActivityModel).id, 'walk');
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(requests, 4);
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(requests, 5);
    },
        () => MockClient((request) async {
              requests++;
              return http.Response(
                  jsonEncode({'success': true, 'activities': records}), 200);
            }));
  });

  testWidgets('fetch exception preserves the existing empty-state fallback',
      (tester) async {
    resetView(tester);
    await http.runWithClient(() async {
      await mountHome(tester);
      await tester.pumpAndSettle();
      expect(tester.widget<HomeDashboard>(find.byType(HomeDashboard)).isLoading,
          false);
      expect(find.text('Your first move awaits'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient(
            (request) async => throw Exception('Test-only network failure')));
  });

  testWidgets('landscape at enlarged text remains scrollable', (tester) async {
    resetView(tester);
    await http.runWithClient(() async {
      await mountHome(tester, width: 640, height: 360, scale: 2, guest: true);
      await tester.pumpAndSettle();
      await scrollThroughHome(tester);
    }, () => MockClient((request) async => http.Response('{}', 500)));
  });

  testWidgets('Home controls have labelled 48px targets and readable contrast',
      (tester) async {
    resetView(tester);
    final semantics = tester.ensureSemantics();
    try {
      await mountHome(tester, guest: true);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(tester.getSize(find.byTooltip('Open profile')).shortestSide,
          greaterThanOrEqualTo(AppSizes.touchTarget));
    } finally {
      semantics.dispose();
    }
  });
}
