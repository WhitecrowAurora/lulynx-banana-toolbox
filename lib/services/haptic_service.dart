import 'package:flutter/services.dart';

/// 振动反馈服务 - 提供丰富的触觉反馈体验
class HapticService {
  static bool _enabled = true;

  /// 是否启用振动
  static bool get enabled => _enabled;

  /// 设置是否启用振动
  static void setEnabled(bool value) {
    _enabled = value;
  }

  /// 轻振动 - 用于按钮点击等轻微反馈
  static Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 中等振动 - 用于操作确认
  static Future<void> medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 重振动 - 用于重要事件
  static Future<void> heavy() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// 选择变化振动 - 用于列表滚动等
  static Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  // ==================== 场景化振动反馈 ====================

  /// 分享操作 - 轻快的单次轻振
  static Future<void> share() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 保存操作 - 确认感的单次中等振动
  static Future<void> save() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 删除操作 - 警告感的单次重振动
  static Future<void> delete() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// 撤销操作 - 特别的双次轻振
  static Future<void> undo() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// 拖拽开始 - 吸附感的轻振
  static Future<void> dragStart() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 拖拽放置 - 确认感的振动
  static Future<void> dragEnd() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 队列操作 - 轻快的反馈
  static Future<void> queueAction() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 任务置顶 - 特别的振动模式
  static Future<void> moveToTop() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// 开关切换 - 清脆的点击感
  static Future<void> toggle() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 下拉刷新触发 - 弹性振动
  static Future<void> refresh() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 复制成功 - 轻快的反馈
  static Future<void> copy() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 长按触发 - 渐进式振动
  static Future<void> longPress() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 进入选择模式 - 明确的反馈
  static Future<void> selectionMode() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 批量操作进度 - 阶梯式振动
  static Future<void> batchProgress(int current, int total) async {
    if (!_enabled || total <= 0) return;
    final progress = current / total;
    if (progress >= 0.25 && progress < 0.26) {
      await HapticFeedback.lightImpact();
    } else if (progress >= 0.5 && progress < 0.51) {
      await HapticFeedback.mediumImpact();
    } else if (progress >= 0.75 && progress < 0.76) {
      await HapticFeedback.mediumImpact();
    } else if (progress >= 1.0 && current == total) {
      await success();
    }
  }

  /// 成功振动 - 双次渐强（生成完成等）
  static Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// 大成功 - 三次振动（批量完成等）
  static Future<void> bigSuccess() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// 错误振动 - 三连重震（严重错误）
  static Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// 轻微错误 - 单次重震
  static Future<void> minorError() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// 警告提示 - 双次振动
  static Future<void> warning() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }

  /// 网络错误 - 独特的振动模式
  static Future<void> networkError() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.lightImpact();
  }

  /// 重试操作 - 鼓励性的振动
  static Future<void> retry() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 页面切换 - 轻微的过渡感
  static Future<void> pageTransition() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 极限边界 - 到达列表边界等
  static Future<void> boundary() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 图片预览进入 - 沉浸感
  static Future<void> previewEnter() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 缩放手势 - 连续反馈
  static Future<void> zoom() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 设置变更 - 确认感
  static Future<void> settingChanged() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 滑块调节 - 连续轻振
  static Future<void> slider() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
}
