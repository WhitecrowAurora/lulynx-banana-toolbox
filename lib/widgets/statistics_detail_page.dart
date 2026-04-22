import 'package:flutter/material.dart';
import 'dart:math' as math;

class StatisticsDetailPage extends StatefulWidget {
  const StatisticsDetailPage({
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
    this.hourlyDistribution = const [],
    this.dailyDistribution = const [],
    this.modelDistribution = const {},
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
  final List<int> hourlyDistribution;
  final List<int> dailyDistribution;
  final Map<String, int> modelDistribution;

  @override
  State<StatisticsDetailPage> createState() => _StatisticsDetailPageState();
}

class _StatisticsDetailPageState extends State<StatisticsDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('生成统计'),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.primaryContainer,
                      ],
                    ),
                  ),
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Text(
                            '${widget.totalCount}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            '总生成次数',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _OverviewCards(
                todayCount: widget.todayCount,
                thisWeekCount: widget.thisWeekCount,
                thisMonthCount: widget.thisMonthCount,
                successRate: widget.successRate,
              ),
            ),
            SliverPersistentHeader(
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.pie_chart), text: '概览'),
                    Tab(icon: Icon(Icons.bar_chart), text: '趋势'),
                    Tab(icon: Icon(Icons.model_training), text: '模型'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
              successCount: widget.successCount,
              failureCount: widget.failureCount,
              successRate: widget.successRate,
              avgDurationMs: widget.avgDurationMs,
              dailyAverage: widget.dailyAverage,
              busiestHour: widget.busiestHour,
              preferredModel: widget.preferredModel,
              preferredAspectRatio: widget.preferredAspectRatio,
              totalTokensUsed: widget.totalTokensUsed,
            ),
            _TrendTab(
              hourlyDistribution: widget.hourlyDistribution,
              dailyDistribution: widget.dailyDistribution,
            ),
            _ModelsTab(
              modelDistribution: widget.modelDistribution,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({
    required this.todayCount,
    required this.thisWeekCount,
    required this.thisMonthCount,
    required this.successRate,
  });

  final int todayCount;
  final int thisWeekCount;
  final int thisMonthCount;
  final double successRate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '$todayCount',
              label: '今日',
              icon: Icons.today,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '$thisWeekCount',
              label: '本周',
              icon: Icons.date_range,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '$thisMonthCount',
              label: '本月',
              icon: Icons.calendar_month,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.successCount,
    required this.failureCount,
    required this.successRate,
    required this.avgDurationMs,
    required this.dailyAverage,
    required this.busiestHour,
    required this.preferredModel,
    required this.preferredAspectRatio,
    required this.totalTokensUsed,
  });

  final int successCount;
  final int failureCount;
  final double successRate;
  final int avgDurationMs;
  final double dailyAverage;
  final String busiestHour;
  final String preferredModel;
  final String preferredAspectRatio;
  final int totalTokensUsed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Success Rate Donut Chart
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _SuccessRatePainter(
                successRate: successRate,
                successColor: colorScheme.primary,
                failColor: colorScheme.error.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow('成功率', '${successRate.toStringAsFixed(1)}%', colorScheme.primary),
                  _buildStatRow('成功次数', '$successCount', colorScheme.primary),
                  _buildStatRow('失败次数', '$failureCount', colorScheme.error),
                  _buildStatRow('平均耗时', _formatDuration(avgDurationMs), colorScheme.onSurface),
                  _buildStatRow('日均生成', dailyAverage.toStringAsFixed(1), colorScheme.onSurface),
                  if (busiestHour.isNotEmpty)
                    _buildStatRow('活跃时段', busiestHour, colorScheme.onSurface),
                  if (preferredModel.isNotEmpty)
                    _buildStatRow('常用模型', preferredModel, colorScheme.onSurface),
                  if (preferredAspectRatio.isNotEmpty)
                    _buildStatRow('常用比例', preferredAspectRatio, colorScheme.onSurface),
                  if (totalTokensUsed > 0)
                    _buildStatRow('Token消耗', _formatTokens(totalTokensUsed), colorScheme.onSurface),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minute = ms ~/ 60000;
    final second = (ms % 60000) / 1000;
    return '${minute}m ${second.toStringAsFixed(0)}s';
  }

  String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(2)}M';
  }
}

class _SuccessRatePainter extends CustomPainter {
  final double successRate;
  final Color successColor;
  final Color failColor;

  _SuccessRatePainter({
    required this.successRate,
    required this.successColor,
    required this.failColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final strokeWidth = radius * 0.2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      paint..color = failColor,
    );

    // Success arc
    final successAngle = (successRate / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      successAngle,
      false,
      paint..color = successColor,
    );

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${successRate.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: radius * 0.5,
          fontWeight: FontWeight.bold,
          color: successColor,
        ),
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

class _TrendTab extends StatelessWidget {
  const _TrendTab({
    required this.hourlyDistribution,
    required this.dailyDistribution,
  });

  final List<int> hourlyDistribution;
  final List<int> dailyDistribution;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (hourlyDistribution.isNotEmpty)
            _HourlyChart(data: hourlyDistribution),
          if (dailyDistribution.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DailyChart(data: dailyDistribution),
          ],
        ],
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.data});

  final List<int> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = data.isEmpty ? 1 : data.reduce(math.max);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '24小时分布',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(24, (hour) {
                  final count = hour < data.length ? data[hour] : 0;
                  final height = maxValue > 0 ? count / maxValue : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Tooltip(
                        message: '$hour:00 - $count次',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 150 * height,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00:00', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text('12:00', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text('23:00', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.data});

  final List<int> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = data.isEmpty ? 1 : data.reduce(math.max);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近7天',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(data.length, (index) {
                  final count = data[index];
                  final height = maxValue > 0 ? count / maxValue : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message: '$count次',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 150 * height,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? colorScheme.secondary
                                : colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelsTab extends StatelessWidget {
  const _ModelsTab({required this.modelDistribution});

  final Map<String, int> modelDistribution;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = modelDistribution.values.fold(0, (sum, v) => sum + v);
    final sortedEntries = modelDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模型使用分布',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...sortedEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final model = entry.value.key;
                    final count = entry.value.value;
                    final percentage = total > 0 ? count / total : 0.0;
                    final colors = [
                      colorScheme.primary,
                      colorScheme.secondary,
                      colorScheme.tertiary,
                      colorScheme.error,
                      colorScheme.outline,
                    ];
                    final color = colors[index % colors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  model,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$count (${(percentage * 100).toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: colorScheme.outlineVariant,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
