import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';

class EmptyState extends ConsumerWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to get dynamic logo
    final rs = ref.watch(restaurantSettingsProvider).valueOrNull;
    final buildUri = ref.read(mediaResolverProvider);
    final logoUrl = (rs?.logoUrl != null && rs!.logoUrl!.isNotEmpty)
        ? buildUri(rs.logoUrl).toString()
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  logoUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackLogo(),
                ),
              )
            else
              _fallbackLogo(),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }

  Widget _fallbackLogo() {
    // Use asset if it exists, else an icon
    return Image.asset(
      'assets/images/logo.png',
      width: 96,
      height: 96,
      errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
    );
  }
}
