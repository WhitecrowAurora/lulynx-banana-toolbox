import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/haptic_service.dart';

class ReferenceImagesPanel extends StatelessWidget {
  const ReferenceImagesPanel({
    super.key,
    required this.referenceImages,
    required this.previewExtent,
    required this.draggingReferenceIndex,
    required this.tr,
    required this.imageUiKeyBuilder,
    required this.onReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
    required this.onRemoveReference,
    required this.onClearReferences,
    this.hapticFeedbackEnabled = true,
  });

  final List<Uint8List> referenceImages;
  final double previewExtent;
  final int? draggingReferenceIndex;
  final String Function(String, {Map<String, Object?> args}) tr;
  final String Function(Uint8List) imageUiKeyBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onReorderStart;
  final void Function(int index) onReorderEnd;
  final void Function(int index) onRemoveReference;
  final VoidCallback onClearReferences;
  final bool hapticFeedbackEnabled;

  void _hapticDragStart() {
    if (hapticFeedbackEnabled) {
      HapticService.dragStart();
    }
  }

  void _hapticDragEnd() {
    if (hapticFeedbackEnabled) {
      HapticService.dragEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (referenceImages.isEmpty) return const SizedBox.shrink();

    final scale = previewExtent / 72.0;
    final panelPadding = (8 * scale).clamp(6.0, 12.0);
    final panelRadius = (10 * scale).clamp(8.0, 14.0);
    final rowHeight = previewExtent;
    final counterExtent = (previewExtent * 0.76).clamp(40.0, 68.0);
    final sideGap = (6 * scale).clamp(4.0, 10.0);
    final itemGap = (8 * scale).clamp(6.0, 12.0);
    final thumbRadius = (8 * scale).clamp(6.0, 12.0);
    final closeOffset = (2 * scale).clamp(1.0, 4.0);
    final closePadding = (3 * scale).clamp(2.0, 5.0);
    final closeIconSize = (14 * scale).clamp(12.0, 18.0);
    final clearButtonWidth = (42 * scale).clamp(36.0, 52.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(panelPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(panelRadius),
      ),
      child: Row(
        children: [
          Container(
            width: counterExtent,
            height: rowHeight,
            padding: EdgeInsets.symmetric(
              horizontal: (4 * scale).clamp(3.0, 6.0),
              vertical: (4 * scale).clamp(3.0, 6.0),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(thumbRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr('参考图'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (10 * scale).clamp(9.0, 12.0),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  tr('{count} 张', args: {'count': referenceImages.length}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (11 * scale).clamp(10.0, 14.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: sideGap),
          Expanded(
            child: SizedBox(
              height: rowHeight,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: referenceImages.length,
                padding: EdgeInsets.zero,
                onReorder: onReorder,
                onReorderStart: (index) {
                  _hapticDragStart();
                  onReorderStart(index);
                },
                onReorderEnd: (index) {
                  _hapticDragEnd();
                  onReorderEnd(index);
                },
                proxyDecorator: (child, _, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(animation.value);
                      return Transform.scale(
                        scale: 1 + (0.04 * t),
                        child: child,
                      );
                    },
                  );
                },
                itemBuilder: (context, index) {
                  final image = referenceImages[index];
                  final imageKey = imageUiKeyBuilder(image);
                  final isDragging = draggingReferenceIndex == index;
                  final rightGap =
                      index == referenceImages.length - 1 ? 0.0 : itemGap;

                  return Container(
                    key: ValueKey('ref-thumb-$imageKey'),
                    width: previewExtent + rightGap,
                    padding: EdgeInsets.only(right: rightGap),
                    alignment: Alignment.centerLeft,
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(thumbRadius + 1),
                          boxShadow: isDragging
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.16),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : const [],
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          opacity: isDragging ? 0.86 : 1,
                          child: Stack(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: ClipRRect(
                                  key: ValueKey('ref-image-$imageKey'),
                                  borderRadius:
                                      BorderRadius.circular(thumbRadius),
                                  child: Image.memory(
                                    image,
                                    width: previewExtent,
                                    height: previewExtent,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: closeOffset,
                                right: closeOffset,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => onRemoveReference(index),
                                    child: Padding(
                                      padding: EdgeInsets.all(closePadding),
                                      child: Icon(
                                        Icons.close,
                                        size: closeIconSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: sideGap),
          SizedBox(
            width: clearButtonWidth,
            height: rowHeight,
            child: TextButton(
              onPressed: referenceImages.isNotEmpty ? onClearReferences : null,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size(clearButtonWidth, rowHeight),
                padding: EdgeInsets.zero,
                textStyle: TextStyle(fontSize: (11 * scale).clamp(10.0, 13.0)),
              ),
              child: Text(tr('清空')),
            ),
          ),
        ],
      ),
    );
  }
}
