import 'package:flutter/material.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: () {}, child: const Text('Add Purchase Entry')),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('Link Recipe / BOM')),
        const SizedBox(height: 24),
        const Text('Low-stock alerts & Stock report will show hereâ€¦'),
      ],
    );
  }
}
