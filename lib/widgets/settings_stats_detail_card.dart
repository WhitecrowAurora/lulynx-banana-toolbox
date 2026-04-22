import 'package:flutter/material.dart';
import 'dart:math' as math;

class SettingsStatsDetailCard extends StatelessWidget {
  const SettingsStatsDetailCard({
    super.key,
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
    required this.successRate,
    required this.avgDurationMs,
    this.todayCount = 0,
    this.thisWeekCount = 0,
    this.thisMonthCount = 0,
    this.dailyAverage = 0.0,
    this.busiestHour = '',
    this.preferredModel = '',
    this.preferredAspectRatio = '',
    this.totalTokensUsed = 0,
    required this.onViewDetails,
    required this.detailLabel,
    required this.todayLabel,
    required this.thisWeekLabel,
    required this.thisMonthLabel,
    required this.dailyAverageLabel,
    required this.busiestHourLabel,
    required this.preferredModelLabel,
    required this.preferredRatioLabel,
    required this.tokensUsedLabel,
  });

  final int totalCount;
  final int successCount;
  final int failureCount;
  final double successRate;
  final int avgDurationMs;
  final int todayCount;
  final int thisWeekCount;
  final int thisMonthCount;
  final double dailyAverage;
  final String busiestHour;
  final String preferredModel;
  final String preferredAspectRatio;
  final int totalTokensUsed;
  final VoidCallback onViewDetails;
  final String detailLabel;
  final String todayLabel;
  final String thisWeekLabel;
  final String thisMonthLabel;
  final String dailyAverageLabel;
  final String busiestHourLabel;
  final String preferredModelLabel;
  final String preferredRatioLabel;
  final String tokensUsedLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    value: '$todayCount',
                    label: todayLabel,
                    icon: Icons.today,
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    value: '$thisWeekCount',
                    label: thisWeekLabel,
                    icon: Icons.date_range,
                    color: colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    value: '$thisMonthCount',
                    label: thisMonthLabel,
                    icon: Icons.calendar_month,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSuccessRateChart(colorScheme, textTheme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(
                        context,
                        dailyAverageLabel,
                        dailyAverage.toStringAsFixed(1),
                      ),
                      const SizedBox(height: 8),
                      if (busiestHour.isNotEmpty)
                        _buildStatRow(context, busiestHourLabel, busiestHour),
                      if (busiestHour.isNotEmpty) const SizedBox(height: 8),
                      if (preferredModel.isNotEmpty)
                        _buildStatRow(context, preferredModelLabel, preferredModel),
                      if (preferredModel.isNotEmpty) const SizedBox(height: 8),
                      if (preferredAspectRatio.isNotEmpty)
                        _buildStatRow(
                          context,
                          preferredRatioLabel,
                          preferredAspectRatio,
                        ),
                      if (preferredAspectRatio.isNotEmpty) const SizedBox(height: 8),
                      if (totalTokensUsed > 0)
                        _buildStatRow(
                          context,
                          tokensUsedLabel,
                          _formatTokens(totalTokensUsed),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(detailLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessRateChart(ColorScheme colorScheme, TextTheme textTheme) {
    final successAngle = (successRate / 100) * 2 * math.pi;
    final failAngle = 2 * math.pi - successAngle;

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _DonutChartPainter(
          successAngle: successAngle,
          failAngle: failAngle,
          successColor: colorScheme.primary,
          failColor: colorScheme.error.withOpacity(0.3),
          centerText: '${successRate.toStringAsFixed(1)}%',
          centerTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(2)}M';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double successAngle;
  final double failAngle;
  final Color successColor;
  final Color failColor;
  final String centerText;
  final TextStyle? centerTextStyle;

  _DonutChartPainter({
    required this.successAngle,
    required this.failAngle,
    required this.successColor,
    required this.failColor,
    required this.centerText,
    this.centerTextStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final strokeWidth = radius * 0.25;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      successAngle,
      false,
      paint..color = successColor,
    );

    if (failAngle > 0.1) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + successAngle,
        failAngle,
        false,
        paint..color = failColor,
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: centerText,
        style: centerTextStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
