﻿// lib/features/auth/login_page.dart  (your LoginPage)
// Key changes:
//  - remove hard-coded default texts
//  - choose PIN mode by reading whether a pin_hash exists
//  - better validation & tiny UX nits
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
  final _mobile = TextEditingController(); // no prefill
  final _pass   = TextEditingController(); // no prefill
  final _pin    = TextEditingController(); // no prefill
  final _form   = GlobalKey<FormState>();

  bool _usePin = false;        // set in init by prefs
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsProvider);
    // If we’ve ever stored a PIN hash, default to PIN mode.
    final hasSavedPin = (prefs.getString('pin_hash') ?? '').isNotEmpty;
    _usePin = hasSavedPin;

    // Optionally pre-fill only the mobile after first successful login
    final lastMobile = prefs.getString('last_mobile');
    if (lastMobile != null && lastMobile.isNotEmpty) {
      _mobile.text = lastMobile;
    }
  }

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

    if (ref.read(isAuthedProvider) && mounted) {
      context.go('/'); // HomeGate -> branch gating already handled elsewhere
    }
  }

  String? _mobileValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final t = v.trim();
    if (t.length < 8) return 'Enter valid mobile';
    return null;
  }

  String? _pinValidator(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (v.length != 4) return 'Enter 4-digit PIN';
    if (int.tryParse(v) == null) return 'Digits only';
    return null;
  }

  String? _passValidator(String? v) => (v == null || v.isEmpty) ? 'Required' : null;

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
                      validator: _mobileValidator,
                      autofillHints: const [AutofillHints.telephoneNumber],
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _usePin,
                      title: const Text('Use 4-digit PIN'),
                      onChanged: (v) => setState(() => _usePin = v),
                    ),
                    const SizedBox(height: 12),

                    if (_usePin)
                      TextFormField(
                        controller: _pin,
                        decoration: const InputDecoration(labelText: 'PIN'),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        validator: _pinValidator,
                        autofillHints: const [AutofillHints.password],
                      )
                    else
                      TextFormField(
                        controller: _pass,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        obscureText: _obscure,
                        validator: _passValidator,
                        autofillHints: const [AutofillHints.password],
                      ),

                    const SizedBox(height: 16),
                    if (auth.error != null) ...[
                      Text(auth.error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],

                    FilledButton(
                      onPressed: auth.loading ? null : _doLogin,
                      child: auth.loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_usePin ? 'Unlock' : 'Login'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/onboarding'),
                      child: const Text('New setup? Run Onboarding'),
                    ),

                    if (auth.offline)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Offline mode: limited actions', style: TextStyle(fontSize: 12)),
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
