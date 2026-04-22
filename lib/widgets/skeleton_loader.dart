import 'package:flutter/material.dart';

/// 骨架屏加载组件 - 用于列表/卡片加载时的占位效果
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 12,
    this.itemCount = 3,
    this.spacing = 12,
    this.direction = Axis.vertical,
  });

  final double height;
  final double width;
  final double borderRadius;
  final int itemCount;
  final double spacing;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    return direction == Axis.vertical
        ? Column(
            children: List.generate(itemCount, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: index < itemCount - 1 ? spacing : 0),
                child: _SkeletonItem(
                  height: height,
                  width: width,
                  borderRadius: borderRadius,
                ),
              );
            }),
          )
        : Row(
            children: List.generate(itemCount, (index) {
              return Padding(
                padding: EdgeInsets.only(right: index < itemCount - 1 ? spacing : 0),
                child: _SkeletonItem(
                  height: height,
                  width: width == double.infinity ? 100 : width,
                  borderRadius: borderRadius,
                ),
              );
            }),
          );
  }
}

/// 单个骨架屏项
class _SkeletonItem extends StatefulWidget {
  const _SkeletonItem({
    required this.height,
    required this.width,
    required this.borderRadius,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  State<_SkeletonItem> createState() => _SkeletonItemState();
}

class _SkeletonItemState extends State<_SkeletonItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
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
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor = colorScheme.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          stops: [
            (_animation.value - 0.2).clamp(0.0, 1.0),
            _animation.value.clamp(0.0, 1.0),
            (_animation.value + 0.2).clamp(0.0, 1.0),
          ],
        );

        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// 带内容的骨架屏项（图片+文字组合）
class ContentSkeleton extends StatelessWidget {
  const ContentSkeleton({
    super.key,
    this.hasImage = true,
    this.lineCount = 2,
  });

  final bool hasImage;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            const _SkeletonShimmer(
              width: 80,
              height: 80,
              borderRadius: 8,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonShimmer(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                ...List.generate(lineCount, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SkeletonShimmer(
                      width: index == lineCount - 1 ? 60 : double.infinity,
                      height: 12,
                      borderRadius: 4,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用的Shimmer效果容器
class _SkeletonShimmer extends StatefulWidget {
  const _SkeletonShimmer({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
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
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor = colorScheme.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
