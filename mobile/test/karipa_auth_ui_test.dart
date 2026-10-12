import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathcraft_mobile/screens/login_screen.dart';
import 'package:pathcraft_mobile/screens/register_screen.dart';
import 'package:pathcraft_mobile/screens/otp_screen.dart';
import 'package:pathcraft_mobile/services/auth_service.dart';
import 'package:pathcraft_mobile/theme/app_theme.dart';
import 'package:pathcraft_mobile/widgets/karipa_logo.dart';

Future<void> mount(WidgetTester tester, Widget screen,
    {double width = 320,
    double scale = 2,
    Brightness brightness = Brightness.light}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AuthService(),
    child: MaterialApp(
      theme: AppTheme.buildTheme(brightness: brightness, useGoogleFonts: false),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: const EdgeInsets.only(bottom: 240),
        ),
        child: child!,
      ),
      home: screen,
      routes: {'/register': (_) => const RegisterScreen()},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'registration': const RegisterScreen(),
    'otp': const OtpScreen(email: 'alex.long.email@example.com'),
  };
  for (final entry in screens.entries) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 412.0]) {
        testWidgets(
            '${entry.key} $brightness $width enlarged text and keyboard',
            (tester) async {
          await mount(tester, entry.value,
              width: width, brightness: brightness);
          expect(find.byType(KaripaLogo), findsOneWidget);
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          for (double offset = 0;
              offset < position.maxScrollExtent;
              offset += 150) {
            position.jumpTo(offset);
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
      'login retains validation, visibility toggle and registration route',
      (tester) async {
    await mount(tester, const LoginScreen(), width: 412, scale: 1);
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    final password = find.byType(TextFormField).last;
    expect(tester.widget<TextFormField>(password).controller, isNotNull);
    await tester.ensureVisible(find.byTooltip('Show or hide password'));
    await tester.tap(find.byTooltip('Show or hide password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        false);
    await tester.ensureVisible(find.text('Register now'));
    await tester.tap(find.text('Register now'));
    await tester.pumpAndSettle();
    expect(find.text('Join Karipa'), findsOneWidget);
  });
  testWidgets('registration retains required-field validation', (tester) async {
    await mount(tester, const RegisterScreen(), width: 412, scale: 1);
    await tester.ensureVisible(find.text('Register'));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
  });
  testWidgets('OTP retains invalid-code feedback', (tester) async {
    await mount(tester, const OtpScreen(email: 'alex@example.com'),
        width: 412, scale: 1);
    await tester.ensureVisible(find.text('Verify'));
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(
        find.text('Please enter a 6-digit verification code.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
