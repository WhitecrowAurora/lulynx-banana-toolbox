import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_i18n.dart';
import '../models/chat_models.dart';
import '../providers/providers.dart';
import '../services/share_service.dart';

class HistoryGenerationsScreen extends ConsumerStatefulWidget {
  const HistoryGenerationsScreen({super.key});

  @override
  ConsumerState<HistoryGenerationsScreen> createState() => _HistoryGenerationsScreenState();
}

class _HistoryGenerationsScreenState extends ConsumerState<HistoryGenerationsScreen> {
  final Set<int> _selectedItems = {};
  bool _isSelectionMode = false;

  String _tr(String zh, {Map<String, Object?> args = const {}}) =>
      context.tr(zh, args: args);

  void _enterSelectionMode(int initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedItems.add(initialId);
    });
    HapticFeedback.lightImpact();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(id);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAll(List<HistoryGenerationItem> items) {
    setState(() {
      _selectedItems.addAll(items.map((e) => e.messageId));
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _shareSelected(List<HistoryGenerationItem> items) async {
    if (_selectedItems.isEmpty) return;
    final selectedItems = items.where((e) => _selectedItems.contains(e.messageId)).toList();

    HapticFeedback.mediumImpact();
    final config = ref.read(apiConfigProvider);

    var successCount = 0;
    for (final item in selectedItems) {
      final bytes = await _loadImageBytes(item.imageUrl);
      if (bytes != null && bytes.isNotEmpty) {
        final success = await ShareService.shareImage(
          imageBytes: bytes,
          text: item.prompt,
          subject: 'Nano Banana Generated Image',
          fileName: 'NanoBanana_${item.messageId}.png',
          signature: config.shareSignature.isEmpty ? null : config.shareSignature,
        );
        if (success) successCount++;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('已分享 {count} 张图片', args: {'count': '$successCount'}))),
    );
    _exitSelectionMode();
  }

  Future<Uint8List?> _loadImageBytes(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;

    if (imageUrl.startsWith('http')) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(imageUrl));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          client.close();
          return null;
        }
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
        }
        client.close();
        return builder.toBytes();
      } catch (_) {
        return null;
      }
    }

    try {
      final file = File(imageUrl);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyPrompt(String prompt) async {
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted || Platform.isAndroid) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('提示词已复制'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = ref.watch(_historyItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(_tr('已选择 {count} 项', args: {'count': '${_selectedItems.length}'}))
            : Text(_tr('历史生成')),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: _tr('全选'),
                  onPressed: () {
                    future.whenData((items) => _selectAll(items));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: _tr('批量分享'),
                  onPressed: () {
                    future.whenData((items) => _shareSelected(items));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: _tr('取消选择'),
                  onPressed: _exitSelectionMode,
                ),
              ]
            : null,
      ),
      body: future.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(_tr('暂无历史生成记录')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _selectedItems.contains(item.messageId);

              return _HistoryListItem(
                item: item,
                isSelectionMode: _isSelectionMode,
                isSelected: isSelected,
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(item.messageId);
                  } else {
                    Navigator.pop(
                      context,
                      HistoryGenerationAction.openOriginal(item),
                    );
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    _enterSelectionMode(item.messageId);
                  }
                },
                onShare: () => _shareSelected([item]),
                onGenerateAgain: () => Navigator.pop(
                  context,
                  HistoryGenerationAction.generateAgain(item),
                ),
                onCopyPrompt: () => _copyPrompt(item.prompt),
                tr: _tr,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_tr('历史生成加载失败: {error}', args: {'error': '$error'})),
          ),
        ),
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onGenerateAgain,
    required this.onCopyPrompt,
    required this.tr,
  });

  final HistoryGenerationItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onGenerateAgain;
  final VoidCallback onCopyPrompt;
  final String Function(String, {Map<String, Object?> args}) tr;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? colorScheme.primary : colorScheme.outline,
                  ),
                ),
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
                    if (!isSelectionMode)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: onShare,
                            icon: const Icon(Icons.share),
                            label: Text(tr('分享')),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: onGenerateAgain,
                            icon: const Icon(Icons.refresh),
                            label: Text(tr('再次生成')),
                          ),
                          OutlinedButton.icon(
                            onPressed: onCopyPrompt,
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
  }

  static String _formatTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
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
