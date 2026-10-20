import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'models/route_model.dart';
import 'models/activity_model.dart';
import 'services/auth_service.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/activity_selection_screen.dart';
import 'screens/route_planning_screen.dart';
import 'screens/recommended_routes_screen.dart';
import 'screens/route_details_screen.dart';
import 'screens/ready_to_start_screen.dart';
import 'screens/active_tracking_screen.dart';
import 'screens/activity_complete_screen.dart';
import 'screens/activity_history_screen.dart';
import 'screens/activity_details_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'theme/app_theme.dart';

import 'services/theme_service.dart';
import 'services/unit_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => UnitPreferences()),
      ],
      child: const KaripaApp(),
    ),
  );
}

class KaripaApp extends StatelessWidget {
  const KaripaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'Karipa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());

          case '/otp':
            return MaterialPageRoute(
              builder: (_) => OtpScreen(email: args?['email'] ?? ''),
            );

          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());

          case '/activity_selection':
            return MaterialPageRoute(
                builder: (_) => const ActivitySelectionScreen());

          case '/route_planning':
            return MaterialPageRoute(
              builder: (_) => RoutePlanningScreen(
                activity: args?['activity'] ?? 'running',
              ),
            );

          case '/recommended_routes':
            return MaterialPageRoute(
              builder: (_) => RecommendedRoutesScreen(
                routes: (args?['routes'] as List<PathRoute>?) ?? [],
                activity: args?['activity'] ?? 'running',
                targetDistanceKm:
                    (args?['targetDistanceKm'] as num?)?.toDouble() ?? 5.0,
                currentLocation: args?['currentLocation'] as Position?,
              ),
            );

          case '/route_details':
            return MaterialPageRoute(
              builder: (_) => RouteDetailsScreen(
                route: args?['route'] as PathRoute,
                activity: args?['activity'] ?? 'running',
                currentLocation: args?['currentLocation'] as Position?,
              ),
            );

          case '/ready_to_start':
            return MaterialPageRoute(
              builder: (_) => ReadyToStartScreen(
                route: args?['route'] as PathRoute,
                activity: args?['activity'] ?? 'running',
                currentLocation: args?['currentLocation'] as Position?,
              ),
            );

          case '/active_tracking':
            return MaterialPageRoute(
              builder: (_) => ActiveTrackingScreen(
                route: args?['route'] as PathRoute?,
                activity: args?['activity'] ?? 'running',
                recordingMode: args?['recordingMode'] ?? 'plan_route',
                initialPosition: args?['initialPosition'] as Position?,
              ),
            );

          case '/activity_complete':
            return MaterialPageRoute(
              builder: (_) => ActivityCompleteScreen(
                activityType: args?['activityType'] ?? 'running',
                recordingMode: args?['recordingMode'] ?? 'plan_route',
                distanceKm: (args?['distanceKm'] as num?)?.toDouble() ?? 0.0,
                durationSeconds:
                    (args?['durationSeconds'] as num?)?.toInt() ?? 0,
                totalElapsedSeconds:
                    (args?['totalElapsedSeconds'] as num?)?.toInt(),
                startedAt: args?['startedAt'] as DateTime?,
                completedAt: args?['completedAt'] as DateTime?,
                paceOrSpeed: args?['paceOrSpeed'] ?? '--:--',
                averagePaceSecondsPerKm:
                    (args?['averagePaceSecondsPerKm'] as num?)?.toDouble(),
                averageSpeedKmh: (args?['averageSpeedKmh'] as num?)?.toDouble(),
                calories: (args?['calories'] as num?)?.toDouble(),
                calorieUnavailableReason:
                    args?['calorieUnavailableReason']?.toString(),
                calorieMetCode: args?['calorieMetCode']?.toString(),
                calorieMetValue: (args?['calorieMetValue'] as num?)?.toDouble(),
                calorieWeightKg: (args?['calorieWeightKg'] as num?)?.toDouble(),
                calorieDurationMinutes:
                    (args?['calorieDurationMinutes'] as num?)?.toDouble(),
                calorieMethodVersion: args?['calorieMethodVersion']?.toString(),
                route: args?['route'] as PathRoute?,
                gpsPoints: (args?['gpsPoints'] as List<LatLng>?) ?? [],
                gpsData:
                    (args?['gpsData'] as List<Map<String, dynamic>>?) ?? [],
                idempotencyKey: args?['idempotencyKey']?.toString() ?? '',
              ),
            );

          case '/activity_history':
            return MaterialPageRoute(
                builder: (_) => const ActivityHistoryScreen());

          case '/activity_details':
            return MaterialPageRoute(
              builder: (_) => ActivityDetailsScreen(
                activity: args?['activity'] as ActivityModel,
              ),
            );

          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());

          case '/leaderboard':
            return MaterialPageRoute(builder: (_) => const LeaderboardScreen());

          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
