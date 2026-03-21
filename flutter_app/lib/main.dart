import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/permission_service.dart';
import 'services/app_blocking_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/strictness_screen.dart';
import 'screens/permission_setup_screen.dart';
import 'screens/blocked_apps_screen.dart';

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
        ChangeNotifierProvider(
          create: (_) => PermissionService(),
        ),
        ChangeNotifierProxyProvider<ApiService, AppBlockingService>(
          create: (ctx) => AppBlockingService(ctx.read<ApiService>()),
          update: (ctx, api, prev) => prev ?? AppBlockingService(api),
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
          '/permission-setup': (context) => const PermissionSetupScreen(),
          '/dashboard': (context) => const FocusScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/planner': (context) => const PlannerScreen(),
          '/calendar': (context) => const CalendarScreen(),
          '/analysis': (context) => const AnalysisScreen(),
          '/strictness': (context) => const StrictnessScreen(),
          '/blocked-apps': (context) => const BlockedAppsScreen(),
        },
      ),
    );
  }
}

/// AuthGate — checks login → profile completion → permissions → dashboard
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await context.read<PermissionService>().checkAll();
    if (mounted) setState(() => _permissionsChecked = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final perms = context.watch<PermissionService>();

    // Not logged in yet → show login
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    // Logged in but profile not set up → onboarding first
    if (!auth.profileComplete) {
      return const OnboardingScreen();
    }

    // Permissions not yet checked → show a brief loading splash
    if (!_permissionsChecked) {
      return const _PermissionCheckSplash();
    }

    // Permissions not all granted → show the permission wizard
    if (!perms.allGranted) {
      return const PermissionSetupScreen();
    }

    // Everything clear → main app
    return const FocusScreen();
  }
}

/// Brief loading screen shown while permissions are being checked.
class _PermissionCheckSplash extends StatelessWidget {
  const _PermissionCheckSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A14),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B61FF)),
              strokeWidth: 2,
            ),
            SizedBox(height: 20),
            Text(
              'QuantumFocus',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
