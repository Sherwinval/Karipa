import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show BuiltInMapCachingProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karipa/screens/active_tracking_screen.dart';
import 'package:karipa/services/unit_preferences.dart';
import 'package:karipa/theme/app_theme.dart';
import 'package:karipa/widgets/route_map_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _location = MethodChannel('flutter.baseflow.com/geolocator');
const _locationUpdates =
    EventChannel('flutter.baseflow.com/geolocator_updates');
final _testTile = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aEOQAAAAASUVORK5CYII=');

void main() {
  testWidgets(
      'free recording waits for Start before timers, permissions or GPS begin',
      (tester) async {
    await _withRecording(tester, autoStart: false, run: (context) async {
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(context.permissionChecks, 0);
      expect(context.streamStarts, 0);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Finish & Review'))
              .onPressed,
          isNull);
      final state = tester.state(find.byType(ActiveTrackingScreen))
          as WidgetsBindingObserver;
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('00:00', findRichText: true), findsOneWidget);
      expect(context.permissionChecks, 0);

      await _tapVisible(tester, find.text('Start'));
      expect(find.text('Pause'), findsOneWidget);
      expect(context.streamStarts, 1);
      expect(context.permissionChecks, greaterThan(0));
      await _tapVisible(tester, find.text('Pause'));
      expect(find.text('Resume'), findsOneWidget);
      await _tapVisible(tester, find.text('Resume'));
      expect(find.text('Pause'), findsOneWidget);
      expect(context.streamStarts, 2);
    });
  });

  testWidgets('planned route recording still starts on entry', (tester) async {
    await _withRecording(tester, recordingMode: 'plan_route',
        run: (context) async {
      expect(find.text('Start'), findsNothing);
      expect(find.text('Pause'), findsOneWidget);
      expect(context.streamStarts, 1);
    });
  });

  late BuiltInMapCachingProvider tileCache;
  setUpAll(() {
    tileCache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: Directory('build/recording-test-cache').absolute.path,
      maxCacheSize: null,
      readOnly: true,
    );
  });
  tearDownAll(() => tileCache.destroy());

  if (const bool.fromEnvironment('RECORDING_CAPTURE')) {
    setUpAll(_loadPreviewFonts);
  }
  for (final (width, height, scale, activity) in [
    (320.0, 560.0, 2.0, 'walking'),
    (360.0, 640.0, 1.0, 'jogging'),
    (375.0, 640.0, 1.3, 'running'),
    (390.0, 844.0, 1.0, 'jogging'),
    (414.0, 720.0, 1.5, 'walking'),
    (430.0, 780.0, 2.0, 'cycling'),
    (640.0, 320.0, 2.0, 'cycling'),
  ]) {
    testWidgets(
        'keeps recording controls visible at $width×$height, text $scale',
        (tester) async {
      await _withRecording(
        tester,
        width: width,
        height: height,
        scale: scale,
        activity: activity,
        run: (context) async {
          expect(find.text('Waiting for accurate GPS'), findsOneWidget);
          expect(find.text(activity == 'cycling' ? 'Speed' : 'Pace'),
              findsOneWidget);
          expect(find.text('Est. gross calories'), findsOneWidget);
          expect(find.text('Unavailable'), findsOneWidget);
          final map = find.byType(RouteMapWidget);
          expect(tester.getSize(map).height, inInclusiveRange(140.0, 290.0));
          if (height == 320) {
            final mapTop = tester.getTopLeft(map).dy;
            final viewport = tester
                .getRect(find.byKey(const PageStorageKey('recording-content')));
            await tester.dragFrom(Offset(viewport.left + 8, viewport.center.dy),
                const Offset(0, -64));
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(map).dy, lessThan(mapTop));
          }
          final finish = find.widgetWithText(FilledButton, 'Finish & Review');
          final initialFinishRect = tester.getRect(finish);
          final pauseRect =
              tester.getRect(find.widgetWithText(FilledButton, 'Pause'));
          expect(initialFinishRect.height, pauseRect.height);
          expect(initialFinishRect.width, pauseRect.width);
          expect(initialFinishRect.bottom, lessThan(height - 24));
          expect(initialFinishRect.height, greaterThanOrEqualTo(48));
          expect(
              find.byTooltip('Close recording').hitTestable(), findsOneWidget);

          await _tapVisible(tester, find.text('GPS details'));
          expect(
              find.textContaining('Only accepted GPS fixes'), findsOneWidget);
          await _tapVisible(tester, find.text('About free recording'));
          expect(
              find.textContaining('offline synchronization'), findsOneWidget);
          expect(tester.getRect(finish), initialFinishRect);
          expect(finish.hitTestable(), findsOneWidget);
          expect(find.text('Pause').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    });
  }

  testWidgets(
      'GPS quality, pause, resume and finish use the existing recording flow',
      (tester) async {
    await _withRecording(tester, run: (context) async {
      final map = find.byType(RouteMapWidget);
      final initialMapWidget = tester.widget(map);
      await tester.pump(const Duration(seconds: 1));
      expect(identical(tester.widget(map), initialMapWidget), isTrue);

      context.fix(latitude: 14.5995, accuracy: 60, secondsAgo: 3);
      await tester.pump();
      expect(find.text('Waiting for accurate GPS'), findsOneWidget);
      expect(tester.widget<RouteMapWidget>(map).trackedPoints, isEmpty);
      context.fix(latitude: 14.5995, accuracy: 5, secondsAgo: 2);
      await tester.pump();
      context.fix(latitude: 14.5996, accuracy: 5, secondsAgo: 1);
      await tester.pump();
      expect(find.text('Waiting for accurate GPS'), findsNothing);
      expect(tester.widget<RouteMapWidget>(map).trackedPoints, hasLength(2));
      expect(find.byTooltip('Recenter map'), findsOneWidget);

      await _tapVisible(tester, find.text('Pause'));
      expect(find.text('Paused', findRichText: true), findsOneWidget);
      await _tapVisible(tester, find.text('Finish & Review'));
      expect(find.text('Finish recording?'), findsOneWidget);
      await _tapVisible(tester, find.text('Back to activity'));
      expect(find.text('Resume').hitTestable(), findsOneWidget);
      expect(context.review, isNull);
      await _tapVisible(tester, find.text('Resume'));
      expect(find.text('Tracking live', findRichText: true), findsOneWidget);
      await _tapVisible(tester, find.byTooltip('Close recording'));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _tapVisible(tester, find.text('Back to activity'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Pause').hitTestable(), findsOneWidget);
      await _tapVisible(tester, find.text('Finish & Review'));
      await _tapVisible(
          tester, find.widgetWithText(FilledButton, 'Finish & review'));
      expect(find.text('Recording review fixture'), findsOneWidget);
      expect(context.review?.name, '/activity_complete');
      final result = context.review?.arguments as Map;
      expect(result['recordingMode'], 'free_recording');
      expect(result['activityType'], 'jogging');
      expect(result['distanceKm'], greaterThan(0));
      expect(result['gpsPoints'], hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('foreground pause warning remains visible with a Resume action',
      (tester) async {
    await _withRecording(
      tester,
      width: 320,
      height: 560,
      scale: 2,
      run: (context) async {
        final state = tester.state(find.byType(ActiveTrackingScreen))
            as WidgetsBindingObserver;
        state.didChangeAppLifecycleState(AppLifecycleState.paused);
        await tester.pumpAndSettle();
        final warning = find.text('Recording paused in the background');
        await tester.ensureVisible(warning);
        expect(warning, findsOneWidget);
        expect(find.text('Resume').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('accepted movement can show pace and a gross calorie estimate',
      (tester) async {
    await _withRecording(tester, hasProfileWeight: true, run: (context) async {
      expect(find.text('Unavailable'), findsOneWidget);
      // The recorder's Stopwatch measures wall time independently of frame time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 5)),
      );
      context.fix(latitude: 14.5995, accuracy: 5, secondsAgo: 3);
      await tester.pump();
      context.fix(latitude: 14.6000, accuracy: 5, secondsAgo: 1);
      await tester.pump();
      expect(find.textContaining(' kcal'), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
      expect(find.text('--:-- /km'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  if (const bool.fromEnvironment('RECORDING_CAPTURE')) {
    for (final brightness in Brightness.values) {
      testWidgets('renders recording preview in ${brightness.name}',
          (tester) async {
        await _withRecording(tester, brightness: brightness,
            run: (context) async {
          context.fix(latitude: 14.5995, accuracy: 60, secondsAgo: 1);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary = context.boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/recording-review')
              ..createSync(recursive: true);
            File('${directory.path}/recording-${brightness.name}.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        });
      });
    }
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _loadPreviewFonts() async {
  var sdk = File(Platform.resolvedExecutable).parent;
  while (sdk.parent.path != sdk.path) {
    final icons = File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(SynchronousFuture(
                ByteData.sublistView(icons.readAsBytesSync()))))
          .load();
      break;
    }
    sdk = sdk.parent;
  }
  // Use local fallback fonts for preview text with network fonts disabled.
  for (final (family, filename) in [
    ('Manrope', 'arialbd.ttf'),
    ('Inter', 'arial.ttf')
  ]) {
    final file = File('C:/Windows/Fonts/$filename');
    if (file.existsSync()) {
      await (FontLoader(family)
            ..addFont(SynchronousFuture(
                ByteData.sublistView(file.readAsBytesSync()))))
          .load();
    }
  }
}

class _RecordingFixture {
  int permissionChecks = 0;
  int streamStarts = 0;
  final boundary = GlobalKey();
  late MockStreamHandlerEventSink _positions;
  RouteSettings? review;

  void fix(
      {required double latitude,
      required double accuracy,
      required int secondsAgo}) {
    _positions.success({
      'latitude': latitude,
      'longitude': 120.9842,
      'accuracy': accuracy,
      'timestamp': DateTime.now()
          .subtract(Duration(seconds: secondsAgo))
          .millisecondsSinceEpoch,
    });
  }
}

Future<void> _withRecording(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
  String activity = 'jogging',
  Brightness brightness = Brightness.light,
  bool hasProfileWeight = false,
  bool autoStart = true,
  String recordingMode = 'free_recording',
  required Future<void> Function(_RecordingFixture) run,
}) async {
  final fixture = _RecordingFixture();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_location, (call) async {
    fixture.permissionChecks++;
    return switch (call.method) {
      'isLocationServiceEnabled' => true,
      'checkPermission' => 2,
      _ => null,
    };
  });
  messenger.setMockStreamHandler(
    _locationUpdates,
    MockStreamHandler.inline(onListen: (_, events) {
      fixture.streamStarts++;
      fixture._positions = events;
    }),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(() => messenger.setMockMethodCallHandler(_location, null));
  SharedPreferences.setMockInitialValues({
    if (hasProfileWeight) 'token': 'widget-test-token',
  });

  await http.runWithClient(() async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => UnitPreferences(),
      child: RepaintBoundary(
        key: fixture.boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildTheme(
              brightness: brightness, useGoogleFonts: false),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ActiveTrackingScreen(
              activity: activity, recordingMode: recordingMode),
          onGenerateRoute: (settings) {
            fixture.review = settings;
            return MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Text('Recording review fixture')),
            );
          },
        ),
      ),
    ));
    try {
      await tester.pumpAndSettle();
      if (autoStart && recordingMode == 'free_recording') {
        await _tapVisible(tester, find.text('Start'));
      }
      await run(fixture);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  },
      () => MockClient((request) async {
            if (request.url.path.endsWith('/auth/profile')) {
              return http.Response(
                  '{"success":true,"profile":{"weightKg":65}}', 200);
            }
            return http.Response.bytes(_testTile, 200,
                headers: {'content-type': 'image/png'});
          }));
}
