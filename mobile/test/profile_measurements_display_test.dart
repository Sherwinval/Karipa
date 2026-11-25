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
  testWidgets('refreshes profile changes from another device automatically',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'sync-test-token',
      'userId': '2',
      'name': 'Sherwin',
    });

    var profileRequests = 0;
    String? sentEtag;
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/profile') &&
          request.method == 'GET') {
        profileRequests++;
        if (profileRequests == 1) {
          return http.Response(
            jsonEncode({
              'success': true,
              'profile': {
                'name': 'Sherwin',
                'heightCm': 170,
                'weightKg': 65,
                'photoData': null,
              },
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'etag': '"profile-v1"',
            },
          );
        }
        sentEtag = request.headers['if-none-match'];
        return http.Response(
          jsonEncode({
            'success': true,
            'profile': {
              'name': 'Updated Runner',
              'heightCm': 180,
              'weightKg': 70,
              'photoData': null,
            },
          }),
          200,
          headers: {
            'content-type': 'application/json',
            'etag': '"profile-v2"',
          },
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
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final authService =
          tester.element(find.byType(ProfileScreen)).read<AuthService>();
      final preferences = await SharedPreferences.getInstance();
      expect(profileRequests, 2);
      expect(sentEtag, '"profile-v1"');
      expect(find.text('Updated Runner'), findsOneWidget);
      expect(authService.name, 'Updated Runner');
      expect(preferences.getString('name'), 'Updated Runner');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        '180',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }, () => mockClient);
  });

  testWidgets('saves profile name changes to the backend and local account',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userId': '1',
      'name': 'Sherwin',
    });

    Map<String, dynamic>? savedRequest;
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/profile') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'profile': {'name': 'Sherwin', 'heightCm': null, 'weightKg': null},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/auth/profile') &&
          request.method == 'PATCH') {
        savedRequest = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'profile': {
              'name': savedRequest!['name'],
              'heightCm': null,
              'weightKg': null,
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
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit profile name'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Taylor Runner',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final authService =
          tester.element(find.byType(ProfileScreen)).read<AuthService>();
      final preferences = await SharedPreferences.getInstance();
      expect(savedRequest, {'name': 'Taylor Runner'});
      expect(authService.name, 'Taylor Runner');
      expect(preferences.getString('name'), 'Taylor Runner');
    }, () => mockClient);
  });

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
              'photoData':
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/0y8AAAAASUVORK5CYII=',
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

      expect(
        find.byWidgetPredicate((widget) {
          if (widget is! Container || widget.decoration is! BoxDecoration) {
            return false;
          }
          return (widget.decoration! as BoxDecoration).image?.image
              is MemoryImage;
        }),
        findsOneWidget,
      );

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
      final weightFieldImperial = tester.widget<TextFormField>(textFields.last);

      expect(heightFieldImperial.controller?.text, '5.74');
      expect(weightFieldImperial.controller?.text, '151');
    }, () => mockClient);
  });
}
