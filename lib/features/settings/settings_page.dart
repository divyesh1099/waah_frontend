import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Branch / Restaurant Profile'),
          subtitle: const Text('Name, address, GSTIN, FSSAI, invoice footer'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/branch'),
        ),
        const Divider(height: 1),
        ListTile(
          title: const Text('Printers & Kitchen Stations'),
          subtitle: const Text('Billing printer, KOT routing, cash drawer'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/printers'),
        ),
        const Divider(height: 1),
        ListTile(
          title: const Text('Users & Roles'),
          subtitle: const Text('Cashier/Waiter/Manager permissions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/users'),
        ),
        const Divider(height: 1),
        ListTile(
          title: const Text('Backup & Security'),
          subtitle: const Text('Auto backup, sync status'),
          trailing: const Icon(Icons.chevron_right),
          // TODO: route when backup page exists
          onTap: () {},
        ),
      ],
    );
  }
}
