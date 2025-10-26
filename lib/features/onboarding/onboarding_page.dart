// lib/features/onboarding/onboarding_page.dart
import 'dart:ui'; // for BackdropFilter blur
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';

/// A sleek multi-step onboarding wizard.
/// Steps:
/// 0: Welcome
/// 1: Admin / Owner
/// 2: Branch
/// 3: Brand & Printers
/// 4: Done
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() =>
      _OnboardingPageState();
}

class _OnboardingPageState
    extends ConsumerState<OnboardingPage> {
  // ----- form keys -----
  final _formAdmin = GlobalKey<FormState>();
  final _formBranch = GlobalKey<FormState>();
  final _formBrand = GlobalKey<FormState>();

  // ----- controllers / inputs -----
  // secret + admin step
  final _appSecret = TextEditingController();
  final _tenantName =
  TextEditingController(text: 'Restaurant Demo'); // brand / tenant
  final _adminName = TextEditingController(text: 'Owner');
  final _mobile = TextEditingController(text: '98XXXXXXXX');
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'admin');
  final _pin = TextEditingController(text: '1234');

  // branch step
  final _branchName = TextEditingController(text: 'Main Branch');
  final _branchPhone = TextEditingController(text: '1800123000');
  final _branchGstin =
  TextEditingController(text: '27AAAAA0000A1Z5');
  final _branchState = TextEditingController(text: 'MH');
  final _branchAddr = TextEditingController(text: 'Road 1');

  // brand/printers step
  final _restName = TextEditingController(text: 'Restaurant Main');
  final _restPhone = TextEditingController(text: '1800123000');
  final _restAddr = TextEditingController(text: 'Road 1');

  // ----- runtime state -----
  bool _busy = false;
  String? _err;
  int _step = 0; // 0..4
  String? _tenantId;
  String? _branchId;

  // for final screen
  late String _finalMobile = _mobile.text;
  late String _finalPassword = _password.text;

  @override
  void dispose() {
    for (final c in [
      _appSecret,
      _tenantName,
      _adminName,
      _mobile,
      _email,
      _password,
      _pin,
      _branchName,
      _branchPhone,
      _branchGstin,
      _branchState,
      _branchAddr,
      _restName,
      _restPhone,
      _restAddr,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // API calls for each logical step
  // ─────────────────────────────────────────────

  Future<bool> _doCreateAdmin() async {
    // validate owner form
    if (!_formAdmin.currentState!.validate()) return false;

    setState(() {
      _busy = true;
      _err = null;
    });
    final client = ref.read(apiClientProvider);

    try {
      final admin = await client.onboardAdmin(
        appSecret: _appSecret.text.trim(),
        tenantName: _tenantName.text.trim(),
        adminName: _adminName.text.trim(),
        mobile: _mobile.text.trim(),
        email:
        _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _password.text,
        pin: _pin.text,
      );

      _tenantId = admin['tenant_id'] as String?;
      if (_tenantId == null || _tenantId!.isEmpty) {
        throw Exception('No tenant_id returned');
      }

      return true;
    } catch (e) {
      _err = e.toString();
      return false;
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<bool> _doCreateBranch() async {
    if (!_formBranch.currentState!.validate()) return false;
    if (_tenantId == null) {
      setState(() {
        _err = 'Missing tenant. Please finish previous step.';
      });
      return false;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    final client = ref.read(apiClientProvider);

    try {
      final br = await client.onboardBranch(
        appSecret: _appSecret.text.trim(),
        tenantId: _tenantId!,
        name: _branchName.text.trim(),
        phone: _branchPhone.text.trim(),
        gstin: _branchGstin.text.trim(),
        stateCode: _branchState.text.trim(),
        address: _branchAddr.text.trim(),
      );

      _branchId = br['branch_id'] as String?;
      if (_branchId == null || _branchId!.isEmpty) {
        throw Exception('No branch_id returned');
      }

      return true;
    } catch (e) {
      _err = e.toString();
      return false;
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<bool> _doBrandAndPrinters() async {
    if (!_formBrand.currentState!.validate()) return false;
    if (_tenantId == null || _branchId == null) {
      setState(() {
        _err =
        'Missing tenant / branch. Please finish previous steps.';
      });
      return false;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    final client = ref.read(apiClientProvider);

    try {
      // Save restaurant profile / legal identity
      await client.onboardRestaurant(
        appSecret: _appSecret.text.trim(),
        tenantId: _tenantId!,
        branchId: _branchId!,
        name: _restName.text.trim(),
        address: _restAddr.text.trim(),
        phone: _restPhone.text.trim(),
        gstin: _branchGstin.text.trim(),
        fssai: '11223344556677',
        printFssaiOnInvoice: true,
        gstInclusiveDefault: true,
      );

      // Seed printers + stations with sane defaults
      await client.onboardPrinters(
        appSecret: _appSecret.text.trim(),
        tenantId: _tenantId!,
        branchId: _branchId!,
        payload: {
          'billing': {
            'name': 'Billing',
            'connection_url':
            'http://localhost:9100/agent',
            'is_default': true,
            'cash_drawer_enabled': true,
            'cash_drawer_code': 'PULSE_2_100',
          },
          'kitchen': [
            {
              'name': 'Kitchen-1',
              'connection_url':
              'http://localhost:9101/agent',
              'is_default': true,
              'stations': ['Main'],
            }
          ],
        },
      );

      // Mark onboarding finished
      await client.onboardFinish(
        appSecret: _appSecret.text.trim(),
        tenantId: _tenantId!,
      );

      _finalMobile = _mobile.text.trim();
      _finalPassword = _password.text;

      return true;
    } catch (e) {
      _err = e.toString();
      return false;
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // step machine
  // ─────────────────────────────────────────────

  Future<void> _handlePrimaryTap() async {
    // We gate the "Continue" button by current step.
    switch (_step) {
      case 0:
      // Just go to step 1 (admin form)
        setState(() {
          _step = 1;
        });
        break;
      case 1:
        if (await _doCreateAdmin()) {
          setState(() {
            _step = 2;
          });
        }
        break;
      case 2:
        if (await _doCreateBranch()) {
          setState(() {
            _step = 3;
          });
        }
        break;
      case 3:
        if (await _doBrandAndPrinters()) {
          setState(() {
            _step = 4;
          });
        }
        break;
      case 4:
      // "Done" – pop back or navigate to login
        if (mounted) {
          Navigator.of(context).pop(); // or pushReplacement('/login')
        }
        break;
    }
  }

  String get _primaryCtaText {
    if (_busy) return 'Working...';
    switch (_step) {
      case 0:
        return 'Get Started';
      case 1:
        return 'Create Admin';
      case 2:
        return 'Create Branch';
      case 3:
        return 'Finish Setup';
      case 4:
        return 'Go to Login';
      default:
        return 'Continue';
    }
  }

  // ─────────────────────────────────────────────
  // UI pieces
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalSteps = 4; // we call 0=welcome, 1..3=setup forms
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: Colors.deepOrangeAccent,
      surface: const Color(0xFF1C1C1E),
      background: Colors.black,
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.black,
        textTheme: Theme.of(context)
            .textTheme
            .apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        )
            .copyWith(
          headlineSmall: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: -0.2,
            height: 1.2,
            color: Colors.white,
          ),
          headlineMedium: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 28,
            letterSpacing: -0.3,
            height: 1.2,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            height: 1.4,
          ),
          labelLarge: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            letterSpacing: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          labelStyle:
          TextStyle(color: Colors.white.withOpacity(0.7)),
          hintStyle:
          TextStyle(color: Colors.white.withOpacity(0.4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.4),
              width: 1,
            ),
          ),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black,
                    Color(0xFF1C1C1E),
                  ],
                ),
              ),
            ),

            // main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // top chrome (step pill, maybe skip)
                    _StepHeader(
                      step: _step,
                      totalSteps: totalSteps,
                    ),

                    const SizedBox(height: 20),

                    // Glass card with form / text
                    Expanded(
                      child: _GlassCard(
                        child: AnimatedSwitcher(
                          duration:
                          const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _buildStepContent(
                            context,
                            colorScheme,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // error line
                    if (_err != null)
                      Padding(
                        padding:
                        const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _err!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // primary CTA button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: ButtonStyle(
                          padding:
                          WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                          ),
                          backgroundColor:
                          WidgetStateProperty.resolveWith(
                                (states) {
                              if (_busy) {
                                return Colors.white
                                    .withOpacity(0.2);
                              }
                              return Colors.white;
                            },
                          ),
                          foregroundColor:
                          WidgetStateProperty.all(
                            Colors.black,
                          ),
                          shape:
                          WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        onPressed: _busy ? null : _handlePrimaryTap,
                        child: _busy
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(Colors.black),
                          ),
                        )
                            : Text(
                          _primaryCtaText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // subtle footer
                    Text(
                      _step < 4
                          ? 'You only do this once.'
                          : 'Welcome to your new POS.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
      BuildContext context,
      ColorScheme scheme,
      ) {
    switch (_step) {
      case 0:
        return _WelcomeStep();
      case 1:
        return _AdminStep(
          formKey: _formAdmin,
          tenantName: _tenantName,
          adminName: _adminName,
          mobile: _mobile,
          email: _email,
          password: _password,
          pin: _pin,
          appSecret: _appSecret,
        );
      case 2:
        return _BranchStep(
          formKey: _formBranch,
          tenantId: _tenantId,
          branchName: _branchName,
          branchPhone: _branchPhone,
          branchGstin: _branchGstin,
          branchState: _branchState,
          branchAddr: _branchAddr,
        );
      case 3:
        return _BrandStep(
          formKey: _formBrand,
          branchId: _branchId,
          restName: _restName,
          restPhone: _restPhone,
          restAddr: _restAddr,
        );
      case 4:
      default:
        return _DoneStep(
          mobile: _finalMobile,
          password: _finalPassword,
        );
    }
  }
}

// ─────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  const _StepHeader({
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final isWelcome = step == 0;
    final isDone = step >= 4;
    final pillText = isWelcome
        ? 'Setup'
        : isDone
        ? 'Ready'
        : 'Step $step of $totalSteps';

    return Row(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 1,
            ),
          ),
          child: Text(
            pillText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        // tiny dot indicators (1..3 only)
        if (!isWelcome && !isDone)
          Row(
            children: List.generate(
              totalSteps,
                  (i) {
                // steps visible are 1..3 (admin/branch/brand)
                // We'll map 1->0,2->1,3->2 for dots
                final visibleStepIdx = step - 1;
                final active = i == visibleStepIdx;
                return Container(
                  width: 6,
                  height: 6,
                  margin:
                  const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Frosted glass card wrapper
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Welcome screen
class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Let's set up your restaurant.",
          style: txt.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          "We'll create your owner account, your first branch, "
              "printers, and kitchen stations.\n\n"
              "In a few taps, you're ready to bill, print KOTs, "
              "and run service.",
          style: txt.bodyMedium,
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            "This is the start.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// Step 1: Admin / Owner
class _AdminStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController appSecret;
  final TextEditingController tenantName;
  final TextEditingController adminName;
  final TextEditingController mobile;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController pin;

  const _AdminStep({
    super.key,
    required this.formKey,
    required this.appSecret,
    required this.tenantName,
    required this.adminName,
    required this.mobile,
    required this.email,
    required this.password,
    required this.pin,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const ValueKey('admin'),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Who runs this place?",
                style: txt.headlineSmall),
            const SizedBox(height: 8),
            Text(
              "We'll make the main account with full access.",
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: appSecret,
              decoration: const InputDecoration(
                labelText: 'Setup Secret',
                hintText: 'Ask your installer / owner',
              ),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: tenantName,
              decoration: const InputDecoration(
                labelText: 'Restaurant / Group Name',
              ),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: adminName,
                    decoration: const InputDecoration(
                      labelText: 'Owner Name',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: pin,
              decoration: const InputDecoration(
                labelText: '4-digit POS PIN',
                hintText: 'For quick auth on counter',
              ),
              validator: (v) =>
              (v == null || v.length != 4)
                  ? 'Enter 4 digits'
                  : null,
            ),

            const SizedBox(height: 24),
            Text(
              "This becomes your admin login.",
              style: txt.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Step 2: Branch
class _BranchStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? tenantId;
  final TextEditingController branchName;
  final TextEditingController branchPhone;
  final TextEditingController branchGstin;
  final TextEditingController branchState;
  final TextEditingController branchAddr;

  const _BranchStep({
    super.key,
    required this.formKey,
    required this.tenantId,
    required this.branchName,
    required this.branchPhone,
    required this.branchGstin,
    required this.branchState,
    required this.branchAddr,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const ValueKey('branch'),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Where are you serving?",
                style: txt.headlineSmall),
            const SizedBox(height: 8),
            Text(
              "Your first outlet / branch.",
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 16),

            Text(
              'Tenant: ${tenantId ?? "-"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: branchName,
              decoration: const InputDecoration(
                labelText: 'Branch Name',
                hintText: 'e.g. Tandoor Express - Andheri',
              ),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: branchPhone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: branchGstin,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: branchState,
                    decoration: const InputDecoration(
                      labelText: 'State Code',
                      hintText: 'MH / KA / DL ...',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: branchAddr,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              "We'll use this on invoices and tax reports.",
              style: txt.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Step 3: Brand & Printers
class _BrandStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? branchId;
  final TextEditingController restName;
  final TextEditingController restPhone;
  final TextEditingController restAddr;

  const _BrandStep({
    super.key,
    required this.formKey,
    required this.branchId,
    required this.restName,
    required this.restPhone,
    required this.restAddr,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const ValueKey('brand'),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Brand & printing",
                style: txt.headlineSmall),
            const SizedBox(height: 8),
            Text(
              "Your receipt header, KOT routing, cash drawer — "
                  "we’ll seed defaults you can tweak later.",
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 16),

            Text(
              'Branch: ${branchId ?? "-"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: restName,
              decoration: const InputDecoration(
                labelText: 'Restaurant Display Name',
                hintText: 'Shown on bills',
              ),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: restPhone,
                    decoration: const InputDecoration(
                      labelText: 'Phone on Bill',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: restAddr,
                    decoration: const InputDecoration(
                      labelText: 'Address on Bill',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              "We'll also create:\n"
                  "• A billing printer (with cash drawer)\n"
                  "• A kitchen printer + Main station\n\n"
                  "You can add more stations later — Tandoor, Wok, Bar…",
              style: txt.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Step 4: Done
class _DoneStep extends StatelessWidget {
  final String mobile;
  final String password;

  const _DoneStep({
    super.key,
    required this.mobile,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('done'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "You're in.",
          style: txt.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          "Your POS is ready to take orders, print KOTs, "
              "and close bills.",
          style: txt.bodyMedium,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 1,
            ),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Login details",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text("Mobile: $mobile"),
                Text("Password: $password"),
                const SizedBox(height: 8),
                Text(
                  "Keep this safe.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            "See you on the floor 👋",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }
}
