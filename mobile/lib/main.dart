import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/activity_setup_screen.dart';
import 'screens/route_details_screen.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/otp') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => OtpScreen(email: args?['email'] ?? ''),
          );
        }
        if (settings.name == '/activity_setup') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => ActivitySetupScreen(activityType: args?['activityType'] ?? 'Walk'),
          );
        }
        if (settings.name == '/route_details') {
          return MaterialPageRoute(
            builder: (context) => const RouteDetailsScreen(),
            settings: settings,
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/routes': (context) => const RoutesScreen(),
      },
    );
  }
}
