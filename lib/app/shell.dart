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

    // pull restaurant settings (name, logo) for this tenant+branch
    final rs = ref.watch(restaurantSettingsProvider).maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );

    // fallback brand while loading or if not configured yet
    final brandName =
    (rs != null && rs.name.isNotEmpty) ? rs.name : 'dPOS';

    // build absolute logo URL if we have a /media/... path
    final logoFullUrl = (rs != null &&
        rs.logoUrl != null &&
        rs.logoUrl!.isNotEmpty)
        ? '$kBaseUrl${rs.logoUrl}'
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!authed) {
        context.go('/login');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (logoFullUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    logoFullUrl,
                    height: 32,
                    width: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.restaurant, size: 32),
                  ),
                ),
              ),
            Flexible(
              child: Text(
                brandName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand row (logo + name), replaces "dPOS"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (logoFullUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            logoFullUrl,
                            height: 40,
                            width: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.restaurant, size: 40),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          brandName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),

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
