import 'package:flutter/material.dart';

class SettingsBackupActions extends StatelessWidget {
  const SettingsBackupActions({
    super.key,
    required this.createBackupLabel,
    required this.restoreBackupLabel,
    required this.onCreateBackup,
    required this.onRestoreBackup,
  });

  final String createBackupLabel;
  final String restoreBackupLabel;
  final VoidCallback onCreateBackup;
  final VoidCallback onRestoreBackup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onCreateBackup,
            icon: const Icon(Icons.backup),
            label: Text(createBackupLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onRestoreBackup,
            icon: const Icon(Icons.restore),
            label: Text(restoreBackupLabel),
          ),
        ),
      ],
    );
  }
}
