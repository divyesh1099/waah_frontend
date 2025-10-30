import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/repo/catalog_repo.dart';

/// ------------------------------------------------------------
/// Helper: robust media URL resolver
/// ------------------------------------------------------------
String? _resolveMediaUrl(String? path, String mediaBaseUrl, String baseUrl) {
  if (path == null) return null;
  final p = path.trim();
  if (p.isEmpty) return null;

  // Already absolute
  if (p.startsWith('http://') || p.startsWith('https://')) return p;

  // Common backend returns
  // 1) "/media/uuid.jpg"  2) "media/uuid.jpg"  3) "uuid.jpg"
  final mb = mediaBaseUrl.endsWith('/') ? mediaBaseUrl : '$mediaBaseUrl/';
  if (p.startsWith('/media/')) return mb + p.substring('/media/'.length);
  if (p.startsWith('media/')) return mb + p.substring('media/'.length);

  // If server ever returned a root-relative path ("/something.jpg") that's
  // not under /media, fall back to baseUrl + p
  if (p.startsWith('/')) {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$b$p';
  }

  // Bare filename -> treat as media path
  return mb + p;
}

Widget _placeholderBox({double? radius, double? size, BorderRadius? r}) {
  final child = Icon(Icons.image, size: (size ?? 48) * 0.66, color: Colors.grey);
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: r ?? (radius != null ? BorderRadius.circular(radius) : null),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Center(child: child),
  );
}

/// ------------------------------------------------------------
/// MenuImage: square thumbnail with rounded corners
/// ------------------------------------------------------------
class MenuImage extends ConsumerWidget {
  const MenuImage({super.key, required this.path, this.size = 56, this.radius = 8});
  final String? path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaBase = ref.watch(mediaBaseUrlProvider);
    final baseUrl = kBaseUrl; // from providers.dart
    final url = _resolveMediaUrl(path, mediaBase, baseUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _placeholderBox(size: size)
            : Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholderBox(size: size),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// MenuAvatar: circular variant for tiny avatars
/// ------------------------------------------------------------
class MenuAvatar extends ConsumerWidget {
  const MenuAvatar({super.key, required this.path, this.size = 32});
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaBase = ref.watch(mediaBaseUrlProvider);
    final baseUrl = kBaseUrl;
    final url = _resolveMediaUrl(path, mediaBase, baseUrl);

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _placeholderBox(size: size)
            : Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholderBox(size: size),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// MenuBannerImage: full-width banner style with optional radius
/// ------------------------------------------------------------
class MenuBannerImage extends ConsumerWidget {
  const MenuBannerImage({super.key, required this.path, this.borderRadius = 8});
  final String? path;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaBase = ref.watch(mediaBaseUrlProvider);
    final baseUrl = kBaseUrl;
    final url = _resolveMediaUrl(path, mediaBase, baseUrl);

    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: url == null
            ? _placeholderBox(r: radius)
            : Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholderBox(r: radius),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// MenuImageUploaderField
/// - Shows a preview
/// - Lets user paste/edit a URL
/// - Optional: if itemId provided, will upload a picked file via CatalogRepo
///   using repo.uploadItemImage(itemId: itemId, file: PlatformFile)
///   and then call onChanged(newUrl?)
/// ------------------------------------------------------------
class MenuImageUploaderField extends ConsumerStatefulWidget {
  const MenuImageUploaderField({
    super.key,
    required this.value,
    required this.onChanged,
    this.itemId,
    this.label = 'Item Photo',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? itemId; // pass item.id here to enable uploads
  final String label;

  @override
  ConsumerState<MenuImageUploaderField> createState() => _MenuImageUploaderFieldState();
}

class _MenuImageUploaderFieldState extends ConsumerState<MenuImageUploaderField> {
  late TextEditingController _urlCtl;
  Uint8List? _localPreviewBytes; // for picked file preview before/after upload
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlCtl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant MenuImageUploaderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && (_urlCtl.text != (widget.value ?? ''))) {
      _urlCtl.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    super.dispose();
  }

  Future<void> _pickAndMaybeUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() => _localPreviewBytes = file.bytes);

    // If no itemId, we can only preview; user should paste a URL or
    // re-open this widget with itemId to enable upload.
    if (widget.itemId == null || widget.itemId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Previewing selected image. To upload, provide itemId to MenuImageUploaderField.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(catalogRepoProvider);
      final dynamic resp = await repo.uploadItemImage(itemId: widget.itemId!, file: file);

      // Try to use returned URL if available
      String? newUrl;
      if (resp is String && resp.trim().isNotEmpty) {
        newUrl = resp.trim();
      } else if (resp is Map && resp['image_url'] is String) {
        newUrl = (resp['image_url'] as String).trim();
      }

      // If backend doesn't return URL, we still trigger change so that
      // caller can re-fetch the item and get the updated imageUrl.
      widget.onChanged(newUrl ?? _urlCtl.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded ✅')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    setState(() => _localPreviewBytes = null);
    _urlCtl.clear();
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final mediaBase = ref.watch(mediaBaseUrlProvider);
    final baseUrl = kBaseUrl;

    final resolvedUrl = _resolveMediaUrl(_urlCtl.text, mediaBase, baseUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: _localPreviewBytes != null
                ? Image.memory(_localPreviewBytes!, fit: BoxFit.cover)
                : (resolvedUrl == null
                ? _placeholderBox(r: BorderRadius.circular(8))
                : Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _placeholderBox(r: BorderRadius.circular(8)),
            )),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlCtl,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Image URL (or leave blank)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => widget.onChanged(v.trim().isEmpty ? null : v.trim()),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickAndMaybeUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick Image'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Clear',
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
        if (widget.itemId == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tip: To enable direct upload, pass itemId: MenuImageUploaderField(itemId: item.id, …)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
      ],
    );
  }
}
