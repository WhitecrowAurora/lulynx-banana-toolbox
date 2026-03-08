import 'package:flutter/material.dart';

class SettingsApiConnectionSection extends StatelessWidget {
  const SettingsApiConnectionSection({
    super.key,
    required this.title,
    required this.baseUrlController,
    required this.apiKeyController,
    required this.apiUserIdController,
    required this.baseUrlLabel,
    required this.baseUrlHelper,
    required this.apiKeyHint,
    required this.apiUserIdLabel,
    required this.apiUserIdHint,
    required this.isTesting,
    required this.isObscured,
    required this.testConnectionLabel,
    required this.testingLabel,
    required this.viewResultLabel,
    required this.showTestResultButton,
    required this.onBaseUrlChanged,
    required this.onApiKeyChanged,
    required this.onApiUserIdChanged,
    required this.onToggleObscured,
    required this.onTestConnection,
    required this.onViewResult,
  });

  final String title;
  final TextEditingController baseUrlController;
  final TextEditingController apiKeyController;
  final TextEditingController apiUserIdController;
  final String baseUrlLabel;
  final String baseUrlHelper;
  final String apiKeyHint;
  final String apiUserIdLabel;
  final String apiUserIdHint;
  final bool isTesting;
  final bool isObscured;
  final String testConnectionLabel;
  final String testingLabel;
  final String viewResultLabel;
  final bool showTestResultButton;
  final ValueChanged<String> onBaseUrlChanged;
  final ValueChanged<String> onApiKeyChanged;
  final ValueChanged<String> onApiUserIdChanged;
  final VoidCallback onToggleObscured;
  final VoidCallback onTestConnection;
  final VoidCallback onViewResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: baseUrlController,
          decoration: InputDecoration(
            labelText: baseUrlLabel,
            hintText: 'https://your-api-endpoint.com',
            helperText: baseUrlHelper,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          onChanged: onBaseUrlChanged,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: apiKeyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: apiKeyHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscured,
            ),
          ),
          obscureText: isObscured,
          onChanged: onApiKeyChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: apiUserIdController,
          decoration: InputDecoration(
            labelText: apiUserIdLabel,
            hintText: apiUserIdHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
          onChanged: onApiUserIdChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isTesting ? null : onTestConnection,
                icon: isTesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(isTesting ? testingLabel : testConnectionLabel),
              ),
            ),
            if (showTestResultButton) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onViewResult,
                child: Text(viewResultLabel),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
