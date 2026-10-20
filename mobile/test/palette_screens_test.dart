import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/theme/design_tokens.dart';
import 'package:karipa/services/auth_service.dart';
import 'package:karipa/services/theme_service.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/models/route_model.dart';
import 'package:karipa/screens/home_screen.dart';
import 'package:karipa/screens/login_screen.dart';
import 'package:karipa/screens/register_screen.dart';
import 'package:karipa/screens/otp_screen.dart';
import 'package:karipa/screens/profile_screen.dart';
import 'package:karipa/screens/activity_selection_screen.dart';
import 'package:karipa/screens/activity_history_screen.dart';
import 'package:karipa/screens/activity_setup_screen.dart';
import 'package:karipa/screens/route_planning_screen.dart';
import 'package:karipa/screens/ready_to_start_screen.dart';
import 'package:karipa/screens/recommended_routes_screen.dart';
import 'package:karipa/screens/activity_complete_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    var sdk = File(Platform.resolvedExecutable).parent;
    while (sdk.parent.path != sdk.path) {
      final icons = File(
          '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')
              ..addFont(
                  Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
            .load();
        break;
      }
      sdk = sdk.parent;
    }
    // Optional local fonts make review PNGs readable without network access.
    // Production continues to use its unchanged Manrope/Inter configuration.
    for (final pair in [('Manrope', 'arialbd.ttf'), ('Inter', 'arial.ttf')]) {
      final file = File('C:/Windows/Fonts/${pair.$2}');
      if (file.existsSync()) {
        final loader = FontLoader(pair.$1)
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        await loader.load();
      }
    }
  });
  final route = PathRoute.fromJson({
    'id': 'palette-review',
    'name': 'Review route',
    'activityType': 'walking',
    'distanceKm': 5.0,
    'durationSeconds': 3600,
  });
  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'otp': const OtpScreen(email: 'review@example.com'),
    'profile': const ProfileScreen(),
    'exit-dialog': const ProfileScreen(),
    'selection': const ActivitySelectionScreen(),
    'history-empty': const ActivityHistoryScreen(),
    'setup': const ActivitySetupScreen(activityType: 'walking'),
    'planning': const RoutePlanningScreen(activity: 'walking'),
    'ready': ReadyToStartScreen(route: route, activity: 'walking'),
    'recommendations-empty': const RecommendedRoutesScreen(
        routes: [], activity: 'walking', targetDistanceKm: 5),
    'recommendations': RecommendedRoutesScreen(
        routes: [route], activity: 'walking', targetDistanceKm: 5),
    'complete': ActivityCompleteScreen(
        activityType: 'walking',
        distanceKm: 5,
        durationSeconds: 3600,
        paceOrSpeed: '12:00',
        calories: 200,
        route: route,
        gpsPoints: const []),
  };
  test('white content, beige supporting surfaces, coral actions', () {
    final t = AppTheme.buildTheme(useGoogleFonts: false);
    expect(t.scaffoldBackgroundColor, KaripaPalette.white);
    expect(t.cardTheme.color, KaripaPalette.white);
    expect(t.inputDecorationTheme.fillColor, KaripaPalette.white);
    expect(t.dialogTheme.backgroundColor, KaripaPalette.white);
    expect(t.bottomNavigationBarTheme.backgroundColor, KaripaPalette.ivory);
    expect(t.drawerTheme.backgroundColor, KaripaPalette.ivory);
    expect(t.navigationRailTheme.backgroundColor, KaripaPalette.ivory);
    expect(t.colorScheme.primary, KaripaPalette.coral);
  });
  for (final width in [390.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} $width ${brightness.name}', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({'isGuest': true});
          final boundary = GlobalKey();
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthService()),
              ChangeNotifierProvider(create: (_) => ThemeService()),
              ChangeNotifierProvider(create: (_) => UnitPreferences()),
            ],
            child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.buildTheme(
                      brightness: brightness, useGoogleFonts: false),
                  home: entry.value,
                )),
          ));
          await tester.pumpAndSettle();
          if (entry.key == 'exit-dialog') {
            await tester.scrollUntilVisible(
              find.text('Exit Guest Mode'),
              400,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(find.text('Exit Guest Mode'));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          for (final element in find.byType(ElevatedButton).evaluate()) {
            final button = element.widget as ElevatedButton;
            final style = Theme.of(element)
                .elevatedButtonTheme
                .style!
                .merge(button.style);
            final fill = style.backgroundColor!.resolve({})!;
            final ink = style.foregroundColor!.resolve({})!;
            final values = [fill.computeLuminance(), ink.computeLuminance()]
              ..sort();
            expect((values.last + 0.05) / (values.first + 0.05),
                greaterThanOrEqualTo(4.5));
          }
          if (const bool.fromEnvironment('PALETTE_CAPTURE')) {
            await tester.runAsync(() async {
              final render = boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final directory = Directory('build/palette-review')
                ..createSync(recursive: true);
              File('${directory.path}/${entry.key}-${width.toInt()}-${brightness.name}.png')
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
}
