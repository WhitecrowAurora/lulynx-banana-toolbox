import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class HomeMessageImage extends StatelessWidget {
  const HomeMessageImage({
    super.key,
    this.imageUrl,
    this.imageBytes,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl ?? '';
    const imageHeight = 220.0;

    Widget content;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      content = Image.memory(
        imageBytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    } else if (resolvedImageUrl.startsWith('http')) {
      content = CachedNetworkImage(
        imageUrl: resolvedImageUrl,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 140),
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined, size: 22)),
      );
    } else if (resolvedImageUrl.isNotEmpty) {
      content = Image.file(
        File(resolvedImageUrl),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 120),
            child: child,
          );
        },
        errorBuilder: (context, _, __) =>
            const Center(child: Icon(Icons.broken_image_outlined, size: 22)),
      );
    } else {
      content =
          const Center(child: Icon(Icons.image_not_supported_outlined, size: 22));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: imageHeight,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: content,
      ),
    );
  }
}
