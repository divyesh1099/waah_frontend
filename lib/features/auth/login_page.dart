import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waah_frontend/app/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _mobile = TextEditingController(text: '9999999999');
  final _pass = TextEditingController(text: 'admin');
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _mobile.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _mobile,
                      decoration: const InputDecoration(labelText: 'Mobile'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v==null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => v==null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    if (auth.error != null) ...[
                      Text(auth.error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: auth.loading ? null : () async {
                        if (!_form.currentState!.validate()) return;
                        await ref.read(authControllerProvider.notifier)
                            .login(_mobile.text.trim(), _pass.text);
                        if (ref.read(isAuthedProvider) && context.mounted) {
                          context.go('/');
                        }
                      },
                      child: auth.loading
                          ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
                          : const Text('Login'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/onboarding'),
                      child: const Text('New setup? Run Onboarding'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
