import 'package:flutter/material.dart';

class SettingsStatsCard extends StatelessWidget {
  const SettingsStatsCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
