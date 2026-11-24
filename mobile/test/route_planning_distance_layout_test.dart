import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/screens/route_planning_screen.dart';
import 'package:karipa/theme/design_tokens.dart';

void main() {
  testWidgets('distance slider and presets remain accessible on small screens',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: RoutePlanningScreen(activity: 'walking'),
      ),
    );
    await tester.pumpAndSettle();

    final sliderFinder = find.byType(Slider);
    final slider = tester.widget<Slider>(sliderFinder);
    expect(slider.min, 3.0);
    expect(slider.max, 30.0);
    expect(slider.divisions, 54);
    expect(slider.value, 3.0);
    expect(find.text('3.0 km'), findsOneWidget);
    expect(slider.semanticFormatterCallback?.call(3.0), '3.0 kilometers');
    expect(slider.semanticFormatterCallback?.call(30.0), '30.0 kilometers');
    final sliderSemantics = tester.getSemantics(sliderFinder);
    expect(sliderSemantics.getSemanticsData().label, 'Target distance');
    expect(find.bySemanticsLabel('Selected distance'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Selected distance'))
          .getSemanticsData()
          .value,
      '3.0 kilometers',
    );

    const visibleNarrowScreenPresetsKm = [3, 15, 30];
    final presetRects = <Rect>[];
    final layoutRect = tester.getRect(
      find
          .ancestor(of: sliderFinder, matching: find.byType(LayoutBuilder))
          .first,
    );
    for (final distance in visibleNarrowScreenPresetsKm) {
      final preset = find.text('$distance km');
      expect(preset, findsOneWidget);
      final rect = tester.getRect(preset);
      presetRects.add(rect);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(tester.widget<Text>(preset).maxLines, 1);
      expect(
        tester.getSemantics(preset).getSemanticsData().flagsCollection.isButton,
        isFalse,
      );
    }
    for (final hiddenDistance in [5, 10, 20, 25]) {
      expect(find.text('$hiddenDistance km'), findsNothing);
    }
    expect(
      presetRects[0].center.dy,
      closeTo(presetRects[1].center.dy, 0.1),
    );
    expect(
      presetRects[1].center.dy,
      closeTo(presetRects[2].center.dy, 0.1),
    );
    for (var first = 0; first < presetRects.length; first++) {
      for (var second = first + 1; second < presetRects.length; second++) {
        expect(
          presetRects[first]
              .inflate(4)
              .overlaps(presetRects[second].inflate(4)),
          isFalse,
        );
      }
    }

    await tester.tapAt(
      tester.getCenter(find.text('15 km')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(sliderFinder).value, 3.0);

    final controlTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(controlTheme.data.activeTrackColor, KaripaPalette.coral);
    expect(controlTheme.data.thumbColor, KaripaPalette.coral);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    final maximumMarkerWidth =
        presetRects.map((rect) => rect.width).reduce((first, second) {
      return math.max(first, second).toDouble();
    });
    final sliderInset = math.max(24.0, maximumMarkerWidth / 2);
    final expectedLabelCenters = visibleNarrowScreenPresetsKm.map((distance) {
      final normalizedValue = (distance - 3) / 27;
      return layoutRect.left +
          sliderInset +
          3 +
          normalizedValue * (layoutRect.width - 2 * sliderInset - 6);
    }).toList(growable: false);
    for (var index = 0; index < presetRects.length; index++) {
      expect(presetRects[index].center.dx,
          closeTo(expectedLabelCenters[index], 1));
    }

    await tester.tapAt(tester.getCenter(sliderFinder));
    await tester.pumpAndSettle();
    final tappedValue = tester.widget<Slider>(sliderFinder).value;
    expect(tappedValue, greaterThan(10.0));
    expect(
      (tappedValue - 3.0) / 0.5,
      closeTo(((tappedValue - 3.0) / 0.5).roundToDouble(), 0.00001),
    );

    await tester.drag(sliderFinder, const Offset(1000, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(sliderFinder).value, 30.0);
    expect(find.text('30.0 km'), findsOneWidget);
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Generate Routes'));
    await tester.pumpAndSettle();
    final actionTop = tester
        .getTopLeft(find.widgetWithText(ElevatedButton, 'Generate Routes'))
        .dy;
    final preferenceBottom =
        tester.getBottomLeft(find.text('Prioritize Sidewalks & Trails')).dy;
    expect(actionTop - preferenceBottom, greaterThanOrEqualTo(20));
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: true);

  testWidgets('slider snaps to stops and gives one haptic per snap',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final hapticCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: RoutePlanningScreen(activity: 'walking'),
      ),
    );
    await tester.pumpAndSettle();

    final sliderFinder = find.byType(Slider);
    final sliderRect = tester.getRect(sliderFinder);
    final layoutRect = tester.getRect(
      find
          .ancestor(of: sliderFinder, matching: find.byType(LayoutBuilder))
          .first,
    );
    const targetValue = 14.5;
    const targetPosition = (targetValue - 3) / 27;
    final targetX =
        layoutRect.left + 24 + 3 + targetPosition * (layoutRect.width - 48 - 6);

    await tester.tapAt(Offset(targetX, sliderRect.center.dy));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.widget<Slider>(sliderFinder).value, 15.0);
    expect(hapticCalls, hasLength(1));
    expect(
      hapticCalls.single.arguments,
      'HapticFeedbackType.selectionClick',
    );
    final selectedMarker = find.text('15 km');
    final selectedMarkerScale = find.ancestor(
      of: selectedMarker,
      matching: find.byType(AnimatedScale),
    );
    expect(
      tester.widget<AnimatedScale>(selectedMarkerScale).scale,
      1.12,
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(selectedMarkerScale).scale, 1.0);

    final nextStepX =
        layoutRect.left + 24 + 3 + (12.5 / 27) * (layoutRect.width - 48 - 6);
    await tester.tapAt(
      Offset(nextStepX, sliderRect.center.dy),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(sliderFinder).value, 15.5);
    expect(hapticCalls, hasLength(1));
  });

  testWidgets('custom distances validate and override the standard slider',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: RoutePlanningScreen(activity: 'walking'),
      ),
    );
    await tester.pumpAndSettle();

    final fieldFinder = find.byType(TextField);
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.decoration?.labelText, 'Custom distance (km)');
    expect(field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true));
    expect(
      find.text(
          'Leave blank for slider. Custom: 30.5 to 100 km in 0.5 km steps.'),
      findsOneWidget,
    );
    final sliderFinder = find.byType(Slider);
    final buttonFinder = find.widgetWithText(ElevatedButton, 'Generate Routes');

    await tester.enterText(fieldFinder, '30');
    await tester.pumpAndSettle();
    expect(find.text('Enter a distance greater than 30 km.'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFinder).onChanged, isNull);
    expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNull);

    await tester.enterText(fieldFinder, 'not a number');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid number of kilometers.'), findsOneWidget);

    await tester.enterText(fieldFinder, '30.25');
    await tester.pumpAndSettle();
    expect(
      find.text('Use 0.5 km increments, such as 30.5 km.'),
      findsOneWidget,
    );

    await tester.enterText(fieldFinder, '101');
    await tester.pumpAndSettle();
    expect(find.text('Maximum custom distance is 100 km.'), findsOneWidget);

    await tester.enterText(fieldFinder, '42.5');
    await tester.pumpAndSettle();
    expect(find.text('42.5 km'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFinder).value, 30.0);
    expect(tester.widget<Slider>(sliderFinder).onChanged, isNull);
    expect(
        find.text('Custom target active; standard slider covers 3 to 30 km.'),
        findsOneWidget);
    expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Selected distance'))
          .getSemanticsData()
          .value,
      '42.5 kilometers, custom target active',
    );

    await tester.enterText(fieldFinder, '100');
    await tester.pumpAndSettle();
    expect(find.text('100.0 km'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Selected distance'))
          .getSemanticsData()
          .value,
      '100.0 kilometers, custom target active',
    );

    await tester.enterText(fieldFinder, '');
    await tester.pumpAndSettle();
    expect(find.text('3.0 km'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFinder).onChanged, isNotNull);
  }, semanticsEnabled: true);
}
