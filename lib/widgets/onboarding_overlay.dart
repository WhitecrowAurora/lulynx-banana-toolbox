import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({
    super.key,
    required this.child,
    required this.onComplete,
    required this.onSkip,
    this.steps = const [],
  });

  final Widget child;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final List<OnboardingStep> steps;

  static Future<void> showIfNeeded({
    required BuildContext context,
    required VoidCallback onComplete,
    required List<OnboardingStep> steps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('_onboarding_shown_v1') ?? false;
    if (hasShown) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OnboardingDialog(
        steps: steps,
        onComplete: () async {
          await prefs.setBool('_onboarding_shown_v1', true);
          if (context.mounted) Navigator.pop(context);
          onComplete();
        },
        onSkip: () async {
          await prefs.setBool('_onboarding_shown_v1', true);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      _controller.reverse().then((_) {
        setState(() => _currentStep++);
        _controller.forward();
      });
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps.isNotEmpty ? widget.steps[_currentStep] : null;

    return Stack(
      children: [
        widget.child,
        if (step != null)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  // Dark backdrop
                  GestureDetector(
                    onTap: _nextStep,
                    child: Container(
                      color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
                    ),
                  ),
                  // Spotlight hole (if targetRect provided)
                  if (step.targetRect != null)
                    Positioned.fromRect(
                      rect: step.targetRect!,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
                              blurRadius: 20,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Info card
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 100 + _slideAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: _InfoCard(
                        step: step,
                        currentStep: _currentStep,
                        totalSteps: widget.steps.length,
                        onNext: _nextStep,
                        onSkip: _skip,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final OnboardingStep step;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 8,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              step.icon,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              step.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              step.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalSteps,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentStep
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const Text('跳过'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(
                    currentStep < totalSteps - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                  ),
                  label: Text(
                    currentStep < totalSteps - 1 ? '下一步' : '开始使用',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog({
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  final List<OnboardingStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
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
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      _controller.reverse().then((_) {
        setState(() => _currentStep++);
        _controller.forward();
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Card(
                elevation: 8,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.steps.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: index == _currentStep ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: index == _currentStep
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          if (_currentStep > 0)
                            TextButton(
                              onPressed: () {
                                _controller.reverse().then((_) {
                                  setState(() => _currentStep--);
                                  _controller.forward();
                                });
                              },
                              child: const Text('上一步'),
                            )
                          else
                            TextButton(
                              onPressed: widget.onSkip,
                              child: const Text('跳过'),
                            ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _nextStep,
                            icon: Icon(
                              _currentStep < widget.steps.length - 1
                                  ? Icons.arrow_forward
                                  : Icons.check,
                            ),
                            label: Text(
                              _currentStep < widget.steps.length - 1
                                  ? '下一步'
                                  : '开始使用',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Rect? targetRect;

  const OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    this.targetRect,
  });
}
