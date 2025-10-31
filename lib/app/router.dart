import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';

import '../data/repo/catalog_repo.dart';
import '../features/users/role_detail_page.dart';
import 'shell.dart';

// Public / auth / onboarding
import 'package:waah_frontend/features/auth/login_page.dart';
import 'package:waah_frontend/features/onboarding/onboarding_page.dart';

// Main app sections
import 'package:waah_frontend/features/home/home_page.dart';
import 'package:waah_frontend/features/pos/pos_page.dart';
import 'package:waah_frontend/features/kot/kot_page.dart';
import 'package:waah_frontend/features/online/online_page.dart';
import 'package:waah_frontend/features/shift/shift_page.dart';
import 'package:waah_frontend/features/menu/menu_page.dart';
import 'package:waah_frontend/features/inventory/inventory_page.dart';
import 'package:waah_frontend/features/reports/reports_page.dart';
import 'package:waah_frontend/features/orders/orders_page.dart';

// Users / roles
import 'package:waah_frontend/features/users/users_page.dart';
import 'package:waah_frontend/features/users/user_new_page.dart';
import 'package:waah_frontend/features/users/user_detail_page.dart';
import 'package:waah_frontend/features/users/roles_page.dart';

// Settings
import 'package:waah_frontend/features/settings/settings_page.dart';
import 'package:waah_frontend/features/settings/branch_settings_page.dart';
import 'package:waah_frontend/features/settings/printer_settings_page.dart';
import 'package:waah_frontend/features/settings/branch_select_page.dart';
import 'package:waah_frontend/features/settings/table_settings_page.dart';

/// Small gate that redirects after the first frame based on auth state.
/// Ensures /auth/me is fetched and adopts me.branchId into activeBranchId.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed    = ref.watch(isAuthedProvider);
    final authState = ref.watch(authControllerProvider);
    final me        = authState.me;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      // 1) Ensure /auth/me on cold start or immediately after login
      if (authed && me == null) {
        ref.read(authControllerProvider.notifier).refreshMe();
      }

      // 2) If no active branch chosen yet, adopt branch from /auth/me
      final branchNow = ref.read(activeBranchIdProvider).trim();
      final meBranch  = ref.read(authControllerProvider).me?.branchId ?? '';
      if (authed && branchNow.isEmpty && meBranch.isNotEmpty) {
        ref.read(activeBranchIdProvider.notifier).set(meBranch);
      }

      // 3) Navigate after the above adjustments
      final hasBranch = ref.read(activeBranchIdProvider).trim().isNotEmpty;
      if (!authed) {
        context.go('/login');
      } else if (!hasBranch) {
        context.go('/branch/select');
      } else {
        context.go('/menu');
        // 🚀 ensure local DB is populated, then go to menu
        final tenantId = ref.read(activeTenantIdProvider);
        final branchId = ref.read(activeBranchIdProvider);
        unawaited(ref.read(catalogRepoProvider).syncDownMenu(tenantId, branchId));
      }
    });

    return const Scaffold(body: SizedBox.shrink());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Public
      GoRoute(
        path: '/',
        builder: (c, s) => const HomeGate(),
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) => const LoginPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (c, s) => const OnboardingPage(),
      ),

      // Authed area (everything below goes inside AppShell with drawer/appbar)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (c, s) => const HomePage(),
          ),
          GoRoute(
            path: '/pos',
            builder: (c, s) => const PosPage(),
          ),
          GoRoute(
            path: '/kot',
            builder: (c, s) => const KotPage(),
          ),
          GoRoute(
            path: '/online',
            builder: (c, s) => const OnlinePage(),
          ),
          GoRoute(
            path: '/shift',
            builder: (c, s) => const ShiftPage(),
          ),
          GoRoute(
            path: '/menu',
            builder: (c, s) => const MenuPage(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (c, s) => const InventoryPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (c, s) => const ReportsPage(),
          ),

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
              final initial = s.extra is UserSummary ? s.extra as UserSummary : null;
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
              final initialRole = s.extra is RoleInfo ? s.extra as RoleInfo : null;
              return RoleDetailPage(
                roleId: rid,
                initialRole: initialRole,
              );
            },
          ),

          // SETTINGS LANDING
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'branch',
                name: 'settings-branch',
                builder: (context, state) => const BranchSettingsPage(),
              ),
              GoRoute(
                path: 'tables',
                name: 'settings-tables',
                builder: (context, state) => const TableSettingsPage(),
              ),
              GoRoute(
                path: 'printers',
                name: 'settings-printers',
                builder: (context, state) => const PrinterSettingsPage(),
              ),
            ],
          ),

          // ORDERS LIST
          GoRoute(
            path: '/orders',
            name: 'orders',
            builder: (c, s) => const OrdersPage(),
          ),

          // Choose/Change Branch
          GoRoute(
            path: '/branch/select',
            builder: (c, s) => const BranchSelectPage(),
          ),
        ],
      ),
    ],

    // auth + RBAC guard
    redirect: (context, state) {
      final authed      = ref.read(isAuthedProvider);
      final path        = state.uri.path;
      final branchIdNow = ref.read(activeBranchIdProvider).trim();
      final hasBranch   = branchIdNow.isNotEmpty;

      final isPublic = path == '/login' || path == '/onboarding' || path == '/';

      // not logged in -> force /login (unless already public)
      if (!authed && !isPublic) {
        return '/login';
      }

      // logged in but NO branch yet: only allow /branch/select
      if (authed && !hasBranch) {
        if (path != '/branch/select') return '/branch/select';
        return null;
      }

      // logged in shouldn't go to /login or /onboarding anymore
      if (authed && (path == '/login' || path == '/onboarding')) {
        return '/';
      }

      // lock down /users* and /roles* to SETTINGS_EDIT
      if (path.startsWith('/users') || path.startsWith('/roles')) {
        final me = ref.read(authControllerProvider).me;
        final canManage = me?.permissions.contains('SETTINGS_EDIT') ?? false;
        if (!canManage) return '/menu';
      }

      return null;
    },
  );
});
