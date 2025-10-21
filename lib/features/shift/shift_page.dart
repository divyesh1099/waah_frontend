import 'package:flutter/material.dart';

class ShiftPage extends StatelessWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: () {}, child: const Text('Open Day / Enter Opening Cash')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Cash In'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Cash Out'))),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('Close Day')),
        const SizedBox(height: 24),
        const Text('Tally / Movements will appear hereâ€¦'),
      ],
    );
  }
}
