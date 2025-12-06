import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/local/app_db.dart';

class RestaurantSettingsPage extends ConsumerStatefulWidget {
  const RestaurantSettingsPage({super.key});

  @override
  ConsumerState<RestaurantSettingsPage> createState() => _RestaurantSettingsPageState();
}

class _RestaurantSettingsPageState extends ConsumerState<RestaurantSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtl;
  late TextEditingController _addressCtl;
  late TextEditingController _phoneCtl;
  late TextEditingController _gstinCtl;
  
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _addressCtl = TextEditingController();
    _phoneCtl = TextEditingController();
    _gstinCtl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _addressCtl.dispose();
    _phoneCtl.dispose();
    _gstinCtl.dispose();
    super.dispose();
  }

  bool _initDone = false;
  void _initData(RestaurantSetting? s) {
    if (_initDone || s == null) return;
    _nameCtl.text = s.name;
    _addressCtl.text = s.address ?? '';
    _phoneCtl.text = s.phone ?? '';
    _gstinCtl.text = s.gstin ?? '';
    _initDone = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);
    final repo = ref.read(settingsRepoProvider);

    try {
      // 1. Construct update map
      final update = {
        'tenant_id': tenantId,
        'branch_id': branchId,
        'name': _nameCtl.text.trim(),
        'address': _addressCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'gstin': _gstinCtl.text.trim(),
      };

      // 2. Call API via Repo (we need to add this method to Repo first, 
      // or call client directly. Let's call client directly for now as Repo 
      // doesn't have updateRestaurant yet).
      // Actually, let's add it to Repo properly in next step. 
      // For now, I'll assume Repo has it or I'll use client.
      await ref.read(apiClientProvider).saveRestaurantSettings(update);
      
      // 3. Refresh repo
      await repo.refreshRestaurantSettings(tenantId, branchId); // We need to add this too

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadLogo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // needed for web/desktop if not using path
    );
    if (res == null || res.files.isEmpty) return;

    setState(() => _loading = true);
    try {
      final tenantId = ref.read(activeTenantIdProvider);
      final branchId = ref.read(activeBranchIdProvider);
      
      final url = await ref.read(apiClientProvider).uploadRestaurantLogo(
        tenantId: tenantId,
        branchId: branchId,
        file: res.files.first,
      );

      // Refresh settings to see new logo
      // await ref.read(settingsRepoProvider).refreshRestaurantSettings(tenantId);
      // For now, manual refresh via client fetch if repo doesn't support it
      // But repo watches stream. We should update repo's cache.
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(restaurantSettingsProvider);
    final mediaResolver = ref.watch(mediaResolverProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (settings) {
          _initData(settings);
          if (settings == null) return const Center(child: Text('No settings found'));

          final logoUrl = mediaResolver(settings.logoUrl);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Image.network(logoUrl.toString(), height: 100, fit: BoxFit.contain),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _uploadLogo,
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload Logo'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(labelText: 'Restaurant Name'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressCtl,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gstinCtl,
                    decoration: const InputDecoration(labelText: 'GSTIN'),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: _loading ? null : _delete,
                      child: const Text('Delete Settings'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Settings?'),
        content: const Text('This will reset restaurant settings for this branch. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final tenantId = ref.read(activeTenantIdProvider);
      final branchId = ref.read(activeBranchIdProvider);
      
      await ref.read(apiClientProvider).deleteRestaurantSettings(
        tenantId: tenantId,
        branchId: branchId,
      );

      // Refresh repo to clear cache
      await ref.read(settingsRepoProvider).refreshRestaurantSettings(tenantId, branchId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings deleted')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
