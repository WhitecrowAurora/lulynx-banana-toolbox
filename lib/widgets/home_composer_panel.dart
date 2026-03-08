import 'package:flutter/material.dart';

class HomeComposerPanel extends StatelessWidget {
  const HomeComposerPanel({
    super.key,
    required this.showBalanceOnHome,
    required this.balanceCard,
    required this.queuePanel,
    required this.hasQueue,
    required this.showGeneratingHint,
    required this.generatingHint,
    required this.hasReferenceImages,
    required this.referenceImagesPanel,
    required this.modelLabel,
    required this.aspectRatioLabel,
    this.imageSizeLabel,
    required this.onPickModel,
    required this.onPickAspect,
    this.onPickImageSize,
    required this.onPickImage,
    required this.promptController,
    required this.promptHintText,
    required this.onSubmitted,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
  });

  final bool showBalanceOnHome;
  final Widget balanceCard;
  final Widget queuePanel;
  final bool hasQueue;
  final bool showGeneratingHint;
  final Widget generatingHint;
  final bool hasReferenceImages;
  final Widget referenceImagesPanel;
  final String modelLabel;
  final String aspectRatioLabel;
  final String? imageSizeLabel;
  final VoidCallback onPickModel;
  final VoidCallback onPickAspect;
  final VoidCallback? onPickImageSize;
  final VoidCallback onPickImage;
  final TextEditingController promptController;
  final String promptHintText;
  final ValueChanged<String> onSubmitted;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBalanceOnHome) balanceCard,
          if (showBalanceOnHome) const SizedBox(height: 8),
          queuePanel,
          if (hasQueue) const SizedBox(height: 8),
          if (showGeneratingHint) generatingHint,
          if (showGeneratingHint) const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: hasReferenceImages
                ? Column(
                    key: const ValueKey('refs-panel-visible'),
                    children: [
                      referenceImagesPanel,
                      const SizedBox(height: 8),
                    ],
                  )
                : const SizedBox.shrink(
                    key: ValueKey('refs-panel-hidden'),
                  ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(modelLabel),
                  onPressed: onPickModel,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.aspect_ratio, size: 14),
                  label: Text(aspectRatioLabel),
                  onPressed: onPickAspect,
                ),
                if (imageSizeLabel != null && onPickImageSize != null) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.hd, size: 14),
                    label: Text(imageSizeLabel!),
                    onPressed: onPickImageSize,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filled(
                onPressed: onPickImage,
                icon: const Icon(Icons.add_photo_alternate),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: promptController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: promptHintText,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isLoading ? onStop : onSend,
                icon: Icon(isLoading ? Icons.stop : Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
