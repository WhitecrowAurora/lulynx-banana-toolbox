import 'package:flutter/material.dart';

class HomeBalanceCard extends StatelessWidget {
  const HomeBalanceCard({
    super.key,
    required this.text,
    required this.isLoading,
    required this.refreshTooltip,
    required this.onRefresh,
  });

  final String text;
  final bool isLoading;
  final String refreshTooltip;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : onRefresh,
            tooltip: refreshTooltip,
          ),
        ],
      ),
    );
  }
}
