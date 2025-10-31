import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _mobile = TextEditingController(text: '9999999999');
  final _pass = TextEditingController(text: 'admin');
  final _pin  = TextEditingController(text: '1234');
  final _form = GlobalKey<FormState>();

  bool _usePin = false; // toggle between password and pin

  @override
  void dispose() {
    _mobile.dispose();
    _pass.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_form.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).login(
      _mobile.text.trim(),
      _usePin ? '' : _pass.text,
      pin: _usePin ? _pin.text.trim() : null,
    );

    // if authed (token present), route to HomeGate -> which will branch-gate
    if (ref.read(isAuthedProvider) && context.mounted) {
      context.go('/');
    }
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
                      decoration:
                      const InputDecoration(labelText: 'Mobile'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Toggle: password login vs PIN login
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _usePin,
                      title: const Text('Use 4-digit PIN instead'),
                      onChanged: (v) {
                        setState(() {
                          _usePin = v;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    if (_usePin)
                      TextFormField(
                        controller: _pin,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Required'
                            : null,
                      )
                    else
                      TextFormField(
                        controller: _pass,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Required'
                            : null,
                      ),

                    const SizedBox(height: 16),
                    if (auth.error != null) ...[
                      Text(
                        auth.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                    ],

                    FilledButton(
                      onPressed: auth.loading ? null : _doLogin,
                      child: auth.loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
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
