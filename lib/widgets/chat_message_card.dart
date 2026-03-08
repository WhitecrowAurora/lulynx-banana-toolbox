import 'package:flutter/material.dart';

class ChatMessageCard extends StatelessWidget {
  const ChatMessageCard({
    super.key,
    required this.prompt,
    required this.statusText,
    required this.timeText,
    required this.durationText,
    required this.copyPromptLabel,
    required this.retryLabel,
    required this.onCopyPrompt,
    required this.onRetry,
    this.promptWidget,
    this.isHighlighted = false,
    this.saveImageLabel,
    this.reuseReferencesLabel,
    this.reuseGeneratedImageLabel,
    this.copyErrorLabel,
    this.onSaveImage,
    this.onReuseReferences,
    this.onReuseGeneratedImage,
    this.onCopyError,
    this.imageWidget,
    this.errorText,
  });

  final String prompt;
  final String statusText;
  final String timeText;
  final String durationText;
  final String copyPromptLabel;
  final String retryLabel;
  final Widget? promptWidget;
  final bool isHighlighted;
  final String? saveImageLabel;
  final String? reuseReferencesLabel;
  final String? reuseGeneratedImageLabel;
  final String? copyErrorLabel;
  final VoidCallback onCopyPrompt;
  final VoidCallback onRetry;
  final VoidCallback? onSaveImage;
  final VoidCallback? onReuseReferences;
  final VoidCallback? onReuseGeneratedImage;
  final VoidCallback? onCopyError;
  final Widget? imageWidget;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        Theme.of(context).colorScheme.secondary.withOpacity(0.24);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Card(
        color: isHighlighted ? highlightColor : null,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              promptWidget ?? Text(prompt),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    label: Text(statusText),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(timeText),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(durationText),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton(
                    onPressed: onCopyPrompt,
                    child: Text(copyPromptLabel),
                  ),
                  if (onSaveImage != null && (saveImageLabel ?? '').isNotEmpty)
                    TextButton(
                      onPressed: onSaveImage,
                      child: Text(saveImageLabel!),
                    ),
                  TextButton(onPressed: onRetry, child: Text(retryLabel)),
                  if (onReuseReferences != null &&
                      (reuseReferencesLabel ?? '').isNotEmpty)
                    TextButton(
                      onPressed: onReuseReferences,
                      child: Text(reuseReferencesLabel!),
                    ),
                  if (onReuseGeneratedImage != null &&
                      (reuseGeneratedImageLabel ?? '').isNotEmpty)
                    TextButton(
                      onPressed: onReuseGeneratedImage,
                      child: Text(reuseGeneratedImageLabel!),
                    ),
                  if (onCopyError != null && (copyErrorLabel ?? '').isNotEmpty)
                    TextButton(
                      onPressed: onCopyError,
                      child: Text(copyErrorLabel!),
                    ),
                ],
              ),
              if (imageWidget != null) ...[
                const SizedBox(height: 6),
                imageWidget!,
              ] else if ((errorText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(errorText!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
