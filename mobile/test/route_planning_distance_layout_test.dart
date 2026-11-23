import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/screens/route_planning_screen.dart';

void main() {
  testWidgets(
      'distance slider uses accessible kilometer steps on small screens',
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
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('30 km'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(slider.semanticFormatterCallback?.call(3.0), '3.0 km');
    expect(slider.semanticFormatterCallback?.call(30.0), '30.0 km');

    await tester.tapAt(tester.getCenter(sliderFinder));
    await tester.pumpAndSettle();
    final tappedValue = tester.widget<Slider>(sliderFinder).value;
    expect(tappedValue, greaterThan(3.0));
    expect(
      (tappedValue - 3.0) / 0.5,
      closeTo(((tappedValue - 3.0) / 0.5).roundToDouble(), 0.00001),
    );

    await tester.drag(sliderFinder, const Offset(1000, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(sliderFinder).value, 30.0);
    expect(find.text('30.0 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
