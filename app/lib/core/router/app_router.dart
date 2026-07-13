import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/presentation/analysis_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/cost/presentation/cost_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/designs/presentation/designs_screen.dart';
import '../../features/projects/presentation/project_screen.dart';
import '../../features/quantities/presentation/quantities_screen.dart';
import '../../features/reports/presentation/report_screen.dart';
import '../../features/scan/presentation/scan_flow_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/splash_screen.dart';

/// Route names — single source of truth for navigation.
abstract class Routes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const scan = '/scan';
  static const project = '/project/:id';
  static const analysis = '/project/:id/analysis';
  static const designs = '/project/:id/designs';
  static const cost = '/project/:id/cost';
  static const quantities = '/project/:id/quantities';
  static const report = '/project/:id/report';
  static const chat = '/chat';
  static const settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      // Still resolving auth → stay on splash.
      if (authState.isLoading) return null;
      final signedIn = authState.valueOrNull != null;
      final onAuthPages = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.splash;
      if (!signedIn && !onAuthPages) return Routes.login;
      if (signedIn && onAuthPages) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const DashboardScreen()),
      GoRoute(path: Routes.scan, builder: (_, __) => const ScanFlowScreen()),
      GoRoute(
        path: Routes.project,
        builder: (_, s) => ProjectScreen(projectId: s.pathParameters['id']!),
        routes: [
          GoRoute(
              path: 'analysis',
              builder: (_, s) =>
                  AnalysisScreen(projectId: s.pathParameters['id']!)),
          GoRoute(
              path: 'designs',
              builder: (_, s) =>
                  DesignsScreen(projectId: s.pathParameters['id']!)),
          GoRoute(
              path: 'cost',
              builder: (_, s) => CostScreen(projectId: s.pathParameters['id']!)),
          GoRoute(
              path: 'quantities',
              builder: (_, s) =>
                  QuantitiesScreen(projectId: s.pathParameters['id']!)),
          GoRoute(
              path: 'report',
              builder: (_, s) =>
                  ReportScreen(projectId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: Routes.chat, builder: (_, __) => const ChatScreen()),
      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
