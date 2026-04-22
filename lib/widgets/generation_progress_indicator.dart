import 'package:flutter/material.dart';

/// 生成进度阶段指示器 - 显示当前生成阶段和进度
class GenerationProgressIndicator extends StatelessWidget {
  const GenerationProgressIndicator({
    super.key,
    required this.progress,
    this.stage = GenerationStage.preparing,
    this.showStageText = true,
    this.estimatedSeconds,
  });

  final double progress; // 0.0 - 100.0
  final GenerationStage stage;
  final bool showStageText;
  final int? estimatedSeconds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _StageIcon(stage: stage, progress: progress),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showStageText)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          stage.label,
                          key: ValueKey(stage.label),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    if (estimatedSeconds != null && estimatedSeconds! > 0)
                      Text(
                        '预计还需 ${estimatedSeconds!} 秒',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ProgressText(progress: progress),
            ],
          ),
          const SizedBox(height: 10),
          _AnimatedProgressBar(
            progress: progress,
            stage: stage,
          ),
        ],
      ),
    );
  }
}

/// 阶段图标
class _StageIcon extends StatelessWidget {
  const _StageIcon({
    required this.stage,
    required this.progress,
  });

  final GenerationStage stage;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    late final Widget icon;
    switch (stage) {
      case GenerationStage.preparing:
        icon = _PulseIcon(
          icon: Icons.edit_note,
          color: colorScheme.primary,
        );
        break;
      case GenerationStage.generating:
        icon = SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: progress / 100,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        );
        break;
      case GenerationStage.downloading:
        icon = _PulseIcon(
          icon: Icons.download,
          color: colorScheme.tertiary,
        );
        break;
      case GenerationStage.completed:
        icon = Icon(
          Icons.check_circle,
          color: colorScheme.primary,
          size: 24,
        );
        break;
      case GenerationStage.failed:
        icon = Icon(
          Icons.error,
          color: colorScheme.error,
          size: 24,
        );
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: icon,
    );
  }
}

/// 脉动动画图标
class _PulseIcon extends StatefulWidget {
  const _PulseIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 24,
          ),
        );
      },
    );
  }
}

/// 进度文字
class _ProgressText extends StatelessWidget {
  const _ProgressText({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        '${progress.toStringAsFixed(0)}%',
        key: ValueKey(progress.toStringAsFixed(0)),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

/// 带动画的进度条
class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({
    required this.progress,
    required this.stage,
  });

  final double progress;
  final GenerationStage stage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    late final Color progressColor;
    switch (stage) {
      case GenerationStage.preparing:
        progressColor = colorScheme.primary;
        break;
      case GenerationStage.generating:
        progressColor = colorScheme.primary;
        break;
      case GenerationStage.downloading:
        progressColor = colorScheme.tertiary;
        break;
      case GenerationStage.completed:
        progressColor = colorScheme.primary;
        break;
      case GenerationStage.failed:
        progressColor = colorScheme.error;
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress / 100),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(progressColor),
          );
        },
      ),
    );
  }
}

/// 生成阶段枚举
enum GenerationStage {
  preparing('正在准备', 0, 10),
  generating('正在生成', 10, 80),
  downloading('正在下载', 80, 95),
  completed('生成完成', 95, 100),
  failed('生成失败', 0, 0);

  final String label;
  final int minProgress;
  final int maxProgress;

  const GenerationStage(this.label, this.minProgress, this.maxProgress);

  /// 根据进度值推断阶段
  static GenerationStage fromProgress(double progress) {
    if (progress >= 95) return completed;
    if (progress >= 80) return downloading;
    if (progress >= 10) return generating;
    return preparing;
  }
}
