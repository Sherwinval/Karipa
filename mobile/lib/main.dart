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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const PathCraftApp(),
    ),
  );
}

class PathCraftApp extends StatelessWidget {
  const PathCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          primary: const Color(0xFF0D9488),
          secondary: const Color(0xFF14B8A6),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
        ),
      ),
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
            return MaterialPageRoute(builder: (_) => const ActivitySelectionScreen());

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
                targetDistanceKm: (args?['targetDistanceKm'] as num?)?.toDouble() ?? 5.0,
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
                route: args?['route'] as PathRoute,
                activity: args?['activity'] ?? 'running',
                initialPosition: args?['initialPosition'] as Position?,
              ),
            );

          case '/activity_complete':
            return MaterialPageRoute(
              builder: (_) => ActivityCompleteScreen(
                activityType: args?['activityType'] ?? 'running',
                distanceKm: (args?['distanceKm'] as num?)?.toDouble() ?? 0.0,
                durationSeconds: (args?['durationSeconds'] as num?)?.toInt() ?? 0,
                paceOrSpeed: args?['paceOrSpeed'] ?? '--:--',
                calories: (args?['calories'] as num?)?.toDouble() ?? 0.0,
                route: args?['route'] as PathRoute,
                gpsPoints: (args?['gpsPoints'] as List<LatLng>?) ?? [],
              ),
            );

          case '/activity_history':
            return MaterialPageRoute(builder: (_) => const ActivityHistoryScreen());

          case '/activity_details':
            return MaterialPageRoute(
              builder: (_) => ActivityDetailsScreen(
                activity: args?['activity'] as ActivityModel,
              ),
            );

          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());

          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
