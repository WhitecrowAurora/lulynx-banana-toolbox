import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_i18n.dart';
import '../models/chat_models.dart';
import '../providers/providers.dart';

class HistoryGenerationsScreen extends ConsumerWidget {
  const HistoryGenerationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(_historyItemsProvider);
    String tr(String zh, {Map<String, Object?> args = const {}}) =>
        context.tr(zh, args: args);

    return Scaffold(
      appBar: AppBar(title: Text(tr('历史生成'))),
      body: future.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(tr('暂无历史生成记录')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(
                    context,
                    HistoryGenerationAction.openOriginal(item),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: _HistoryThumbnail(imageUrl: item.imageUrl),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.prompt,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.sessionTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(item.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      HistoryGenerationAction.openOriginal(item),
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(tr('查看原消息')),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      HistoryGenerationAction.generateAgain(item),
                                    ),
                                    icon: const Icon(Icons.refresh),
                                    label: Text(tr('再次生成')),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _copyPrompt(context, item.prompt),
                                    icon: const Icon(Icons.content_copy_outlined),
                                    label: Text(tr('复制提示词')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(tr('历史生成加载失败: {error}', args: {'error': '$error'})),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _copyPrompt(BuildContext context, String prompt) async {
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!context.mounted || Platform.isAndroid) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(context.tr('提示词已复制'))),
    );
  }
}

enum HistoryGenerationActionType { openOriginal, generateAgain }

class HistoryGenerationAction {
  const HistoryGenerationAction({
    required this.type,
    required this.item,
  });

  final HistoryGenerationActionType type;
  final HistoryGenerationItem item;

  factory HistoryGenerationAction.openOriginal(HistoryGenerationItem item) {
    return HistoryGenerationAction(
      type: HistoryGenerationActionType.openOriginal,
      item: item,
    );
  }

  factory HistoryGenerationAction.generateAgain(HistoryGenerationItem item) {
    return HistoryGenerationAction(
      type: HistoryGenerationActionType.generateAgain,
      item: item,
    );
  }
}

final _historyItemsProvider =
    FutureProvider<List<HistoryGenerationItem>>((ref) async {
  return ref.read(chatDatabaseProvider).getRecentGeneratedHistory();
});

class _HistoryThumbnail extends StatelessWidget {
  const _HistoryThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = imageUrl ?? '';
    if (resolved.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }
    if (resolved.startsWith('http')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return Image.file(
      File(resolved),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
