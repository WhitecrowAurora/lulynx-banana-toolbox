import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';


class HomeMessageImage extends StatelessWidget {
  const HomeMessageImage({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.heroTag,
    this.onTap,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl ?? '';
    const imageHeight = 220.0;
    final colorScheme = Theme.of(context).colorScheme;

    Widget content;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      content = _buildMemoryImage(imageBytes!, colorScheme);
    } else if (resolvedImageUrl.startsWith('http')) {
      content = _buildNetworkImage(resolvedImageUrl, colorScheme);
    } else if (resolvedImageUrl.isNotEmpty) {
      content = _buildFileImage(resolvedImageUrl, colorScheme);
    } else {
      content = _buildPlaceholder(colorScheme);
    }

    Widget result = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: imageHeight,
        color: colorScheme.surfaceContainerHighest,
        child: content,
      ),
    );

    if (heroTag != null) {
      result = Hero(
        tag: heroTag!,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: result,
          ),
        ),
      );
    } else if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: result,
        ),
      );
    }

    return result;
  }

  Widget _buildMemoryImage(Uint8List bytes, ColorScheme colorScheme) {
    return Hero(
      tag: heroTag ?? 'memory_image_${bytes.hashCode}',
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildNetworkImage(String url, ColorScheme colorScheme) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeInCurve: Curves.easeOutCubic,
      placeholder: (context, url) => _buildShimmerPlaceholder(colorScheme),
      errorWidget: (context, url, error) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '加载失败',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileImage(String path, ColorScheme colorScheme) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      errorBuilder: (context, _, __) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 32,
        color: colorScheme.outline,
      ),
    );
  }

  Widget _buildShimmerPlaceholder(ColorScheme colorScheme) {
    return _EnhancedShimmerEffect(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surfaceContainerHigh,
      showProgressIndicator: true,
    );
  }
}

/// 增强版Shimmer效果 - 支持从左到右扫描动画和进度指示器
class _EnhancedShimmerEffect extends StatefulWidget {
  const _EnhancedShimmerEffect({
    required this.baseColor,
    required this.highlightColor,
    this.showProgressIndicator = false,
  });

  final Color baseColor;
  final Color highlightColor;
  final bool showProgressIndicator;

  @override
  State<_EnhancedShimmerEffect> createState() => _EnhancedShimmerEffectState();
}

class _EnhancedShimmerEffectState extends State<_EnhancedShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 从左到右的扫描动画
    _slideAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    // 柔和的脉动动画
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
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
      animation: _controller,
      builder: (context, child) {
        final slideValue = _slideAnimation.value;
        final pulseValue = _pulseAnimation.value;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                Color.lerp(
                  widget.highlightColor,
                  widget.baseColor,
                  0.3,
                )!,
                widget.highlightColor,
                Color.lerp(
                  widget.highlightColor,
                  widget.baseColor,
                  0.3,
                )!,
                widget.baseColor,
              ],
              stops: [
                (slideValue - 0.4).clamp(0.0, 1.0),
                (slideValue - 0.15).clamp(0.0, 1.0),
                slideValue.clamp(0.0, 1.0),
                (slideValue + 0.15).clamp(0.0, 1.0),
                (slideValue + 0.4).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: widget.showProgressIndicator
              ? Center(
                  child: Opacity(
                    opacity: pulseValue,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(
                              widget.highlightColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '加载中...',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.highlightColor.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
