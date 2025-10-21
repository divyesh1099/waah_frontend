import 'package:flutter/material.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: () {}, child: const Text('Add User')),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('Roles & Permissions')),
        const SizedBox(height: 24),
        const Text('Activity logs will appear hereâ€¦'),
      ],
    );
  }
}
