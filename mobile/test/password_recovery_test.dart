import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/screens/password_recovery_screen.dart';
import 'package:karipa/screens/login_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/theme/app_theme.dart';

class RecoveryAuth extends AuthService {
  final calls = <String>[];
  final payloads = <Map<String, String>>[];
  Map<String, dynamic>? failure;
  Completer<Map<String, dynamic>>? pending;
  int expiresIn = 600;
  int resendAfter = 60;
  int resetExpiresIn = 300;

  @override
  Future<Map<String, dynamic>> recoverPassword(
      String operation, Map<String, String> payload) async {
    calls.add(operation);
    payloads.add(payload);
    if (pending != null) return pending!.future;
    if (failure != null) return failure!;
    return switch (operation) {
      'request' || 'resend' => {
          'success': true,
          'challengeId': 'test-challenge',
          'expiresIn': expiresIn,
          'resendAfter': resendAfter
        },
      'verify' => {
          'success': true,
          'authorization': 'test-authorization',
          'expiresIn': resetExpiresIn
        },
      _ => {'success': true},
    };
  }
}

Future<RecoveryAuth> mount(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
  Brightness brightness = Brightness.light,
  double keyboard = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final auth = RecoveryAuth();
  await auth.initialized;
  await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.buildTheme(brightness: brightness, useGoogleFonts: false),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: child!),
      home: const PasswordRecoveryScreen(),
      routes: {'/login': (_) => const LoginScreen()},
    ),
  ));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> tap(WidgetTester tester, String text) async {
  // Let the focused field finish revealing itself before scrolling to an action.
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> request(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('recovery-email')), 'alex@example.com');
  await tap(tester, 'Send reset code');
}

void main() {
  testWidgets('expired code and reset session reject keyboard submission',
      (tester) async {
    final auth = await mount(tester);
    auth.expiresIn = 0;
    auth.resendAfter = 0;
    await request(tester);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-code')), '123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(auth.calls, ['request']);
    expect(find.textContaining('This code has expired'), findsOneWidget);
    auth.expiresIn = 600;
    auth.resetExpiresIn = 0;
    await tap(tester, 'Resend code');
    expect(find.textContaining('A replacement code was sent'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('recovery-code')))
            .controller!
            .text,
        isEmpty);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-code')), '123456');
    await tap(tester, 'Verify code');
    await tester.enterText(
        find.byKey(const ValueKey('New password')), 'new-password');
    await tester.enterText(
        find.byKey(const ValueKey('Confirm new password')), 'new-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(auth.calls, ['request', 'resend', 'verify']);
    expect(
        find.textContaining('Your reset session has expired'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('request cooldown also blocks keyboard submissions',
      (tester) async {
    final auth = await mount(tester);
    auth.failure = {
      'success': false,
      'message': 'Please wait.',
      'retryAfter': 60
    };
    await request(tester);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-email')), 'alex@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(auth.calls, ['request']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('validates email before making a request', (tester) async {
    final auth = await mount(tester);
    await tap(tester, 'Send reset code');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('walks email, code, password validation, success, and sign-in',
      (tester) async {
    final auth = await mount(tester);
    await request(tester);
    expect(find.textContaining('a•••@example.com'), findsOneWidget);
    expect(find.textContaining('alex@example.com'), findsNothing);
    expect(find.textContaining('Code expires in'), findsOneWidget);
    final resend = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Resend code in 60 seconds'));
    expect(resend.onPressed, isNull);
    await tap(tester, 'Verify code');
    expect(find.text('Enter all six digits.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-code')), '12ab3456');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('recovery-code')))
            .controller!
            .text,
        '123456');
    await tap(tester, 'Verify code');
    expect(find.text('Create a new password'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('New password')), 'new-password');
    await tester.enterText(
        find.byKey(const ValueKey('Confirm new password')), 'different');
    await tap(tester, 'Reset password');
    expect(find.text('Passwords do not match.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('Confirm new password')), 'new-password');
    await tap(tester, 'Reset password');
    expect(find.text('Password updated'), findsOneWidget);
    expect(auth.payloads.last, {
      'challengeId': 'test-challenge',
      'authorization': 'test-authorization',
      'password': 'new-password'
    });
    await tap(tester, 'Back to sign in');
    expect(find.text('Welcome to Karipa'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Register now'), findsOneWidget);
  });

  testWidgets(
      'shows server failures and prevents duplicate requests while loading',
      (tester) async {
    final auth = await mount(tester);
    auth.pending = Completer();
    await tester.enterText(
        find.byKey(const ValueKey('recovery-email')), 'alex@example.com');
    await tap(tester, 'Send reset code');
    expect(find.text('Sending code…'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('recovery-email')))
            .enabled,
        false);
    auth.pending!.complete(
        {'success': false, 'message': 'Email delivery is unavailable.'});
    await tester.pumpAndSettle();
    expect(find.text('Email delivery is unavailable.'), findsOneWidget);
    expect(auth.calls.length, 1);
    expect(find.text('Send reset code'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(800, 1000)
    ]) {
      testWidgets(
          'all recovery stages fit $brightness $size with enlarged text and keyboard',
          (tester) async {
        final auth = await mount(tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
            keyboard: size.height < 400 ? 120 : 240);
        await request(tester);
        expect(tester.takeException(), isNull);
        await tester.enterText(
            find.byKey(const ValueKey('recovery-code')), '123456');
        await tap(tester, 'Verify code');
        expect(tester.takeException(), isNull);
        await tester.enterText(
            find.byKey(const ValueKey('New password')), 'new-password');
        await tester.enterText(
            find.byKey(const ValueKey('Confirm new password')), 'new-password');
        await tap(tester, 'Reset password');
        expect(tester.takeException(), isNull);
        expect(find.text('Password updated'), findsOneWidget);
        expect(auth.calls, ['request', 'verify', 'reset']);
        await tester.pumpWidget(const SizedBox()); // Dispose countdown timers.
      });
    }
  }
}
