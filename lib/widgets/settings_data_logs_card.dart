import 'package:flutter/material.dart';

class SettingsDataLogsCard extends StatelessWidget {
  const SettingsDataLogsCard({
    super.key,
    required this.imageCacheLabel,
    required this.imageCacheValue,
    required this.logLabel,
    required this.logValue,
    required this.refreshLabel,
    required this.exportLogLabel,
    required this.shareLogLabel,
    required this.saveAsLabel,
    required this.exportDiagnosticsLabel,
    required this.shareDiagnosticsLabel,
    required this.saveDiagnosticsLabel,
    required this.clearLogsLabel,
    required this.clearImageCacheLabel,
    required this.isRefreshingStorage,
    required this.isBusyWithDiagnostics,
    required this.onRefreshStorage,
    required this.onExportLog,
    required this.onShareLog,
    required this.onSaveLogAs,
    required this.onExportDiagnostics,
    required this.onShareDiagnostics,
    required this.onSaveDiagnosticsAs,
    required this.onClearLogs,
    required this.onClearImageCache,
  });

  final String imageCacheLabel;
  final String imageCacheValue;
  final String logLabel;
  final String logValue;
  final String refreshLabel;
  final String exportLogLabel;
  final String shareLogLabel;
  final String saveAsLabel;
  final String exportDiagnosticsLabel;
  final String shareDiagnosticsLabel;
  final String saveDiagnosticsLabel;
  final String clearLogsLabel;
  final String clearImageCacheLabel;
  final bool isRefreshingStorage;
  final bool isBusyWithDiagnostics;
  final VoidCallback onRefreshStorage;
  final VoidCallback onExportLog;
  final VoidCallback onShareLog;
  final VoidCallback onSaveLogAs;
  final VoidCallback onExportDiagnostics;
  final VoidCallback onShareDiagnostics;
  final VoidCallback onSaveDiagnosticsAs;
  final VoidCallback onClearLogs;
  final VoidCallback onClearImageCache;

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
                Text(imageCacheLabel),
                const Spacer(),
                Text(imageCacheValue),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(logLabel),
                const Spacer(),
                Text(logValue),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: isRefreshingStorage ? null : onRefreshStorage,
                  icon: isRefreshingStorage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(refreshLabel),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onExportLog,
                  icon: const Icon(Icons.file_download),
                  label: Text(exportLogLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onShareLog,
                  icon: const Icon(Icons.share),
                  label: Text(shareLogLabel),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onSaveLogAs,
                  icon: const Icon(Icons.save_alt),
                  label: Text(saveAsLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: isBusyWithDiagnostics ? null : onExportDiagnostics,
                  icon: isBusyWithDiagnostics
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.medical_information_outlined),
                  label: Text(exportDiagnosticsLabel),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusyWithDiagnostics ? null : onShareDiagnostics,
                  icon: const Icon(Icons.share_outlined),
                  label: Text(shareDiagnosticsLabel),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusyWithDiagnostics ? null : onSaveDiagnosticsAs,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saveDiagnosticsLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: onClearLogs,
                  child: Text(clearLogsLabel),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onClearImageCache,
                  child: Text(clearImageCacheLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
