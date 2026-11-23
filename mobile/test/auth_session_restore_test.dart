import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karipa/screens/splash_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('restores a saved login before routing from the splash screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'saved-jwt',
      'userId': 'user-123',
      'name': 'Karipa User',
      'isGuest': false,
    });

    final auth = AuthService();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: const SplashScreen(),
          routes: {
            '/home': (_) => const Scaffold(body: Text('Home screen')),
            '/login': (_) => const Scaffold(body: Text('Login screen')),
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isTrue);
    expect(auth.token, 'saved-jwt');
    expect(auth.userId, 'user-123');
    expect(auth.name, 'Karipa User');
    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Login screen'), findsNothing);
  });
}
