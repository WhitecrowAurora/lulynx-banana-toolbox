class UsageStats {
  final int totalCount;
  final int successCount;
  final int failureCount;
  final int avgDurationMs;

  const UsageStats({
    this.totalCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.avgDurationMs = 0,
  });

  double get successRate =>
      totalCount == 0 ? 0 : (successCount / totalCount) * 100;
}
