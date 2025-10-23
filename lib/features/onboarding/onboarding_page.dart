import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  final _form3 = GlobalKey<FormState>();

  // Inputs
  final _appSecret = TextEditingController();
  final _tenantName = TextEditingController(text: 'Restaurant Demo');
  final _adminName  = TextEditingController(text: 'Owner');
  final _mobile     = TextEditingController(text: '98XXXXXXXX');
  final _email      = TextEditingController();
  final _password   = TextEditingController(text: 'admin');
  final _pin        = TextEditingController(text: '1234');

  final _branchName = TextEditingController(text: 'Main Branch');
  final _branchPhone= TextEditingController(text: '1800123000');
  final _branchGstin= TextEditingController(text: '27AAAAA0000A1Z5');
  final _branchState= TextEditingController(text: 'MH');
  final _branchAddr = TextEditingController(text: 'Road 1');

  final _restName   = TextEditingController(text: 'Restaurant Main');
  final _restPhone  = TextEditingController(text: '1800123000');
  final _restAddr   = TextEditingController(text: 'Road 1');

  String? _tenantId;
  String? _branchId;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [
      _appSecret, _tenantName, _adminName, _mobile, _email, _password, _pin,
      _branchName, _branchPhone, _branchGstin, _branchState, _branchAddr,
      _restName, _restPhone, _restAddr,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _step1() async {
    if (!_form1.currentState!.validate()) return;
    setState((){_busy=true; _err=null;});
    final client = ref.read(apiClientProvider);
    try {
      final admin = await client.onboardAdmin(
        appSecret: _appSecret.text.trim(),
        tenantName: _tenantName.text.trim(),
        adminName: _adminName.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _password.text,
        pin: _pin.text,
      );
      _tenantId = admin['tenant_id'] as String?;
    } catch (e) {
      _err = e.toString();
    } finally {
      setState((){_busy=false;});
    }
  }

  Future<void> _step2() async {
    if (!_form2.currentState!.validate()) return;
    setState((){_busy=true; _err=null;});
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
    } catch (e) {
      _err = e.toString();
    } finally {
      setState((){_busy=false;});
    }
  }

  Future<void> _step3() async {
    if (!_form3.currentState!.validate()) return;
    setState((){_busy=true; _err=null;});
    final client = ref.read(apiClientProvider);
    try {
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

      // quick printers
      await client.onboardPrinters(
        appSecret: _appSecret.text.trim(),
        tenantId: _tenantId!,
        branchId: _branchId!,
        payload: {
          'billing': {
            'name': 'Billing',
            'connection_url': 'http://localhost:9100/agent',
            'is_default': true,
            'cash_drawer_enabled': true,
            'cash_drawer_code': 'PULSE_2_100',
          },
          'kitchen': [
            {
              'name': 'Kitchen-1',
              'connection_url': 'http://localhost:9101/agent',
              'is_default': true,
              'stations': ['Main']
            }
          ]
        },
      );

      await client.onboardFinish(appSecret: _appSecret.text.trim(), tenantId: _tenantId!);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Onboarding Complete'),
            content: Text('Tenant ready.\nLogin with:\nMobile: ${_mobile.text}\nPassword: ${_password.text}'),
            actions: [ TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK')) ],
          ),
        );
      }
    } catch (e) {
      _err = e.toString();
    } finally {
      setState((){_busy=false;});
    }
  }

  @override
  Widget build(BuildContext context) {
    final step1 = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Step 1 — Create Tenant & Admin', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(controller: _appSecret, decoration: const InputDecoration(labelText:'App Secret'), validator:(v)=>v==null||v.isEmpty?'Required':null),
              TextFormField(controller: _tenantName, decoration: const InputDecoration(labelText:'Tenant Name'), validator:(v)=>v==null||v.isEmpty?'Required':null),
              Row(children:[
                Expanded(child: TextFormField(controller: _adminName, decoration: const InputDecoration(labelText:'Admin Name'), validator:(v)=>v==null||v.isEmpty?'Required':null)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _mobile, decoration: const InputDecoration(labelText:'Mobile'), keyboardType: TextInputType.phone, validator:(v)=>v==null||v.isEmpty?'Required':null)),
              ]),
              Row(children:[
                Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText:'Email (optional)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _password, decoration: const InputDecoration(labelText:'Password'), obscureText: true, validator:(v)=>v==null||v.isEmpty?'Required':null)),
              ]),
              TextFormField(controller: _pin, decoration: const InputDecoration(labelText:'PIN (4 digits)'), validator:(v)=>v==null||v.length!=4?'Enter 4-digit PIN':null),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _step1,
                child: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
                    : const Text('Create Admin'),
              ),
            ],
          ),
        ),
      ),
    );

    final step2 = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Step 2 — Create First Branch', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Tenant ID: ${_tenantId ?? "-"}'),
              const SizedBox(height: 8),
              TextFormField(controller: _branchName, decoration: const InputDecoration(labelText:'Branch Name'), validator:(v)=>v==null||v.isEmpty?'Required':null),
              Row(children:[
                Expanded(child: TextFormField(controller: _branchPhone, decoration: const InputDecoration(labelText:'Phone'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _branchGstin, decoration: const InputDecoration(labelText:'GSTIN'))),
              ]),
              Row(children:[
                Expanded(child: TextFormField(controller: _branchState, decoration: const InputDecoration(labelText:'State Code (e.g. MH)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _branchAddr, decoration: const InputDecoration(labelText:'Address'))),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || _tenantId==null ? null : _step2,
                child: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
                    : const Text('Create Branch'),
              ),
            ],
          ),
        ),
      ),
    );

    final step3 = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Step 3 — Restaurant Settings & Printers', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Branch ID: ${_branchId ?? "-"}'),
              const SizedBox(height: 8),
              TextFormField(controller: _restName, decoration: const InputDecoration(labelText:'Restaurant Name'), validator:(v)=>v==null||v.isEmpty?'Required':null),
              Row(children:[
                Expanded(child: TextFormField(controller: _restPhone, decoration: const InputDecoration(labelText:'Phone'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _restAddr, decoration: const InputDecoration(labelText:'Address'))),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || _branchId==null ? null : _step3,
                child: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
                    : const Text('Finish & Seed Printers'),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding (Admin)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_err != null) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_err!, style: const TextStyle(color: Colors.red)),
            ),
            step1,
            const SizedBox(height: 12),
            step2,
            const SizedBox(height: 12),
            step3,
          ],
        ),
      ),
    );
  }
}
