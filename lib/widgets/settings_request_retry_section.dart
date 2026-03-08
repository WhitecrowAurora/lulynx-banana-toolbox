import 'package:flutter/material.dart';

class SettingsRequestRetrySection extends StatelessWidget {
  const SettingsRequestRetrySection({
    super.key,
    required this.title,
    required this.requestTimeoutValue,
    required this.requestTimeoutLabel,
    required this.secondUnitLabel,
    required this.onRequestTimeoutChanged,
    required this.maxRetryCountValue,
    required this.maxRetryCountLabel,
    required this.timesUnitLabel,
    required this.autoRetryEnabled,
    required this.onMaxRetryCountChanged,
    required this.retryBaseDelayValue,
    required this.retryBaseDelayLabel,
    required this.onRetryBaseDelayChanged,
    required this.retryMaxDelayValue,
    required this.retryMaxDelayLabel,
    required this.retryMaxDelayOptions,
    required this.onRetryMaxDelayChanged,
    required this.retryJitterValue,
    required this.retryJitterLabel,
    required this.onRetryJitterChanged,
    required this.enhancedReferenceTitle,
    required this.enhancedReferenceSubtitle,
    required this.enhancedReferenceValue,
    required this.onEnhancedReferenceChanged,
    required this.backgroundKeepAliveTitle,
    required this.backgroundKeepAliveSubtitle,
    required this.backgroundKeepAliveValue,
    required this.onBackgroundKeepAliveChanged,
    required this.notificationResidentTitle,
    required this.notificationResidentSubtitle,
    required this.notificationResidentValue,
    required this.onNotificationResidentChanged,
    required this.showBatteryOptimizationCard,
    required this.ignoringBatteryOptimizations,
    required this.batteryOptimizedText,
    required this.disableBatteryOptimizationText,
    required this.isCheckingBatteryOptimization,
    required this.openSettingsLabel,
    required this.checkingLabel,
    required this.onOpenBatteryOptimizationSettings,
  });

  final String title;
  final int requestTimeoutValue;
  final String requestTimeoutLabel;
  final String secondUnitLabel;
  final ValueChanged<int> onRequestTimeoutChanged;
  final int maxRetryCountValue;
  final String maxRetryCountLabel;
  final String timesUnitLabel;
  final bool autoRetryEnabled;
  final ValueChanged<int> onMaxRetryCountChanged;
  final int retryBaseDelayValue;
  final String retryBaseDelayLabel;
  final ValueChanged<int> onRetryBaseDelayChanged;
  final int retryMaxDelayValue;
  final String retryMaxDelayLabel;
  final List<DropdownMenuItem<int>> retryMaxDelayOptions;
  final ValueChanged<int> onRetryMaxDelayChanged;
  final int retryJitterValue;
  final String retryJitterLabel;
  final ValueChanged<int> onRetryJitterChanged;
  final String enhancedReferenceTitle;
  final String enhancedReferenceSubtitle;
  final bool enhancedReferenceValue;
  final ValueChanged<bool> onEnhancedReferenceChanged;
  final String backgroundKeepAliveTitle;
  final String backgroundKeepAliveSubtitle;
  final bool backgroundKeepAliveValue;
  final ValueChanged<bool>? onBackgroundKeepAliveChanged;
  final String notificationResidentTitle;
  final String notificationResidentSubtitle;
  final bool notificationResidentValue;
  final ValueChanged<bool>? onNotificationResidentChanged;
  final bool showBatteryOptimizationCard;
  final bool ignoringBatteryOptimizations;
  final String batteryOptimizedText;
  final String disableBatteryOptimizationText;
  final bool isCheckingBatteryOptimization;
  final String openSettingsLabel;
  final String checkingLabel;
  final VoidCallback onOpenBatteryOptimizationSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: requestTimeoutValue,
          decoration: InputDecoration(
            labelText: requestTimeoutLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.timer_outlined),
          ),
          items: const [60, 120, 180, 300, 600, 900]
              .map((v) => DropdownMenuItem(value: v, child: Text('$v ')))
              .toList()
              .map((item) => DropdownMenuItem<int>(
                    value: item.value,
                    child: Text('${item.value} $secondUnitLabel'),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) onRequestTimeoutChanged(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: maxRetryCountValue,
          decoration: InputDecoration(
            labelText: maxRetryCountLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.restart_alt),
          ),
          items: List.generate(
            11,
            (i) => DropdownMenuItem<int>(
              value: i,
              child: Text('$i $timesUnitLabel'),
            ),
          ),
          onChanged: autoRetryEnabled
              ? (value) {
                  if (value != null) onMaxRetryCountChanged(value);
                }
              : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: retryBaseDelayValue,
          decoration: InputDecoration(
            labelText: retryBaseDelayLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.timelapse_outlined),
          ),
          items: const [250, 500, 1000, 1500, 2000, 3000, 5000]
              .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v ms')))
              .toList(),
          onChanged: autoRetryEnabled
              ? (value) {
                  if (value != null) onRetryBaseDelayChanged(value);
                }
              : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: retryMaxDelayValue,
          decoration: InputDecoration(
            labelText: retryMaxDelayLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.schedule_outlined),
          ),
          items: retryMaxDelayOptions,
          onChanged: autoRetryEnabled
              ? (value) {
                  if (value != null) onRetryMaxDelayChanged(value);
                }
              : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: retryJitterValue,
          decoration: InputDecoration(
            labelText: retryJitterLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.shuffle),
          ),
          items: const [0, 5, 10, 15, 20, 25, 30, 40, 50]
              .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v%')))
              .toList(),
          onChanged: autoRetryEnabled
              ? (value) {
                  if (value != null) onRetryJitterChanged(value);
                }
              : null,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(enhancedReferenceTitle),
          subtitle: Text(enhancedReferenceSubtitle),
          value: enhancedReferenceValue,
          onChanged: onEnhancedReferenceChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(backgroundKeepAliveTitle),
          subtitle: Text(backgroundKeepAliveSubtitle),
          value: backgroundKeepAliveValue,
          onChanged: onBackgroundKeepAliveChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(notificationResidentTitle),
          subtitle: Text(notificationResidentSubtitle),
          value: notificationResidentValue,
          onChanged: onNotificationResidentChanged,
        ),
        if (showBatteryOptimizationCard) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    ignoringBatteryOptimizations
                        ? Icons.verified
                        : Icons.warning_amber_rounded,
                    color: ignoringBatteryOptimizations ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ignoringBatteryOptimizations
                          ? batteryOptimizedText
                          : disableBatteryOptimizationText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: isCheckingBatteryOptimization
                        ? null
                        : onOpenBatteryOptimizationSettings,
                    child: Text(
                      isCheckingBatteryOptimization
                          ? checkingLabel
                          : openSettingsLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
