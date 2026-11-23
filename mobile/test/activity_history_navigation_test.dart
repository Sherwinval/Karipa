import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/screens/activity_history_screen.dart';
import 'package:karipa/services/unit_preferences.dart';

void main() {
  testWidgets('activity history back button returns to home', (tester) async {
    SharedPreferences.setMockInitialValues({'isGuest': true});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UnitPreferences(),
        child: MaterialApp(
          initialRoute: '/activity_history',
          routes: {
            '/activity_history': (_) => const ActivityHistoryScreen(),
            '/home': (_) => const Scaffold(body: Text('Home Page')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Home Page'), findsOneWidget);
    expect(find.text('Activity History'), findsNothing);
  });
}
