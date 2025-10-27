
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:waah_frontend/app/providers.dart';

// ---- URL helpers ----
String _resolveMediaUrl(String? path, WidgetRef ref) {
  if (path == null) return '';
  final p = path.trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http://') || p.startsWith('https://')) return p;

  final baseRaw = ref.read(mediaBaseUrlProvider);
  final base = baseRaw.endsWith('/') ? baseRaw.substring(0, baseRaw.length - 1) : baseRaw;
  final right = p.startsWith('/') ? p : '/$p';
  return '$base$right';
}

String _resolveUploadEndpoint(WidgetRef ref) {
  // Uses mediaBaseUrlProvider origin and posts to /api/media/upload
  // Example: https://api.example.com/api/media/upload
  final baseRaw = ref.read(mediaBaseUrlProvider);
  try {
    final u = Uri.parse(baseRaw);
    final origin = '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
    return '$origin/api/media/upload';
  } catch (_) {
    // Fallback if baseRaw isn't a full URI
    return '/api/media/upload';
  }
}

// ---- Display Widgets ----
class MenuImage extends ConsumerWidget {
  const MenuImage({super.key, required this.path, this.size = 56, this.radius = 10});
  final String? path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = _resolveMediaUrl(path, ref);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, size: size * .42, color: Colors.grey.shade600),
    );

    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (ctx, err, st) => placeholder,
      ),
    );
  }
}

class MenuBannerImage extends ConsumerWidget {
  const MenuBannerImage({super.key, required this.path, this.height = 180});
  final String? path;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = _resolveMediaUrl(path, ref);
    final border = BorderRadius.circular(14);

    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: border,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 40),
    );

    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: border,
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (c, e, s) => placeholder,
        loadingBuilder: (c, child, prog) => prog == null
            ? child
            : SizedBox(height: height, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }
}

// ---- Upload helpers & field ----
Future<String?> pickAndUploadMenuImage(WidgetRef ref) async {
  final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  final bytes = f.bytes; // withData: true ensures bytes on all platforms (avoid dart:io)
  if (bytes == null) return null;

  final uploadUrl = _resolveUploadEndpoint(ref);
  final req = http.MultipartRequest('POST', Uri.parse(uploadUrl));
  req.files.add(http.MultipartFile.fromBytes('file', bytes as Uint8List, filename: f.name));

  // Optional: send a tag to let backend group items under a folder
  req.fields['bucket'] = 'items';

  final streamed = await req.send();
  final body = await streamed.stream.bytesToString();
  if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      // Expecting { path: "/media/items/xxx.jpg", url?: "https://..." }
      final path = (map['path'] ?? map['url'])?.toString();
      return path;
    } catch (_) {
      // If backend just returns the path as a string
      return body.trim().isNotEmpty ? body.trim() : null;
    }
  }
  throw Exception('Upload failed (${streamed.statusCode}): $body');
}

class MenuImageUploaderField extends ConsumerStatefulWidget {
  const MenuImageUploaderField({super.key, required this.value, required this.onChanged});
  final String? value; // current path or URL
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<MenuImageUploaderField> createState() => _MenuImageUploaderFieldState();
}

class _MenuImageUploaderFieldState extends ConsumerState<MenuImageUploaderField> {
  bool _busy = false;

  Future<void> _doUpload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await pickAndUploadMenuImage(ref);
      if (path != null) widget.onChanged(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteUrl() async {
    final ctl = TextEditingController(text: widget.value ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image URL or /media path'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(hintText: 'https://...  or  /media/items/xyz.jpg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Use')),
        ],
      ),
    );
    if (res != null) widget.onChanged(res.isEmpty ? null : res);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuBannerImage(path: widget.value),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _doUpload,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: const Text('Upload image'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pasteUrl,
              icon: const Icon(Icons.link),
              label: const Text('Paste URL'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => widget.onChanged(null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}