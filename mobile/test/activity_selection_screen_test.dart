import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/screens/activity_selection_screen.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/widgets/activity_selection_card.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    void Function(RouteSettings) onRoute,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: const ActivitySelectionScreen(),
        onGenerateRoute: (settings) {
          onRoute(settings);
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Recording destination')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Free Recording navigates directly without route-planning data',
      (tester) async {
    RouteSettings? requested;
    await mount(tester, (settings) => requested = settings);

    await tester.ensureVisible(find.text('Free recording'));
    await tester.tap(find.text('Free recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to free recording'));
    await tester.pumpAndSettle();

    expect(requested?.name, '/active_tracking');
    expect(requested?.arguments, {
      'activity': 'running',
      'recordingMode': 'free_recording',
    });
  });

  testWidgets('Plan a Route preserves the existing route-planning destination',
      (tester) async {
    RouteSettings? requested;
    await mount(tester, (settings) => requested = settings);

    await tester.tap(find.text('Continue to route planning'));
    await tester.pumpAndSettle();

    expect(requested?.name, '/route_planning');
    expect(requested?.arguments, {'activity': 'running'});
  });

  testWidgets('recording modes expose exclusive checked states and tap actions',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, (_) {});
    final free = find.bySemanticsLabel(
        'Free recording. Track freely without a planned route.');
    await tester.ensureVisible(find.text('Free recording'));
    expect(
        tester.getSemantics(free),
        matchesSemantics(
            label: 'Free recording. Track freely without a planned route.',
            hasCheckedState: true,
            isChecked: false,
            isInMutuallyExclusiveGroup: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true));
    await tester.tap(find.text('Free recording'));
    await tester.pumpAndSettle();
    expect(
        tester.getSemantics(free),
        matchesSemantics(
            label: 'Free recording. Track freely without a planned route.',
            hasCheckedState: true,
            isChecked: true,
            isInMutuallyExclusiveGroup: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true));
    await tester.ensureVisible(find.text('Plan a route'));
    expect(
        tester.getSemantics(find.bySemanticsLabel(
            'Plan a route. Generate a route around your target distance.')),
        matchesSemantics(
            label:
                'Plan a route. Generate a route around your target distance.',
            hasCheckedState: true,
            isChecked: false,
            isInMutuallyExclusiveGroup: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true));
    semantics.dispose();
  });

  for (final activity in ['Walking', 'Jogging', 'Running', 'Cycling']) {
    for (final free in [false, true]) {
      testWidgets(
          '$activity reaches ${free ? 'free recording' : 'planning'} and retains selection on return',
          (tester) async {
        final routes = <RouteSettings>[];
        await mount(tester, routes.add);
        await tester.tap(find.text(activity));
        if (free) {
          await tester.ensureVisible(find.text('Free recording'));
          await tester.tap(find.text('Free recording'));
        }
        await tester.pumpAndSettle();
        final cta = find.text(
            free ? 'Continue to free recording' : 'Continue to route planning');
        await tester.tap(cta);
        await tester.tap(cta,
            warnIfMissed: false); // Same-frame duplicate intent.
        await tester.pumpAndSettle();
        expect(routes.length, 1);
        expect(
            routes.single.name, free ? '/active_tracking' : '/route_planning');
        expect(routes.single.arguments, {
          'activity': activity.toLowerCase(),
          if (free) 'recordingMode': 'free_recording',
        });
        Navigator.pop(tester.element(find.text('Recording destination')));
        await tester.pumpAndSettle();
        final selected = tester
            .widgetList<ActivitySelectionCard>(
                find.byType(ActivitySelectionCard))
            .where((card) => card.selected);
        expect(selected.single.label, activity);
        expect(cta, findsOneWidget);
      });
    }
  }

  for (final width in [320.0, 360.0, 375.0, 390.0, 414.0, 430.0, 640.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
            'layout $width text $scale $brightness exposes every option above a safe CTA',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, width == 640 ? 360 : 740);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.buildTheme(
                brightness: brightness, useGoogleFonts: false),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 24, bottom: 34)),
                child: child!),
            home: const ActivitySelectionScreen(),
          ));
          await tester.pumpAndSettle();
          final walking =
              tester.getRect(find.byType(ActivitySelectionCard).at(0));
          final jogging =
              tester.getRect(find.byType(ActivitySelectionCard).at(1));
          expect(walking.top, jogging.top);
          expect(walking.height, jogging.height);
          for (final label in [
            'Walking',
            'Jogging',
            'Running',
            'Cycling',
            'Plan a route',
            'Free recording'
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.text('Free recording'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Free recording'));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.text('Free recording')).bottom,
              lessThan(tester.getRect(find.byType(FilledButton)).top));
          expect(find.text('Continue to free recording'), findsOneWidget);
          expect(find.text('Continue to route planning'), findsNothing);
          final semantics = tester.ensureSemantics();
          // A scrolled viewport clips semantics bounds for partially visible
          // tiles. Measure their full interactive surfaces instead.
          for (final surface
              in find.byType(ActivitySelectionSurface).evaluate()) {
            expect(tester.getSize(find.byWidget(surface.widget)).shortestSide,
                greaterThanOrEqualTo(48));
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('navigation failure shows feedback and permits retry',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(MaterialApp(
      home: const ActivitySelectionScreen(),
      onGenerateRoute: (_) {
        if (fail) throw StateError('Test navigation failure');
        return MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Recovered destination')));
      },
    ));
    await tester.tap(find.text('Continue to route planning'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unable to continue'));
    expect(find.text('Could not open the next screen. Please try again.'),
        findsOneWidget);
    fail = false;
    await tester.tap(find.text('Continue to route planning'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered destination'), findsOneWidget);
  });
}
