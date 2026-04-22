import 'package:flutter/material.dart';

class HomeGeneratingHint extends StatefulWidget {
  const HomeGeneratingHint({
    super.key,
    required this.text,
  });

  final String text;

  @override
  State<HomeGeneratingHint> createState() => _HomeGeneratingHintState();
}

class _HomeGeneratingHintState extends State<HomeGeneratingHint>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondary.withOpacity(
                        0.3 + 0.2 * _pulseController.value,
                      ),
                      blurRadius: 6 + 4 * _pulseController.value,
                      spreadRadius: 1 * _pulseController.value,
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, child) {
                    final progress = _slideController.value;
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            colorScheme.onSecondaryContainer.withOpacity(0.3),
                            colorScheme.onSecondaryContainer,
                            colorScheme.onSecondaryContainer.withOpacity(0.3),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                          transform: GradientRotation(
                            progress * 2 * 3.14159,
                          ),
                        ).createShader(bounds);
                      },
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'AI 正在构思画面',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _dotController,
                      builder: (context, child) {
                        return Text(
                          '.' * (1 + (_dotController.value * 3).floor()),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 2 * 3.14159,
                child: Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: colorScheme.secondary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
