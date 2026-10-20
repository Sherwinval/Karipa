import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/screens/login_screen.dart';
import 'package:karipa/screens/register_screen.dart';
import 'package:karipa/screens/otp_screen.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/widgets/karipa_logo.dart';

Future<void> mount(WidgetTester tester, Widget screen,
    {double width = 320,
    double scale = 2,
    Brightness brightness = Brightness.light}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthService()),
      ChangeNotifierProvider(create: (_) => UnitPreferences()),
    ],
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
  testWidgets('registration measurements are optional and use selected units',
      (tester) async {
    await mount(tester, const RegisterScreen(), width: 412, scale: 1);
    expect(find.text('Optional Measurements'), findsOneWidget);
    expect(find.text('Height (cm)'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
    await tester.ensureVisible(find.text('Register'));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid number in cm.'), findsNothing);
    expect(find.text('Enter a valid number in kg.'), findsNothing);
    await tester
        .element(find.byType(RegisterScreen))
        .read<UnitPreferences>()
        .setSystem(UnitSystem.imperial);
    await tester.pumpAndSettle();
    expect(find.text('Height (ft)'), findsOneWidget);
    expect(find.text('Weight (lb)'), findsOneWidget);
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
