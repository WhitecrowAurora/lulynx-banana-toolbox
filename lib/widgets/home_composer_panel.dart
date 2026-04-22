import 'package:flutter/material.dart';

class HomeComposerPanel extends StatefulWidget {
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
  State<HomeComposerPanel> createState() => _HomeComposerPanelState();
}

class _HomeComposerPanelState extends State<HomeComposerPanel>
    with TickerProviderStateMixin {
  late final AnimationController _sendButtonController;
  late final AnimationController _pulseController;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });

    if (widget.isLoading) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HomeComposerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _sendButtonController.dispose();
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSendPressed() {
    _sendButtonController.forward().then((_) {
      _sendButtonController.reverse();
    });
    if (widget.isLoading) {
      widget.onStop();
    } else {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showBalanceOnHome)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.balanceCard,
            ),
          if (widget.showBalanceOnHome) const SizedBox(height: 8),
          widget.queuePanel,
          if (widget.hasQueue) const SizedBox(height: 8),
          if (widget.showGeneratingHint)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
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
              child: widget.generatingHint,
            ),
          if (widget.showGeneratingHint) const SizedBox(height: 8),
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
            child: widget.hasReferenceImages
                ? Column(
                    key: const ValueKey('refs-panel-visible'),
                    children: [
                      widget.referenceImagesPanel,
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
                _AnimatedActionChip(
                  icon: Icons.auto_awesome,
                  label: widget.modelLabel,
                  onPressed: widget.onPickModel,
                  delay: 0,
                ),
                const SizedBox(width: 6),
                _AnimatedActionChip(
                  icon: Icons.aspect_ratio,
                  label: widget.aspectRatioLabel,
                  onPressed: widget.onPickAspect,
                  delay: 50,
                ),
                if (widget.imageSizeLabel != null &&
                    widget.onPickImageSize != null) ...[
                  const SizedBox(width: 6),
                  _AnimatedActionChip(
                    icon: Icons.hd,
                    label: widget.imageSizeLabel!,
                    onPressed: widget.onPickImageSize!,
                    delay: 100,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _AnimatedIconButton(
                icon: Icons.add_photo_alternate,
                onPressed: widget.onPickImage,
                color: colorScheme.primaryContainer,
                iconColor: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isFocused
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: widget.promptController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration(
                      hintText: widget.promptHintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: widget.isLoading
                          ? [
                              BoxShadow(
                                color: colorScheme.secondary.withOpacity(
                                  0.3 + 0.3 * _pulseController.value,
                                ),
                                blurRadius: 8 + 8 * _pulseController.value,
                                spreadRadius: 2 * _pulseController.value,
                              ),
                            ]
                          : null,
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 0.9).animate(
                        CurvedAnimation(
                          parent: _sendButtonController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: widget.isLoading
                              ? colorScheme.secondary
                              : colorScheme.primary,
                          foregroundColor: widget.isLoading
                              ? colorScheme.onSecondary
                              : colorScheme.onPrimary,
                        ),
                        onPressed: _onSendPressed,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return RotationTransition(
                              turns: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            widget.isLoading ? Icons.stop : Icons.send,
                            key: ValueKey(widget.isLoading ? 'stop' : 'send'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedActionChip extends StatefulWidget {
  const _AnimatedActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.delay,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int delay;

  @override
  State<_AnimatedActionChip> createState() => _AnimatedActionChipState();
}

class _AnimatedActionChipState extends State<_AnimatedActionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ActionChip(
        avatar: Icon(widget.icon, size: 14),
        label: Text(widget.label),
        onPressed: widget.onPressed,
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  const _AnimatedIconButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color iconColor;

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon, color: widget.iconColor),
        ),
      ),
    );
  }
}
