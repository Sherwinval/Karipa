import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pathcraft_mobile/main.dart';
import 'package:pathcraft_mobile/services/auth_service.dart';

void main() {
  testWidgets('PathCraft app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const PathCraftApp(),
      ),
    );

    expect(find.text('PathCraft'), findsOneWidget);
  });
}
