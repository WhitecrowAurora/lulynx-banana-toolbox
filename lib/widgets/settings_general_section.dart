import 'package:flutter/material.dart';

import '../models/api_config.dart';
import 'settings_account_balance_card.dart';

class SettingsGeneralSection extends StatelessWidget {
  const SettingsGeneralSection({
    super.key,
    required this.config,
    required this.title,
    required this.quotaUnitLabel,
    required this.refreshTooltip,
    required this.emptyHint,
    required this.showBalanceTitle,
    required this.showBalanceSubtitle,
    required this.languageLabel,
    required this.languageHelper,
    required this.snackBarLabel,
    required this.snackBarHelper,
    required this.quota,
    required this.quotaError,
    required this.isLoadingQuota,
    required this.onRefreshQuota,
    required this.onShowBalanceChanged,
    required this.onAppLanguageChanged,
    required this.onSnackBarPositionChanged,
    required this.translate,
  });

  final ApiConfig config;
  final String title;
  final String quotaUnitLabel;
  final String refreshTooltip;
  final String emptyHint;
  final String showBalanceTitle;
  final String showBalanceSubtitle;
  final String languageLabel;
  final String languageHelper;
  final String snackBarLabel;
  final String snackBarHelper;
  final double? quota;
  final String? quotaError;
  final bool isLoadingQuota;
  final VoidCallback onRefreshQuota;
  final ValueChanged<bool> onShowBalanceChanged;
  final ValueChanged<String> onAppLanguageChanged;
  final ValueChanged<String> onSnackBarPositionChanged;
  final String Function(String) translate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsAccountBalanceCard(
          title: title,
          quotaUnitLabel: quotaUnitLabel,
          refreshTooltip: refreshTooltip,
          emptyHint: emptyHint,
          isLoading: isLoadingQuota,
          quota: quota,
          errorText: quotaError,
          onRefresh: onRefreshQuota,
        ),
        SwitchListTile(
          title: Text(showBalanceTitle),
          subtitle: Text(showBalanceSubtitle),
          value: config.showBalanceOnHome,
          onChanged: onShowBalanceChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: config.appLanguage,
          decoration: InputDecoration(
            labelText: languageLabel,
            helperText: languageHelper,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.language),
          ),
          items: ApiConfig.availableAppLanguages
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['id'],
                  child: Text(translate(item['name'] ?? '')),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null || value.isEmpty) return;
            onAppLanguageChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: config.snackBarPosition,
          decoration: InputDecoration(
            labelText: snackBarLabel,
            helperText: snackBarHelper,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.vertical_align_center),
          ),
          items: ApiConfig.availableSnackBarPositions.map((item) {
            return DropdownMenuItem<String>(
              value: item['id'],
              child: Text(translate(item['name'] ?? item['id'] ?? '')),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null || value.isEmpty) return;
            onSnackBarPositionChanged(value);
          },
        ),
      ],
    );
  }
}
