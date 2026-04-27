import 'package:flutter/material.dart';

class SettingsProviderModelSection extends StatelessWidget {
  const SettingsProviderModelSection({
    super.key,
    required this.title,
    required this.groupLabel,
    required this.groupHint,
    required this.groupItems,
    required this.selectedGroupId,
    required this.saveGroupLabel,
    required this.updateGroupLabel,
    required this.deleteGroupLabel,
    required this.providerValue,
    required this.providerItems,
    required this.modelValue,
    required this.modelLabel,
    required this.modelHelperText,
    required this.modelItems,
    required this.modelStatusText,
    required this.modelLoadError,
    required this.isLoadingModels,
    required this.refreshModelsLabel,
    required this.onGroupChanged,
    required this.onSaveGroup,
    required this.onUpdateGroup,
    required this.onDeleteGroup,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onRefreshModels,
  });

  final String title;
  final String groupLabel;
  final String groupHint;
  final List<DropdownMenuItem<String>> groupItems;
  final String? selectedGroupId;
  final String saveGroupLabel;
  final String updateGroupLabel;
  final String deleteGroupLabel;
  final String providerValue;
  final List<DropdownMenuItem<String>> providerItems;
  final String? modelValue;
  final String modelLabel;
  final String modelHelperText;
  final List<DropdownMenuItem<String>> modelItems;
  final String modelStatusText;
  final String? modelLoadError;
  final bool isLoadingModels;
  final String refreshModelsLabel;
  final ValueChanged<String?> onGroupChanged;
  final VoidCallback onSaveGroup;
  final VoidCallback onUpdateGroup;
  final VoidCallback onDeleteGroup;
  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final VoidCallback onRefreshModels;

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
        DropdownButtonFormField<String>(
          value: selectedGroupId,
          decoration: InputDecoration(
            labelText: groupLabel,
            helperText: groupHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: groupItems,
          onChanged: onGroupChanged,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onSaveGroup,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(saveGroupLabel),
            ),
            FilledButton.tonalIcon(
              onPressed: selectedGroupId == null ? null : onUpdateGroup,
              icon: const Icon(Icons.save_outlined),
              label: Text(updateGroupLabel),
            ),
            FilledButton.tonalIcon(
              onPressed: selectedGroupId == null ? null : onDeleteGroup,
              icon: const Icon(Icons.delete_outline),
              label: Text(deleteGroupLabel),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: providerValue,
          decoration: const InputDecoration(
            labelText: 'Provider',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.hub_outlined),
          ),
          items: providerItems,
          onChanged: (value) {
            if (value != null) onProviderChanged(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: modelValue,
          decoration: InputDecoration(
            labelText: modelLabel,
            helperText: modelHelperText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.auto_awesome),
          ),
          items: modelItems,
          onChanged: (value) {
            if (value != null) onModelChanged(value);
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                modelStatusText,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: isLoadingModels ? null : onRefreshModels,
              icon: isLoadingModels
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(refreshModelsLabel),
            ),
          ],
        ),
        if ((modelLoadError ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              modelLoadError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
