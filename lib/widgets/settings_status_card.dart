import 'package:flutter/material.dart';

class SettingsStatusCard extends StatelessWidget {
  const SettingsStatusCard({
    super.key,
    required this.isValid,
    required this.completeLabel,
    required this.incompleteLabel,
  });

  final bool isValid;
  final String completeLabel;
  final String incompleteLabel;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? Colors.green : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(isValid ? Icons.check_circle : Icons.warning, color: color),
            const SizedBox(width: 8),
            Text(
              isValid ? completeLabel : incompleteLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
