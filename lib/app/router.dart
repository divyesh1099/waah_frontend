// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart'; // <-- add this

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
import '../features/users/user_new_page.dart';
import '../features/users/user_detail_page.dart';
import '../features/users/roles_page.dart'; //
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
    initialLocation: '/',
    routes: [
      // Public
      GoRoute(path: '/', builder: (c, s) => const HomeGate()),
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),

      // Authed area
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomePage()),
          GoRoute(path: '/pos', builder: (c, s) => const PosPage()),
          GoRoute(path: '/kot', builder: (c, s) => const KotPage()),
          GoRoute(path: '/online', builder: (c, s) => const OnlinePage()),
          GoRoute(path: '/shift', builder: (c, s) => const ShiftPage()),
          GoRoute(path: '/menu', builder: (c, s) => const MenuPage()),
          GoRoute(
            path: '/inventory',
            builder: (c, s) => const InventoryPage(),
          ),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsPage()),

          // USERS LIST
          GoRoute(
            path: '/users',
            builder: (c, s) => const UsersPage(),
          ),

          // CREATE USER
          GoRoute(
            path: '/users/new',
            builder: (c, s) => const UserCreatePage(),
          ),

          // USER DETAIL (assign/remove roles, view info)
          GoRoute(
            path: '/users/:id',
            builder: (c, s) {
              final id = s.pathParameters['id']!;
              final initial = s.extra is UserSummary
                  ? s.extra as UserSummary
                  : null;
              return UserDetailPage(
                userId: id,
                initialUser: initial,
              );
            },
          ),

          // ROLES LIST
          GoRoute(
            path: '/roles',
            builder: (c, s) => const RolesPage(),
          ),

          // ROLE DETAIL (grant/revoke permissions)
          GoRoute(
            path: '/roles/:roleId',
            builder: (c, s) {
              final rid = s.pathParameters['roleId']!;
              final initialRole =
              s.extra is Role ? s.extra as Role : null;
              return RoleDetailPage(
                roleId: rid,
                initialRole: initialRole,
              );
            },
          ),

          GoRoute(
              path: '/settings', builder: (c, s) => const SettingsPage()),
          GoRoute(
            path: '/orders',
            name: 'orders',
            builder: (c, s) => const OrdersPage(),
          ),
        ],
      ),
    ],

    // auth + RBAC guard
    redirect: (context, state) {
      final authed = ref.read(isAuthedProvider);
      final path = state.uri.path;

      final isPublic =
          path == '/login' || path == '/onboarding' || path == '/';

      // if not logged in and trying to hit a private route
      if (!authed && !isPublic) return '/login';

      // if logged in but trying to go to login/onboarding
      if (authed && (path == '/login' || path == '/onboarding')) {
        return '/';
      }

      // lock down /users* and /roles* to SETTINGS_EDIT
      if (path.startsWith('/users') || path.startsWith('/roles')) {
        final me = ref.read(authControllerProvider).me;
        final canManage =
            me?.permissions.contains('SETTINGS_EDIT') ?? false;
        if (!canManage) {
          return '/menu';
        }
      }

      return null;
    },
  );
});
