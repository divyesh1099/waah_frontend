import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waah_frontend/app/shell.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/features/auth/auth_controller.dart';

import 'package:waah_frontend/data/local/app_db.dart'; // NEW

void main() {
  testWidgets('Sidebar closes when an item is selected', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => Container(key: const Key('home'))),
            GoRoute(path: '/menu', builder: (context, state) => Container(key: const Key('menu'))),
            GoRoute(path: '/pos', builder: (context, state) => Container(key: const Key('pos'))),
            GoRoute(path: '/branch/select', builder: (context, state) => Container(key: const Key('branch-select'))),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthedProvider.overrideWithValue(true),
          authControllerProvider.overrideWith((ref) => AuthControllerMock(ref, prefs)),
          activeBranchIdProvider.overrideWith((ref) => IdNotifier(prefs, 'active_branch_id', 'branch-1')),
          restaurantSettingsProvider.overrideWith((ref) => Stream.value(RestaurantSetting(
            id: 1,
            tenantId: 't1',
            branchId: 'b1',
            name: 'Test Rest',
            logoUrl: '',
            printFssaiOnInvoice: false,
            gstInclusiveDefault: true,
            serviceChargeMode: 'NONE',
            serviceChargeValue: 0.0,
            packingChargeMode: 'NONE',
            packingChargeValue: 0.0,
          ))),
          branchesStreamProvider.overrideWith((ref) => Stream.value([])),
           mediaResolverProvider.overrideWithValue((path) => Uri.parse('http://test/$path')),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Verify drawer is closed initially
    expect(find.text('Menu'), findsNothing);

    // Open the drawer
    await tester.dragFrom(const Offset(0, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    // Verify drawer is open
    expect(find.text('Menu'), findsOneWidget);

    // Tap on 'Menu' item
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // Verify drawer is closed
    expect(find.text('Menu'), findsNothing);
  });
}

class AuthControllerMock extends AuthController {
  AuthControllerMock(Ref ref, SharedPreferences prefs) : super(ref, prefs) {
    state = AuthState(
      token: 'token',
      me: MeInfo(
        id: 'u1',
        tenantId: 't1',
        branchId: 'b1',
        name: 'Test User',
        active: true,
        roles: [],
        permissions: [],
      ),
    );
  }
}
