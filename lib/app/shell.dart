import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'nav_items.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WAAH POS')),
      drawer: const _AppDrawer(), // no selection highlight yet (version-safe)
      body: child,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 56, height: 56),
                  const SizedBox(width: 12),
                  const Text('WAAH POS',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                itemBuilder: (context, i) {
                  final n = navItems[i];
                  return ListTile(
                    leading: Icon(n.icon),
                    title: Text(n.title),
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      context.go(n.route);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
