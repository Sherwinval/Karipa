import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karipa/main.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/theme_service.dart';
import 'package:karipa/widgets/karipa_logo.dart';

void main() {
  testWidgets('Karipa app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
        ],
        child: const KaripaApp(),
      ),
    );

    expect(find.byType(KaripaLogo), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    // Dispose before draining the existing splash delay to avoid navigation.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
