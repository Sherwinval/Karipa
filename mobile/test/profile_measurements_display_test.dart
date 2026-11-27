import 'dart:convert';
import 'dart:async';
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
  for (final (width, height, scale, guest, brightness) in [
    (320.0, 640.0, 2.0, false, Brightness.light),
    (360.0, 740.0, 1.0, true, Brightness.dark),
    (390.0, 844.0, 1.0, false, Brightness.light),
    (430.0, 800.0, 1.5, false, Brightness.dark),
    (640.0, 360.0, 2.0, true, Brightness.light),
  ]) {
    testWidgets('Profile summary fits $width at $scale, guest $guest',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, height);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      await _profileFixture(tester,
          guest: guest, scale: scale, brightness: brightness, run: () async {
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Not set'), findsNWidgets(2));
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text(guest ? 'Guest account' : 'Signed in'),
            guest ? findsOneWidget : findsNWidgets(2));
        await tester.ensureVisible(find.text('How measurements are used'));
        await tester.tap(find.text('How measurements are used'));
        await tester.pumpAndSettle();
        expect(
            find.textContaining('adviser review is pending'), findsOneWidget);
        await tester.ensureVisible(find.text('Imperial'));
        await tester.tap(find.text('Imperial'));
        await tester.pumpAndSettle();
        expect(find.text('mi · ft · lb'), findsOneWidget);
        await tester
            .ensureVisible(find.text(guest ? 'Exit Guest Mode' : 'Sign Out'));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets(
      'measurement validation, drafts, save failure, save and clear stay intact',
      (tester) async {
    var patchCount = 0;
    var failSave = true;
    final saving = Completer<http.Response>();
    await _profileFixture(tester, patch: (request) async {
      patchCount++;
      if (failSave) {
        return http.Response('{"message":"Unable to save measurements"}', 500);
      }
      if (patchCount == 2) return saving.future;
      return http.Response(
          '{"success":true,"profile":{"heightCm":null,"weightKg":null}}', 200);
    }, run: () async {
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '-1');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a positive value in cm.'), findsOneWidget);
      expect(patchCount, 0);
      await tester.enterText(find.byType(TextFormField).first, '180');
      await tester.enterText(find.byType(TextFormField).last, '70');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(patchCount, 1);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '180');
      failSave = false;
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .enabled,
          false);
      saving.complete(http.Response(
          '{"success":true,"profile":{"heightCm":180,"weightKg":70}}', 200));
      await tester.pumpAndSettle();
      expect(find.text('180 cm'), findsOneWidget);
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '160');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('180 cm'), findsOneWidget);
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear values'));
      await tester.tap(find.text('Clear values'));
      await tester.pumpAndSettle();
      expect(patchCount, 3);
      expect(find.text('Not set'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('loading failure exposes Retry and recovers', (tester) async {
    var calls = 0;
    final pending = Completer<http.Response>();
    await _profileFixture(tester, settle: false, get: () async {
      calls++;
      return calls == 1
          ? await pending.future
          : http.Response('{"success":true,"profile":{}}', 200);
    }, run: () async {
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending
          .complete(http.Response('{"message":"Could not load profile"}', 500));
      await tester.pumpAndSettle();
      final retry = find.text('Retry loading measurements');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Not set'), findsNWidgets(2));
    });
  });

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
      expect(find.text('180 cm'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

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

      await tester.tap(find.text('Edit name'));
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

      expect(find.text('175 cm'), findsOneWidget);
      expect(find.text('68.5 kg'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      final heightField = tester.widget<TextFormField>(textFields.first);
      final weightField = tester.widget<TextFormField>(textFields.last);

      // Verify stored values are displayed
      expect(heightField.controller?.text, '175');
      expect(weightField.controller?.text, '68.5');

      expect(find.text('Cancel'), findsOneWidget);

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

Future<void> _profileFixture(
  WidgetTester tester, {
  bool guest = false,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool settle = true,
  Future<http.Response> Function()? get,
  Future<http.Response> Function(http.Request)? patch,
  required Future<void> Function() run,
}) async {
  SharedPreferences.setMockInitialValues(guest
      ? {'isGuest': true}
      : {
          'token': 'test-token',
          'userId': 'fixture',
          'name': 'Alexandria A Very Long Family Name',
        });
  await http.runWithClient(() async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => UnitPreferences()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(
              brightness: brightness, useGoogleFonts: false),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!),
          home: const ProfileScreen(),
        )));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
    try {
      await run();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  },
      () => MockClient((request) async {
            if (request.method == 'PATCH' && patch != null) {
              return patch(request);
            }
            if (get != null) return get();
            return http.Response('{"success":true,"profile":{}}', 200);
          }));
}
