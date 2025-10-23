import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waah_frontend/app/providers.dart';

import 'shell.dart';

import '../features/auth/login_page.dart';
import '../features/onboarding/onboarding_page.dart';

import '../features/home/home_page.dart';
import '../features/pos/pos_page.dart';
import '../features/kot/kot_page.dart';
import '../features/online/online_page.dart';
import '../features/shift/shift_page.dart';
import '../features/menu/menu_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/reports/reports_page.dart';
import '../features/users/users_page.dart';
import '../features/settings/settings_page.dart';
import '../features/orders/orders_page.dart';

/// Small gate that redirects after the first frame based on auth state.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(isAuthedProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.go(authed ? '/menu' : '/login');
    });

    return const Scaffold(body: SizedBox.shrink());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // Land at "/" which uses HomeGate to bounce to the right place
    initialLocation: '/',
    routes: [
      // Public routes
      GoRoute(path: '/', builder: (c, s) => const HomeGate()),
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),

      // Authed app area
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomePage()),
          GoRoute(path: '/pos', builder: (c, s) => const PosPage()),
          GoRoute(path: '/kot', builder: (c, s) => const KotPage()),
          GoRoute(path: '/online', builder: (c, s) => const OnlinePage()),
          GoRoute(path: '/shift', builder: (c, s) => const ShiftPage()),
          GoRoute(path: '/menu', builder: (c, s) => const MenuPage()),
          GoRoute(path: '/inventory', builder: (c, s) => const InventoryPage()),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsPage()),
          GoRoute(path: '/users', builder: (c, s) => const UsersPage()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
          GoRoute(path: '/orders', name: 'orders', builder: (c, s) => const OrdersPage()),
        ],
      ),
    ],
    // Simple global guard
    redirect: (context, state) {
      final authed = ref.read(isAuthedProvider);
      final path = state.uri.path;

      final isPublic = path == '/login' || path == '/onboarding' || path == '/';
      if (!authed && !isPublic) return '/login';
      if (authed && (path == '/login' || path == '/onboarding')) return '/';
      return null;
    },
  );
});
