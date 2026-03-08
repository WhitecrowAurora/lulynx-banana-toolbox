import 'package:flutter/material.dart';

class SettingsFooterSections extends StatelessWidget {
  const SettingsFooterSections({
    super.key,
    required this.dataLogsTitle,
    required this.dataLogsCard,
    required this.backupTitle,
    required this.backupActions,
    required this.statsTitle,
    required this.statsCard,
    required this.statusTitle,
    required this.statusCard,
    required this.aboutCard,
  });

  final String dataLogsTitle;
  final Widget dataLogsCard;
  final String backupTitle;
  final Widget backupActions;
  final String statsTitle;
  final Widget statsCard;
  final String statusTitle;
  final Widget statusCard;
  final Widget aboutCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dataLogsTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        dataLogsCard,
        const SizedBox(height: 24),
        Text(
          backupTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        backupActions,
        const SizedBox(height: 24),
        Text(
          statsTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        statsCard,
        const SizedBox(height: 24),
        Text(
          statusTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        statusCard,
        const SizedBox(height: 24),
        aboutCard,
        const SizedBox(height: 24),
      ],
    );
  }
}
