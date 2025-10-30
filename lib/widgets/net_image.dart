import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  const NetImage(
      this.url, {
        super.key,
        this.height,
        this.width,
        this.fit,
        this.radius = 6,
        this.placeholderIcon = Icons.image,
      });

  final String? url;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    final has = u.startsWith('http');
    final clip = BorderRadius.circular(radius);

    Widget child;
    if (!has) {
      child = Icon(placeholderIcon, size: (height ?? 48) * .7);
    } else {
      child = Image.network(
        u,
        height: height,
        width: width,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(placeholderIcon, size: (height ?? 48) * .7),
      );
    }

    return ClipRRect(
      borderRadius: clip,
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        height: height,
        width: width,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
