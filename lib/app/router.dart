import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'shell.dart';
import '../features/auth/login_page.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
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
        ],
      ),
    ],
    redirect: (context, state) => null,
  );
});
