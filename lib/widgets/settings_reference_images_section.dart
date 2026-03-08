import 'package:flutter/material.dart';

class SettingsReferenceImagesSection extends StatelessWidget {
  const SettingsReferenceImagesSection({
    super.key,
    required this.title,
    required this.referenceUploadModeValue,
    required this.referenceUploadModeLabel,
    required this.referenceUploadModeItems,
    required this.onReferenceUploadModeChanged,
    required this.preprocessOnPickTitle,
    required this.preprocessOnPickSubtitle,
    required this.preprocessOnPickValue,
    required this.onPreprocessOnPickChanged,
    required this.referencePreviewSizeValue,
    required this.referencePreviewSizeLabel,
    required this.referencePreviewSizeItems,
    required this.onReferencePreviewSizeChanged,
    required this.referenceMaxSingleImageMbValue,
    required this.referenceMaxSingleImageMbLabel,
    required this.referenceMaxSingleImageMbItems,
    required this.onReferenceMaxSingleImageMbChanged,
    required this.preprocessReferenceTitle,
    required this.preprocessReferenceSubtitle,
    required this.preprocessReferenceValue,
    required this.onPreprocessReferenceChanged,
    required this.referenceFormatValue,
    required this.referenceFormatLabel,
    required this.referenceFormatItems,
    required this.onReferenceFormatChanged,
    required this.referenceMaxDimensionValue,
    required this.referenceMaxDimensionLabel,
    required this.referenceMaxDimensionItems,
    required this.onReferenceMaxDimensionChanged,
    required this.referenceQualityValue,
    required this.referenceQualityLabel,
    required this.referenceQualityItems,
    required this.onReferenceQualityChanged,
    required this.qualityPreviewCard,
    required this.autoDegradeTitle,
    required this.autoDegradeSubtitle,
    required this.autoDegradeValue,
    required this.onAutoDegradeChanged,
    required this.idempotencyKeyTitle,
    required this.idempotencyKeySubtitle,
    required this.idempotencyKeyValue,
    required this.onIdempotencyKeyChanged,
    required this.enforceHttpsTitle,
    required this.enforceHttpsSubtitle,
    required this.enforceHttpsValue,
    required this.onEnforceHttpsChanged,
  });

  final String title;
  final String referenceUploadModeValue;
  final String referenceUploadModeLabel;
  final List<DropdownMenuItem<String>> referenceUploadModeItems;
  final ValueChanged<String> onReferenceUploadModeChanged;
  final String preprocessOnPickTitle;
  final String preprocessOnPickSubtitle;
  final bool preprocessOnPickValue;
  final ValueChanged<bool> onPreprocessOnPickChanged;
  final String referencePreviewSizeValue;
  final String referencePreviewSizeLabel;
  final List<DropdownMenuItem<String>> referencePreviewSizeItems;
  final ValueChanged<String> onReferencePreviewSizeChanged;
  final int referenceMaxSingleImageMbValue;
  final String referenceMaxSingleImageMbLabel;
  final List<DropdownMenuItem<int>> referenceMaxSingleImageMbItems;
  final ValueChanged<int> onReferenceMaxSingleImageMbChanged;
  final String preprocessReferenceTitle;
  final String preprocessReferenceSubtitle;
  final bool preprocessReferenceValue;
  final ValueChanged<bool> onPreprocessReferenceChanged;
  final String referenceFormatValue;
  final String referenceFormatLabel;
  final List<DropdownMenuItem<String>> referenceFormatItems;
  final ValueChanged<String> onReferenceFormatChanged;
  final int referenceMaxDimensionValue;
  final String referenceMaxDimensionLabel;
  final List<DropdownMenuItem<int>> referenceMaxDimensionItems;
  final ValueChanged<int> onReferenceMaxDimensionChanged;
  final int referenceQualityValue;
  final String referenceQualityLabel;
  final List<DropdownMenuItem<int>> referenceQualityItems;
  final ValueChanged<int> onReferenceQualityChanged;
  final Widget qualityPreviewCard;
  final String autoDegradeTitle;
  final String autoDegradeSubtitle;
  final bool autoDegradeValue;
  final ValueChanged<bool> onAutoDegradeChanged;
  final String idempotencyKeyTitle;
  final String idempotencyKeySubtitle;
  final bool idempotencyKeyValue;
  final ValueChanged<bool> onIdempotencyKeyChanged;
  final String enforceHttpsTitle;
  final String enforceHttpsSubtitle;
  final bool enforceHttpsValue;
  final ValueChanged<bool> onEnforceHttpsChanged;

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
          value: referenceUploadModeValue,
          decoration: InputDecoration(
            labelText: referenceUploadModeLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.filter_1),
          ),
          items: referenceUploadModeItems,
          onChanged: (value) {
            if (value != null) onReferenceUploadModeChanged(value);
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(preprocessOnPickTitle),
          subtitle: Text(preprocessOnPickSubtitle),
          value: preprocessOnPickValue,
          onChanged: onPreprocessOnPickChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: referencePreviewSizeValue,
          decoration: InputDecoration(
            labelText: referencePreviewSizeLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.photo_size_select_large),
          ),
          items: referencePreviewSizeItems,
          onChanged: (value) {
            if (value != null) onReferencePreviewSizeChanged(value);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: referenceMaxSingleImageMbValue,
          decoration: InputDecoration(
            labelText: referenceMaxSingleImageMbLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.sd_storage),
          ),
          items: referenceMaxSingleImageMbItems,
          onChanged: (value) {
            if (value != null) onReferenceMaxSingleImageMbChanged(value);
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(preprocessReferenceTitle),
          subtitle: Text(preprocessReferenceSubtitle),
          value: preprocessReferenceValue,
          onChanged: onPreprocessReferenceChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: referenceFormatValue,
          decoration: InputDecoration(
            labelText: referenceFormatLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.image),
          ),
          items: referenceFormatItems,
          onChanged: (value) {
            if (value != null) onReferenceFormatChanged(value);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: referenceMaxDimensionValue,
          decoration: InputDecoration(
            labelText: referenceMaxDimensionLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.straighten),
          ),
          items: referenceMaxDimensionItems,
          onChanged: (value) {
            if (value != null) onReferenceMaxDimensionChanged(value);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: referenceQualityValue,
          decoration: InputDecoration(
            labelText: referenceQualityLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.tune),
          ),
          items: referenceQualityItems,
          onChanged: (value) {
            if (value != null) onReferenceQualityChanged(value);
          },
        ),
        const SizedBox(height: 8),
        qualityPreviewCard,
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(autoDegradeTitle),
          subtitle: Text(autoDegradeSubtitle),
          value: autoDegradeValue,
          onChanged: onAutoDegradeChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(idempotencyKeyTitle),
          subtitle: Text(idempotencyKeySubtitle),
          value: idempotencyKeyValue,
          onChanged: onIdempotencyKeyChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(enforceHttpsTitle),
          subtitle: Text(enforceHttpsSubtitle),
          value: enforceHttpsValue,
          onChanged: onEnforceHttpsChanged,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
