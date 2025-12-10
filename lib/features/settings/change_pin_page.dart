import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/api_client.dart';

class ChangePinPage extends ConsumerStatefulWidget {
  const ChangePinPage({super.key});

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtl = TextEditingController();
  final _newCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtl.dispose();
    _newCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);

    try {
      await api.changePin(
        currentPin: _currentCtl.text,
        newPin: _newCtl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated')),
        );
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to change PIN');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validatePin(String? v) {
    if (v == null || v.isEmpty) return 'Enter PIN';
    if (v.length < 4) return 'Use at least 4 digits';
    if (!RegExp(r'^\\d+$').hasMatch(v)) return 'PIN should be numbers only';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentCtl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current PIN',
                      prefixIcon: Icon(Icons.pin),
                    ),
                    validator: _validatePin,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCtl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'New PIN',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    validator: _validatePin,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new PIN',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    validator: (v) {
                      final base = _validatePin(v);
                      if (base != null) return base;
                      if (v != _newCtl.text) return 'PINs do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  FilledButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_loading ? 'Saving...' : 'Update PIN'),
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
