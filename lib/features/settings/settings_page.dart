import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(title: Text('Restaurant Profile (logo, address, GSTIN, FSSAI)')),
        ListTile(title: Text('Charges (service & packing)')),
        ListTile(title: Text('Printers & Stations (billing, kitchen, drawer)')),
        ListTile(title: Text('Invoice footer / tax options')),
        ListTile(title: Text('Backup & Security')),
        ListTile(title: Text('Device / Sync status')),
      ],
    );
  }
}
