import 'package:flutter/material.dart';

import '../services/haptic_service.dart';

class ChatMessageCard extends StatefulWidget {
  const ChatMessageCard({
    super.key,
    required this.prompt,
    required this.statusText,
    required this.timeText,
    required this.durationText,
    required this.copyPromptLabel,
    required this.retryLabel,
    required this.onCopyPrompt,
    required this.onRetry,
    this.promptWidget,
    this.isHighlighted = false,
    this.saveImageLabel,
    this.reuseReferencesLabel,
    this.reuseGeneratedImageLabel,
    this.copyErrorLabel,
    this.onSaveImage,
    this.onReuseReferences,
    this.onReuseGeneratedImage,
    this.onCopyError,
    this.imageWidget,
    this.errorText,
    this.animationDelay = 0,
    this.shareLabel,
    this.onShare,
  });

  final String prompt;
  final String statusText;
  final String timeText;
  final String durationText;
  final String copyPromptLabel;
  final String retryLabel;
  final Widget? promptWidget;
  final bool isHighlighted;
  final String? saveImageLabel;
  final String? reuseReferencesLabel;
  final String? reuseGeneratedImageLabel;
  final String? copyErrorLabel;
  final VoidCallback onCopyPrompt;
  final VoidCallback onRetry;
  final VoidCallback? onSaveImage;
  final VoidCallback? onReuseReferences;
  final VoidCallback? onReuseGeneratedImage;
  final VoidCallback? onCopyError;
  final Widget? imageWidget;
  final String? errorText;
  final int animationDelay;
  final String? shareLabel;
  final VoidCallback? onShare;

  @override
  State<ChatMessageCard> createState() => _ChatMessageCardState();
}

class _ChatMessageCardState extends State<ChatMessageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
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
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = colorScheme.secondary.withOpacity(0.24);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: widget.isHighlighted
                  ? [
                      BoxShadow(
                        color: colorScheme.secondary.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Card(
              color: widget.isHighlighted ? highlightColor : null,
              margin: const EdgeInsets.only(bottom: 10),
              elevation: widget.isHighlighted ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.promptWidget ?? Text(widget.prompt),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _AnimatedChip(label: widget.statusText),
                        _AnimatedChip(
                          label: widget.timeText,
                          delay: 50,
                        ),
                        _AnimatedChip(
                          label: widget.durationText,
                          delay: 100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _AnimatedTextButton(
                          label: widget.copyPromptLabel,
                          onPressed: () {
                            HapticService.light();
                            widget.onCopyPrompt();
                          },
                          delay: 150,
                        ),
                        if (widget.onSaveImage != null &&
                            (widget.saveImageLabel ?? '').isNotEmpty)
                          _AnimatedTextButton(
                            label: widget.saveImageLabel!,
                            onPressed: () {
                              HapticService.medium();
                              widget.onSaveImage!();
                            },
                            delay: 200,
                          ),
                        if (widget.onShare != null &&
                            (widget.shareLabel ?? '').isNotEmpty)
                          _AnimatedTextButton(
                            label: widget.shareLabel!,
                            onPressed: () {
                              HapticService.medium();
                              widget.onShare!();
                            },
                            delay: 225,
                          ),
                        _AnimatedTextButton(
                          label: widget.retryLabel,
                          onPressed: () {
                            HapticService.medium();
                            widget.onRetry();
                          },
                          delay: 250,
                        ),
                        if (widget.onReuseReferences != null &&
                            (widget.reuseReferencesLabel ?? '').isNotEmpty)
                          _AnimatedTextButton(
                            label: widget.reuseReferencesLabel!,
                            onPressed: () {
                              HapticService.light();
                              widget.onReuseReferences!();
                            },
                            delay: 300,
                          ),
                        if (widget.onReuseGeneratedImage != null &&
                            (widget.reuseGeneratedImageLabel ?? '').isNotEmpty)
                          _AnimatedTextButton(
                            label: widget.reuseGeneratedImageLabel!,
                            onPressed: () {
                              HapticService.light();
                              widget.onReuseGeneratedImage!();
                            },
                            delay: 350,
                          ),
                        if (widget.onCopyError != null &&
                            (widget.copyErrorLabel ?? '').isNotEmpty)
                          _AnimatedTextButton(
                            label: widget.copyErrorLabel!,
                            onPressed: () {
                              HapticService.error();
                              widget.onCopyError!();
                            },
                            delay: 400,
                            isError: true,
                          ),
                      ],
                    ),
                    if (widget.imageWidget != null) ...[
                      const SizedBox(height: 10),
                      _AnimatedImageContainer(child: widget.imageWidget!),
                    ] else if ((widget.errorText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _AnimatedErrorContainer(
                          errorText: widget.errorText!,
                          onRetry: widget.onRetry,
                          retryLabel: widget.retryLabel,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedChip extends StatefulWidget {
  const _AnimatedChip({
    required this.label,
    this.delay = 0,
  });

  final String label;
  final int delay;

  @override
  State<_AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<_AnimatedChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
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
      child: Chip(
        label: Text(widget.label),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _AnimatedTextButton extends StatefulWidget {
  const _AnimatedTextButton({
    required this.label,
    required this.onPressed,
    this.delay = 0,
    this.isError = false,
  });

  final String label;
  final VoidCallback onPressed;
  final int delay;
  final bool isError;

  @override
  State<_AnimatedTextButton> createState() => _AnimatedTextButtonState();
}

class _AnimatedTextButtonState extends State<_AnimatedTextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
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
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: TextButton(
          style: widget.isError
              ? TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                )
              : null,
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _AnimatedImageContainer extends StatefulWidget {
  const _AnimatedImageContainer({required this.child});

  final Widget child;

  @override
  State<_AnimatedImageContainer> createState() =>
      _AnimatedImageContainerState();
}

class _AnimatedImageContainerState extends State<_AnimatedImageContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: widget.child,
        ),
      ),
    );
  }
}

class _AnimatedErrorContainer extends StatefulWidget {
  const _AnimatedErrorContainer({
    required this.errorText,
    this.onRetry,
    this.retryLabel = '重试',
  });

  final String errorText;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  State<_AnimatedErrorContainer> createState() =>
      _AnimatedErrorContainerState();
}

class _AnimatedErrorContainerState extends State<_AnimatedErrorContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.error.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.error.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '生成失败',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                widget.errorText,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticService.medium();
                      widget.onRetry!();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(widget.retryLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
