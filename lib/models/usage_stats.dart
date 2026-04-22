class UsageStats {
  final int totalCount;
  final int successCount;
  final int failureCount;
  final int avgDurationMs;
  final int todayCount;
  final int thisWeekCount;
  final int thisMonthCount;
  final String busiestHour;
  final String preferredModel;
  final String preferredAspectRatio;
  final int totalTokensUsed;
  final double dailyAverage;

  const UsageStats({
    this.totalCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.avgDurationMs = 0,
    this.todayCount = 0,
    this.thisWeekCount = 0,
    this.thisMonthCount = 0,
    this.busiestHour = '',
    this.preferredModel = '',
    this.preferredAspectRatio = '',
    this.totalTokensUsed = 0,
    this.dailyAverage = 0,
  });

  double get successRate =>
      totalCount == 0 ? 0 : (successCount / totalCount) * 100;
}
