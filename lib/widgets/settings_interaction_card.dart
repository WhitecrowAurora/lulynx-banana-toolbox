import 'package:flutter/material.dart';

import 'settings_section_header.dart';

class SettingsInteractionCard extends StatelessWidget {
  const SettingsInteractionCard({
    super.key,
    required this.hapticFeedbackEnabled,
    required this.shareSignature,
    required this.sectionTitle,
    required this.hapticFeedbackTitle,
    required this.hapticFeedbackSubtitle,
    required this.shareSignatureLabel,
    required this.shareSignatureHint,
    required this.onHapticFeedbackChanged,
    required this.onShareSignatureChanged,
  });

  final bool hapticFeedbackEnabled;
  final String shareSignature;
  final String sectionTitle;
  final String hapticFeedbackTitle;
  final String hapticFeedbackSubtitle;
  final String shareSignatureLabel;
  final String shareSignatureHint;
  final ValueChanged<bool> onHapticFeedbackChanged;
  final ValueChanged<String> onShareSignatureChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: sectionTitle),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(hapticFeedbackTitle),
                subtitle: Text(hapticFeedbackSubtitle),
                value: hapticFeedbackEnabled,
                secondary: Icon(
                  hapticFeedbackEnabled ? Icons.vibration : Icons.block,
                  color: hapticFeedbackEnabled
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                onChanged: onHapticFeedbackChanged,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(
                  Icons.edit_note,
                  color: colorScheme.primary,
                ),
                title: Text(shareSignatureLabel),
                subtitle: shareSignature.isNotEmpty
                    ? Text(
                        shareSignature,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Text(
                        shareSignatureHint,
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSignatureEditor(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSignatureEditor(BuildContext context) {
    final controller = TextEditingController(text: shareSignature);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.brush,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        shareSignatureLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLength: 50,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: shareSignatureHint,
                    border: const OutlineInputBorder(),
                    counterText: '${controller.text.length}/50',
                    helperText: '分享图片时会将此签名添加到图片底部',
                  ),
                  onChanged: (value) {
                    // Update counter
                    (context as Element).markNeedsBuild();
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    onShareSignatureChanged(controller.text.trim());
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('保存'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
