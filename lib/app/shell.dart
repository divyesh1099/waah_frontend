import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(isAuthedProvider);
    final me = ref.watch(authControllerProvider).me;
    final currentBranchId = ref.watch(activeBranchIdProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!authed) {
        context.go('/login');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waah'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Waah POS',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    'User: ${me?.name ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Branch: ${currentBranchId.isEmpty ? '(none)' : currentBranchId}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.store),
                    label: const Text(
                      'Change Branch',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      context.go('/branch/select');
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Menu'),
              onTap: () => context.go('/menu'),
            ),
            ListTile(
              title: const Text('POS'),
              onTap: () => context.go('/pos'),
            ),
            ListTile(
              title: const Text('Orders'),
              onTap: () => context.go('/orders'),
            ),
            ListTile(
              title: const Text('Shift & Cash'),
              onTap: () => context.go('/shift'),
            ),
            ListTile(
              title: const Text('KOT'),
              onTap: () => context.go('/kot'),
            ),
            ListTile(
              title: const Text('Online Orders'),
              onTap: () => context.go('/online'),
            ),
            ListTile(
              title: const Text('Inventory'),
              onTap: () => context.go('/inventory'),
            ),
            ListTile(
              title: const Text('Reports'),
              onTap: () => context.go('/reports'),
            ),
            const Divider(),
            ListTile(
              title: const Text('Users'),
              onTap: () => context.go('/users'),
            ),
            ListTile(
              title: const Text('Roles / Permissions'),
              onTap: () => context.go('/roles'),
            ),
            ListTile(
              title: const Text('Settings'),
              subtitle: const Text('Branch, printers, backup'),
              onTap: () => context.go('/settings'),
            ),
            const Divider(),
            ListTile(
              title: const Text('Logout'),
              onTap: () {
                ref.read(authControllerProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}
