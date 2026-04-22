import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for managing home screen widgets
class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('com.nanobanana/home_widget');
  static bool _isSupported = false;

  /// Initialize home widget service
  static Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      _isSupported = result ?? false;
    } on MissingPluginException {
      _isSupported = false;
    } on PlatformException {
      _isSupported = false;
    }
  }

  /// Check if home widgets are supported on this platform
  static bool get isSupported => _isSupported;

  /// Update the quick actions widget
  static Future<bool> updateQuickActionsWidget({
    required int pendingCount,
    required String lastPrompt,
    required DateTime? lastGeneratedAt,
  }) async {
    if (!_isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('updateQuickActions', {
        'pendingCount': pendingCount,
        'lastPrompt': lastPrompt,
        'lastGeneratedAt': lastGeneratedAt?.millisecondsSinceEpoch ?? 0,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Update the statistics widget
  static Future<bool> updateStatsWidget({
    required int totalGenerated,
    required int successCount,
    required double successRate,
    required String preferredModel,
  }) async {
    if (!_isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('updateStats', {
        'totalGenerated': totalGenerated,
        'successCount': successCount,
        'successRate': successRate,
        'preferredModel': preferredModel,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Request to pin a widget (Android only)
  static Future<bool> requestPinWidget(String widgetType) async {
    if (!_isSupported || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Show widget configuration dialog
  static Future<void> showWidgetConfigDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.widgets_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '桌面小部件',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '添加小部件到主屏幕',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (Platform.isAndroid)
                _WidgetTypeCard(
                  icon: Icons.bolt,
                  title: '快速操作',
                  description: '一键生成、查看队列、快捷输入',
                  onTap: () => requestPinWidget('quick_actions'),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('长按桌面空白处，点击"+"添加小部件'),
                ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 12),
                _WidgetTypeCard(
                  icon: Icons.analytics_outlined,
                  title: '生成统计',
                  description: '显示今日生成次数、成功率、常用模型',
                  onTap: () => requestPinWidget('stats'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetTypeCard extends StatelessWidget {
  const _WidgetTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: InkWell(
        onTap: () {
          onTap();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
