import 'package:flutter/material.dart';

class SettingsAboutCard extends StatelessWidget {
  const SettingsAboutCard({
    super.key,
    required this.appName,
    required this.version,
    required this.copyrightTitle,
    required this.copyrightText,
    required this.thanksText,
    required this.licenseRows,
    required this.checkUpdateLabel,
    required this.onCheckUpdate,
    this.isCheckingUpdate = false,
    this.isDownloadingUpdate = false,
    this.updateStatus,
  });

  final String appName;
  final String version;
  final String copyrightTitle;
  final String copyrightText;
  final String thanksText;
  final List<String> licenseRows;
  final String checkUpdateLabel;
  final VoidCallback onCheckUpdate;
  final bool isCheckingUpdate;
  final bool isDownloadingUpdate;
  final String? updateStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  appName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  version,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              copyrightTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              copyrightText,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              thanksText,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < licenseRows.length; i++) ...[
                    _LicenseRow(text: licenseRows[i]),
                    if (i != licenseRows.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: (isCheckingUpdate || isDownloadingUpdate)
                      ? null
                      : onCheckUpdate,
                  icon: (isCheckingUpdate || isDownloadingUpdate)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt),
                  label: Text(checkUpdateLabel),
                ),
              ],
            ),
            if ((updateStatus ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                updateStatus!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LicenseRow extends StatelessWidget {
  const _LicenseRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '- ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
