import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/screens/profile_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/theme/app_theme.dart';

import 'package:karipa/services/theme_service.dart';

void main() {
  testWidgets('displays stored height and weight measurements from backend',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userId': '1',
      'name': 'Sherwin',
    });

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/profile')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'profile': {
              'heightCm': 175.0,
              'weightKg': 68.5,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => UnitPreferences()),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(
                brightness: Brightness.dark, useGoogleFonts: false),
            home: const ProfileScreen(),
          ),
        ),
      );

      // Settle loading and async getProfile
      await tester.pumpAndSettle();

      // Find the Height and Weight TextFormFields
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      final heightField = tester.widget<TextFormField>(textFields.first);
      final weightField = tester.widget<TextFormField>(textFields.last);

      // Verify stored values are displayed
      expect(heightField.controller?.text, '175');
      expect(weightField.controller?.text, '68.5');

      // Verify that Edit button is present
      expect(find.text('Edit'), findsOneWidget);

      // Switch to Imperial
      await tester
          .element(find.byType(ProfileScreen))
          .read<UnitPreferences>()
          .setSystem(UnitSystem.imperial);
      await tester.pumpAndSettle();

      // Verify values are converted according to imperial unit system (ft and lb)
      // 175 cm / 30.48 = ~5.74 ft
      // 68.5 kg * 2.2046226218 = ~151.0 lb
      final heightFieldImperial =
          tester.widget<TextFormField>(textFields.first);
      final weightFieldImperial =
          tester.widget<TextFormField>(textFields.last);

      expect(heightFieldImperial.controller?.text, '5.74');
      expect(weightFieldImperial.controller?.text, '151');
    }, () => mockClient);
  });
}
