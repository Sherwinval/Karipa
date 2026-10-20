import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/screens/activity_selection_screen.dart';

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

    await tester.tap(find.text('Start Free Recording'));
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

    await tester.tap(find.text('Continue to Route Planning'));
    await tester.pumpAndSettle();

    expect(requested?.name, '/route_planning');
    expect(requested?.arguments, {'activity': 'running'});
  });
}
