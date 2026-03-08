import 'dart:typed_data';

import 'package:flutter/material.dart';

class SettingsQualityPreviewCard extends StatelessWidget {
  const SettingsQualityPreviewCard({
    super.key,
    required this.originalBytes,
    required this.compressedBytes,
    required this.imageName,
    required this.errorText,
    required this.isLoading,
    required this.split,
    required this.title,
    required this.pickButtonLabel,
    required this.dragHintText,
    required this.emptyHintText,
    required this.fileNameLabel,
    required this.unnamedLabel,
    required this.originalOnlyLabel,
    required this.comparisonLabel,
    required this.previewFailedText,
    required this.originalTag,
    required this.compressedTag,
    required this.onPickImage,
    required this.onSplitChanged,
    required this.formatBytes,
  });

  final Uint8List? originalBytes;
  final Uint8List? compressedBytes;
  final String? imageName;
  final String? errorText;
  final bool isLoading;
  final double split;
  final String title;
  final String pickButtonLabel;
  final String dragHintText;
  final String emptyHintText;
  final String fileNameLabel;
  final String unnamedLabel;
  final String originalOnlyLabel;
  final String comparisonLabel;
  final String previewFailedText;
  final String originalTag;
  final String compressedTag;
  final VoidCallback onPickImage;
  final ValueChanged<double> onSplitChanged;
  final String Function(int bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    final original = originalBytes;
    final compressed = compressedBytes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(pickButtonLabel),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dragHintText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            if (original == null || original.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(emptyHintText),
              )
            else ...[
              Text(
                fileNameLabel.replaceFirst('{name}', imageName ?? unnamedLabel),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                compressed == null
                    ? originalOnlyLabel.replaceFirst(
                        '{original}',
                        formatBytes(original.length),
                      )
                    : comparisonLabel
                        .replaceFirst('{original}', formatBytes(original.length))
                        .replaceFirst(
                          '{compressed}',
                          formatBytes(compressed.length),
                        ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 240,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : compressed == null || compressed.isEmpty
                          ? Center(child: Text(previewFailedText))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final splitX = width * split;
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapDown: (details) {
                                    onSplitChanged(
                                      (details.localPosition.dx / width)
                                          .clamp(0.05, 0.95),
                                    );
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    onSplitChanged(
                                      (split + details.delta.dx / width)
                                          .clamp(0.05, 0.95),
                                    );
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        original,
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                      ),
                                      ClipRect(
                                        clipper: _PreviewRightClipper(split),
                                        child: Image.memory(
                                          compressed,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                      Positioned(
                                        left: splitX - 1,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 2,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Positioned(
                                        left: splitX - 14,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.black45,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.drag_indicator,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: _PreviewTag(text: originalTag),
                                      ),
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: _PreviewTag(text: compressedTag),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
              if ((errorText ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

class _PreviewRightClipper extends CustomClipper<Rect> {
  const _PreviewRightClipper(this.split);

  final double split;

  @override
  Rect getClip(Size size) {
    final left = (size.width * split).clamp(0.0, size.width);
    return Rect.fromLTWH(left, 0, size.width - left, size.height);
  }

  @override
  bool shouldReclip(covariant _PreviewRightClipper oldClipper) {
    return oldClipper.split != split;
  }
}
