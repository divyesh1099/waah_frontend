// lib/app/shell.dart
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

    // if token got nuked (401 -> logout), kick user to /login
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
            const DrawerHeader(
              child: Text('Waah POS'),
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
              title: const Text('Shift'),
              onTap: () => context.go('/shift'),
            ),
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
