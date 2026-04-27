import 'api_config.dart';

class ModelProfile {
  final String id;
  final String name;
  final String providerId;
  final String model;

  const ModelProfile({
    required this.id,
    required this.name,
    required this.providerId,
    required this.model,
  });

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final modelName = model.trim();
    if (modelName.isNotEmpty) return modelName;
    return id;
  }

  ModelProfile copyWith({
    String? id,
    String? name,
    String? providerId,
    String? model,
  }) {
    return ModelProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
    );
  }

  ApiConfig applyTo(ApiConfig config) {
    return config.copyWith(
      providerId: providerId,
      model: model,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'providerId': providerId,
        'model': model,
      };

  factory ModelProfile.fromJson(Map<String, dynamic> json) {
    return ModelProfile(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString() ?? '',
      providerId:
          json['providerId']?.toString() ??
          ApiConfig.providerNanoBananaCompatible,
      model: json['model']?.toString() ?? 'nano-banana',
    );
  }

  factory ModelProfile.fromConfig(
    ApiConfig config, {
    required String id,
    required String name,
  }) {
    return ModelProfile(
      id: id,
      name: name,
      providerId: config.providerId,
      model: config.model,
    );
  }
}
