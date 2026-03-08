import 'package:flutter/material.dart';

class SettingsAccountBalanceCard extends StatelessWidget {
  const SettingsAccountBalanceCard({
    super.key,
    required this.title,
    required this.quotaUnitLabel,
    required this.refreshTooltip,
    required this.emptyHint,
    required this.isLoading,
    required this.onRefresh,
    this.quota,
    this.errorText,
  });

  final String title;
  final String quotaUnitLabel;
  final String refreshTooltip;
  final String emptyHint;
  final bool isLoading;
  final VoidCallback onRefresh;
  final double? quota;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    tooltip: refreshTooltip,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (quota != null)
              Text(
                '${quota!.toStringAsFixed(2)} $quotaUnitLabel',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            else if ((errorText ?? '').trim().isNotEmpty)
              Text(
                errorText!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              Text(
                emptyHint,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer
                      .withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
