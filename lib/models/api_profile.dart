import 'api_config.dart';

class ApiProfile {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String apiUserId;
  final String providerId;
  final String model;

  const ApiProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.apiUserId,
    required this.providerId,
    required this.model,
  });

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final base = baseUrl.trim();
    if (base.isNotEmpty) return base;
    return id;
  }

  ApiProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? apiUserId,
    String? providerId,
    String? model,
  }) {
    return ApiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiUserId: apiUserId ?? this.apiUserId,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
    );
  }

  ApiConfig applyTo(ApiConfig config) {
    return config.copyWith(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiUserId: apiUserId,
      providerId: providerId,
      model: model,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'apiUserId': apiUserId,
        'providerId': providerId,
        'model': model,
      };

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
    return ApiProfile(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      apiUserId: json['apiUserId']?.toString() ?? '',
      providerId:
          json['providerId']?.toString() ?? ApiConfig.providerNanoBananaCompatible,
      model: json['model']?.toString() ?? 'nano-banana',
    );
  }

  factory ApiProfile.fromConfig(
    ApiConfig config, {
    required String id,
    required String name,
  }) {
    return ApiProfile(
      id: id,
      name: name,
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      apiUserId: config.apiUserId,
      providerId: config.providerId,
      model: config.model,
    );
  }
}
