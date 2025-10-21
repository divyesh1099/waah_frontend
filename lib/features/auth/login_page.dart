import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/empty_state.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: EmptyState(
        title: 'WAAH POS',
        subtitle: 'Sign in with mobile + password or PIN',
        actions: [
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Mock Sign In'),
          ),
        ],
      ),
    );
  }
}
