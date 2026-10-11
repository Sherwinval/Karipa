import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathcraft_mobile/theme/app_theme.dart';
import 'package:pathcraft_mobile/theme/design_tokens.dart';
import 'package:pathcraft_mobile/widgets/activity_selection_card.dart';
import 'package:pathcraft_mobile/widgets/karipa_button.dart';
import 'package:pathcraft_mobile/widgets/karipa_feedback.dart';
import 'package:pathcraft_mobile/widgets/metric_tile.dart';
import 'package:pathcraft_mobile/widgets/route_recommendation_card.dart';
import 'package:pathcraft_mobile/widgets/section_heading.dart';
import 'package:pathcraft_mobile/widgets/status_badge.dart';

double contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  return ((l1 > l2 ? l1 : l2) + 0.05) / ((l1 > l2 ? l2 : l1) + 0.05);
}

ThemeData testTheme(Brightness brightness) =>
    AppTheme.buildTheme(brightness: brightness, useGoogleFonts: false);

Future<void> showComponent(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  await tester.pumpWidget(MaterialApp(
    theme: testTheme(brightness),
    home: Builder(
        builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reduceMotion,
              ),
              child: Scaffold(
                  body: SafeArea(
                      child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.pageMargin(width)),
                child: child,
              ))),
            )),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in Brightness.values) {
    test('${brightness.name}: semantic pairs and control states have contrast',
        () {
      final theme = testTheme(brightness);
      final c = theme.colorScheme;
      final pairs = <(Color, Color)>[
        (c.primary, c.onPrimary),
        (c.primaryContainer, c.onPrimaryContainer),
        (c.secondary, c.onSecondary),
        (c.secondaryContainer, c.onSecondaryContainer),
        (c.tertiary, c.onTertiary),
        (c.tertiaryContainer, c.onTertiaryContainer),
        (c.surface, c.onSurface),
        (c.surfaceContainerLow, c.onSurface),
        (c.surface, c.onSurfaceVariant),
        (c.error, c.onError),
        (c.errorContainer, c.onErrorContainer),
        (c.inverseSurface, c.onInverseSurface),
        (c.primaryFixed, c.onPrimaryFixed),
        (c.primaryFixedDim, c.onPrimaryFixedVariant),
        (c.secondaryFixed, c.onSecondaryFixed),
        (c.secondaryFixedDim, c.onSecondaryFixedVariant),
        (c.tertiaryFixed, c.onTertiaryFixed),
        (c.tertiaryFixedDim, c.onTertiaryFixedVariant),
      ];
      for (final (fill, ink) in pairs) {
        expect(KaripaPalette.values, containsAll([fill, ink]));
        expect(contrast(fill, ink), greaterThanOrEqualTo(4.5));
      }
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!
      ]) {
        for (final states in [
          <WidgetState>{},
          {WidgetState.disabled},
          {WidgetState.focused}
        ]) {
          final fill = style.backgroundColor!.resolve(states)!;
          final ink = style.foregroundColor!.resolve(states)!;
          expect(contrast(fill, ink), greaterThanOrEqualTo(4.5));
          expect(style.minimumSize!.resolve(states)!.height,
              greaterThanOrEqualTo(48));
          expect(contrast(style.side!.resolve(states)!.color, c.surface),
              greaterThanOrEqualTo(3));
        }
      }
      final tokens = theme.extension<PathCraftColors>()!;
      expect(contrast(tokens.routeHighlight, tokens.routeCasing),
          greaterThanOrEqualTo(3));
      expect(contrast(tokens.recordedTrack, tokens.recordedTrackCasing),
          greaterThanOrEqualTo(3));
      expect(contrast(tokens.metricPanel, tokens.onMetricPanel),
          greaterThanOrEqualTo(4.5));
    });

    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets(
          '${brightness.name}: components fit ${width.toInt()}px at 200% text',
          (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final components = <Widget>[
          const SectionHeading(
              title: 'Make your next move',
              subtitle: 'Walking, jogging, running and cycling.'),
          KaripaButton(
              label: 'Choose your next activity',
              icon: Icons.arrow_forward,
              onPressed: () {}),
          KaripaButton.secondary(
              label: 'Explore route preferences', onPressed: () {}),
          const KaripaButton(
              label: 'Generating route', onPressed: null, isLoading: true),
          const MetricTile(
              label: 'Elapsed active time',
              value: '01:24:36',
              prominent: true,
              icon: Icons.timer_outlined),
          const MetricTile(
              label: 'Estimated remaining distance',
              value: '12.45',
              unit: 'km',
              icon: Icons.straighten),
          const StatusBadge(
              text: 'Estimated completion time unavailable',
              icon: Icons.info_outline),
          ActivitySelectionCard(
              label: 'Walking',
              description: 'Move at your own pace.',
              icon: Icons.directions_walk,
              selected: true,
              onTap: () {}),
          RouteRecommendationCard(
              title: 'Riverside exploration',
              distanceLabel: '5.25 km',
              estimatedDurationLabel: '45 min',
              suitabilityLabel: 'Preference match',
              explanation: 'Based on your selected distance and preferences.',
              recommended: true,
              mapPreview: const SizedBox(
                  height: 160,
                  child: Center(child: Text('Map preview fixture'))),
              onPressed: () {}),
          KaripaFeedback(
              title: 'Location unavailable',
              message: 'Check your device location permission.',
              kind: FeedbackKind.error,
              actionLabel: 'Try again',
              onAction: () {}),
          const KaripaFeedback(
              title: 'No activities yet',
              message: 'Your saved activities will appear here.',
              kind: FeedbackKind.empty),
          const KaripaProgress(label: 'Generating route options'),
          const KaripaProgress(label: 'Distance progress', value: 0.5),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child:
                    MetricTile(label: 'Distance', value: '12.45', unit: 'km')),
            SizedBox(width: AppSpacing.md),
            Expanded(
                child: MetricTile(label: 'Route type', value: 'Out & Back')),
          ]),
        ];
        for (final component in components) {
          await showComponent(tester, component,
              width: width, textScale: 2, brightness: brightness);
          expect(tester.takeException(), isNull,
              reason: '${component.runtimeType} overflowed');
        }
      });
    }
  }

  testWidgets('buttons forward callbacks and disable busy/null actions',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var primaryTaps = 0;
    var secondaryTaps = 0;
    await showComponent(
        tester,
        Column(children: [
          KaripaButton(label: 'Start', onPressed: () => primaryTaps++),
          KaripaButton.secondary(
              label: 'Back', onPressed: () => secondaryTaps++),
          KaripaButton(
              label: 'Saving', isLoading: true, onPressed: () => primaryTaps++),
          const KaripaButton(label: 'Unavailable', onPressed: null),
        ]));
    await tester.tap(find.text('Start'));
    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Saving'));
    await tester.tap(find.text('Unavailable'));
    expect(primaryTaps, 1);
    expect(secondaryTaps, 1);
    expect(tester.getSize(find.widgetWithText(FilledButton, 'Start')).height,
        greaterThanOrEqualTo(56));
  });

  testWidgets('all four activity cards expose selection and forward taps',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      var taps = 0;
      for (final label in ['Walking', 'Jogging', 'Running', 'Cycling']) {
        await showComponent(
            tester,
            ActivitySelectionCard(
                label: label,
                icon: Icons.directions_walk,
                selected: true,
                onTap: () => taps++));
        expect(find.bySemanticsLabel(label), findsOneWidget);
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(
            node,
            matchesSemantics(
                label: label,
                isButton: true,
                isSelected: true,
                hasSelectedState: true,
                hasEnabledState: true,
                isEnabled: true,
                hasTapAction: true,
                hasFocusAction: true,
                isFocusable: true));
        await tester.tap(find.text(label));
      }
      expect(taps, 4);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('route and feedback actions forward the supplied callbacks',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var routeTaps = 0;
    var retryTaps = 0;
    await showComponent(
        tester,
        RouteRecommendationCard(
            title: 'Route',
            distanceLabel: '5 km',
            estimatedDurationLabel: '30 min',
            suitabilityLabel: 'Moderate',
            explanation: 'Preference match only.',
            onPressed: () => routeTaps++));
    await tester.tap(find.text('View route details'));
    await showComponent(
        tester,
        KaripaFeedback(
            title: 'Try again',
            message: 'Request unavailable.',
            actionLabel: 'Retry',
            onAction: () => retryTaps++));
    await tester.tap(find.text('Retry'));
    expect(routeTaps, 1);
    expect(retryTaps, 1);
  });

  testWidgets('metric announces label/value/unit once without live updates',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await showComponent(tester,
          const MetricTile(label: 'Distance', value: '5.25', unit: 'km'));
      expect(find.bySemanticsLabel('Distance: 5.25 km'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Distance: 5.25 km')),
          matchesSemantics(label: 'Distance: 5.25 km'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'loading respects reduced motion and determinate values remain real',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showComponent(tester, const KaripaProgress(label: 'Loading routes'),
        reduceMotion: true);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
    await showComponent(
        tester, const KaripaProgress(label: 'Distance progress', value: 0.4),
        reduceMotion: true);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        0.4);
  });

  testWidgets('primary action passes target-size and label guidelines',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await showComponent(
          tester, KaripaButton(label: 'Choose activity', onPressed: () {}));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
