import 'package:flutter/material.dart';
import '../models/generation_queue_task.dart';
import '../services/haptic_service.dart';

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.queue,
    required this.isLoading,
    required this.isExpanded,
    required this.isPeeking,
    required this.tr,
    required this.queueStatusText,
    required this.onToggleExpanded,
    required this.onClearQueue,
    required this.onCancelTask,
    required this.onMoveToFront,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicateTask,
    required this.onEditPrompt,
    this.hapticFeedbackEnabled = true,
  });

  final List<GenerationQueueTask> queue;
  final bool isLoading;
  final bool isExpanded;
  final bool isPeeking;
  final String Function(String, {Map<String, Object?> args}) tr;
  final String Function(QueueTaskStatus status) queueStatusText;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClearQueue;
  final void Function(GenerationQueueTask task) onCancelTask;
  final void Function(GenerationQueueTask task) onMoveToFront;
  final void Function(GenerationQueueTask task) onMoveUp;
  final void Function(GenerationQueueTask task) onMoveDown;
  final void Function(GenerationQueueTask task) onDuplicateTask;
  final void Function(GenerationQueueTask task) onEditPrompt;
  final bool hapticFeedbackEnabled;

  void _hapticLight() {
    if (hapticFeedbackEnabled) {
      HapticService.light();
    }
  }

  void _hapticQueueAction() {
    if (hapticFeedbackEnabled) {
      HapticService.queueAction();
    }
  }

  void _hapticMoveToTop() {
    if (hapticFeedbackEnabled) {
      HapticService.moveToTop();
    }
  }

  void _hapticDelete() {
    if (hapticFeedbackEnabled) {
      HapticService.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) return const SizedBox.shrink();

    final pendingCount =
        queue.where((t) => t.status == QueueTaskStatus.pending).length;
    final showQueueDetail = isExpanded || isPeeking;
    const queueHeaderFontSize = 13.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${tr('队列')}: ${queue.length}',
                style: const TextStyle(fontSize: queueHeaderFontSize),
              ),
              if (isLoading) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tr('生成中，可继续提交'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ] else if (pendingCount > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '${tr('待处理')}: $pendingCount',
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
              ] else ...[
                const Spacer(),
              ],
              IconButton(
                onPressed: onToggleExpanded,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: isExpanded ? tr('收起队列') : tr('展开队列'),
                icon: Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                ),
              ),
              const SizedBox(width: 2),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12, height: 1.1),
                ),
                onPressed: pendingCount > 0 ? onClearQueue : null,
                child: Text(tr('清空队列')),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showQueueDetail
                ? Column(
                    children: [
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: isExpanded ? 220 : 150,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: queue.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final task = queue[index];
                            final isRunning = task.status == QueueTaskStatus.running;
                            final firstPendingIndex = queue.indexWhere(
                              (t) => t.status == QueueTaskStatus.pending,
                            );
                            final canMoveToFront = !isRunning &&
                                firstPendingIndex >= 0 &&
                                index > firstPendingIndex;
                            final canMoveUp = !isRunning && index > 0;
                            final canMoveDown =
                                !isRunning && index < queue.length - 1;

                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        child: Chip(
                                          label: Text(queueStatusText(task.status)),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isRunning
                                              ? Theme.of(context).colorScheme.primaryContainer
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (task.fromRetry)
                                        Chip(
                                          label: Text(tr('重试任务')),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () {
                                          _hapticDelete();
                                          onCancelTask(task);
                                        },
                                        icon: Icon(
                                          isRunning ? Icons.stop_circle : Icons.cancel,
                                        ),
                                        tooltip:
                                            isRunning ? tr('取消当前任务') : tr('移出队列'),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    task.prompt,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (task.referenceImages.isNotEmpty)
                                    Text(
                                      '${tr('参考图')}: ${task.referenceImages.length}',
                                    ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: canMoveToFront
                                            ? () {
                                                _hapticMoveToTop();
                                                onMoveToFront(task);
                                              }
                                            : null,
                                        icon: const Icon(Icons.vertical_align_top),
                                        tooltip: tr('置顶（下一位执行）'),
                                      ),
                                      IconButton(
                                        onPressed: canMoveUp
                                            ? () {
                                                _hapticQueueAction();
                                                onMoveUp(task);
                                              }
                                            : null,
                                        icon: const Icon(Icons.arrow_upward),
                                        tooltip: tr('上移'),
                                      ),
                                      IconButton(
                                        onPressed: canMoveDown
                                            ? () {
                                                _hapticQueueAction();
                                                onMoveDown(task);
                                              }
                                            : null,
                                        icon: const Icon(Icons.arrow_downward),
                                        tooltip: tr('下移'),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          _hapticQueueAction();
                                          onDuplicateTask(task);
                                        },
                                        icon: const Icon(Icons.copy_all),
                                        tooltip: tr('重复'),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: isRunning
                                            ? null
                                            : () {
                                                _hapticLight();
                                                onEditPrompt(task);
                                              },
                                        child: Text(tr('编辑提示词')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
