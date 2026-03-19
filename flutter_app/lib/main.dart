import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/strictness_screen.dart';

void main() {
  runApp(const AntiDistractionApp());
}

class AntiDistractionApp extends StatelessWidget {
  const AntiDistractionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(
          create: (_) => AuthService(apiService)..tryAutoLogin(),
        ),
      ],
      child: MaterialApp(
        title: 'QuantumFocus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/dashboard': (context) => const FocusScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/planner': (context) => const PlannerScreen(),
          '/calendar': (context) => const CalendarScreen(),
          '/analysis': (context) => const AnalysisScreen(),
          '/strictness': (context) => const StrictnessScreen(),
        },
      ),
    );
  }
}

/// AuthGate — checks login status and profile completion
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasEvaluatedToday = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoggedIn) {
      if (!auth.profileComplete) {
        return const OnboardingScreen();
      }
      
      return const FocusScreen();
    }
    return const LoginScreen();
  }
}
