class ApiConfig {
  static const String autoAspectRatio = 'auto';
  static const String providerNanoBananaCompatible = 'nano_banana_compatible';

  static const String referenceUploadModeAuto = 'auto';
  static const String referenceUploadModeList = 'list';
  static const String referenceUploadModeSingle = 'single';

  static const String referenceFormatKeep = 'keep';
  static const String referenceFormatJpeg = 'jpeg';
  static const String referenceFormatPng = 'png';
  static const String referenceFormatWebp = 'webp';
  static const String referencePreviewSizeSmall = 'small';
  static const String referencePreviewSizeMedium = 'medium';
  static const String referencePreviewSizeLarge = 'large';
  static const String appLanguageSystem = 'system';
  static const String appLanguageZh = 'zh';
  static const String appLanguageEn = 'en';
  static const String snackBarPositionBottom = 'bottom';
  static const String snackBarPositionTop = 'top';
  static const int defaultRetryBaseDelayMs = 1000;
  static const int defaultRetryMaxDelayMs = 3000;
  static const int defaultRetryJitterPercent = 20;

  final String baseUrl;
  final String apiKey;
  final String apiUserId;
  final String providerId;
  final String model;
  final String aspectRatio;
  final String imageSize;
  final String responseFormat;

  final bool showBalanceOnHome;
  final bool autoRetryEnabled;
  final int requestTimeoutSeconds;
  final int maxRetryCount;
  final bool enforceHttps;

  final bool referenceCompatEnhanced;
  final String referenceUploadMode;
  final bool referencePreprocessOnPick;
  final bool referencePreprocessEnabled;
  final int referenceMaxSingleImageMb;
  final String referenceNormalizeFormat;
  final int referenceMaxDimension;
  final int referenceQuality;
  final String referencePreviewSize;
  final String appLanguage;
  final bool referenceAutoDegradeOnRetry;
  final bool sendIdempotencyKey;
  final String snackBarPosition;
  final int retryBaseDelayMs;
  final int retryMaxDelayMs;
  final int retryJitterPercent;
  final bool backgroundKeepAliveEnabled;
  final bool notificationResidentEnabled;
  final List<Map<String, String>> cachedBananaModels;
  final String cachedBananaModelsConfigKey;
  final int cachedBananaModelsFetchedAtMs;

  ApiConfig({
    required this.baseUrl,
    required this.apiKey,
    this.apiUserId = '',
    this.providerId = providerNanoBananaCompatible,
    this.model = 'nano-banana',
    this.aspectRatio = '1:1',
    this.imageSize = '1K',
    this.responseFormat = 'url',
    this.showBalanceOnHome = false,
    this.autoRetryEnabled = false,
    this.requestTimeoutSeconds = 600,
    this.maxRetryCount = 10,
    this.enforceHttps = false,
    this.referenceCompatEnhanced = false,
    this.referenceUploadMode = referenceUploadModeAuto,
    this.referencePreprocessOnPick = false,
    this.referencePreprocessEnabled = false,
    this.referenceMaxSingleImageMb = 20,
    this.referenceNormalizeFormat = referenceFormatKeep,
    this.referenceMaxDimension = 0,
    this.referenceQuality = 90,
    this.referencePreviewSize = referencePreviewSizeMedium,
    this.appLanguage = appLanguageSystem,
    this.referenceAutoDegradeOnRetry = false,
    this.sendIdempotencyKey = true,
    this.snackBarPosition = snackBarPositionBottom,
    this.retryBaseDelayMs = defaultRetryBaseDelayMs,
    this.retryMaxDelayMs = defaultRetryMaxDelayMs,
    this.retryJitterPercent = defaultRetryJitterPercent,
    this.backgroundKeepAliveEnabled = false,
    this.notificationResidentEnabled = false,
    this.cachedBananaModels = const [],
    this.cachedBananaModelsConfigKey = '',
    this.cachedBananaModelsFetchedAtMs = 0,
  });

  bool get isValid => apiKey.isNotEmpty && baseUrl.isNotEmpty;

  bool get supportsImageSize =>
      model == 'nano-banana-2' || model == 'gemini-3.1-flash-image-preview';

  ApiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? apiUserId,
    String? providerId,
    String? model,
    String? aspectRatio,
    String? imageSize,
    String? responseFormat,
    bool? showBalanceOnHome,
    bool? autoRetryEnabled,
    int? requestTimeoutSeconds,
    int? maxRetryCount,
    bool? enforceHttps,
    bool? referenceCompatEnhanced,
    String? referenceUploadMode,
    bool? referencePreprocessOnPick,
    bool? referencePreprocessEnabled,
    int? referenceMaxSingleImageMb,
    String? referenceNormalizeFormat,
    int? referenceMaxDimension,
    int? referenceQuality,
    String? referencePreviewSize,
    String? appLanguage,
    bool? referenceAutoDegradeOnRetry,
    bool? sendIdempotencyKey,
    String? snackBarPosition,
    int? retryBaseDelayMs,
    int? retryMaxDelayMs,
    int? retryJitterPercent,
    bool? backgroundKeepAliveEnabled,
    bool? notificationResidentEnabled,
    List<Map<String, String>>? cachedBananaModels,
    String? cachedBananaModelsConfigKey,
    int? cachedBananaModelsFetchedAtMs,
  }) {
    final normalizedBaseDelayMs = _normalizeRetryBaseDelayMs(
      retryBaseDelayMs ?? this.retryBaseDelayMs,
    );
    final normalizedMaxDelayMs = _normalizeRetryMaxDelayMs(
      retryMaxDelayMs ?? this.retryMaxDelayMs,
      normalizedBaseDelayMs,
    );
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiUserId: apiUserId ?? this.apiUserId,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      imageSize: imageSize ?? this.imageSize,
      responseFormat: responseFormat ?? this.responseFormat,
      showBalanceOnHome: showBalanceOnHome ?? this.showBalanceOnHome,
      autoRetryEnabled: autoRetryEnabled ?? this.autoRetryEnabled,
      requestTimeoutSeconds:
          (requestTimeoutSeconds ?? this.requestTimeoutSeconds).clamp(30, 900),
      maxRetryCount: (maxRetryCount ?? this.maxRetryCount).clamp(0, 10),
      enforceHttps: enforceHttps ?? this.enforceHttps,
      referenceCompatEnhanced:
          referenceCompatEnhanced ?? this.referenceCompatEnhanced,
      referenceUploadMode: _normalizeReferenceUploadMode(
        referenceUploadMode ?? this.referenceUploadMode,
      ),
      referencePreprocessOnPick:
          referencePreprocessOnPick ?? this.referencePreprocessOnPick,
      referencePreprocessEnabled:
          referencePreprocessEnabled ?? this.referencePreprocessEnabled,
      referenceMaxSingleImageMb:
          (referenceMaxSingleImageMb ?? this.referenceMaxSingleImageMb)
              .clamp(20, 60),
      referenceNormalizeFormat: _normalizeReferenceFormat(
        referenceNormalizeFormat ?? this.referenceNormalizeFormat,
      ),
      referenceMaxDimension:
          (referenceMaxDimension ?? this.referenceMaxDimension).clamp(0, 4096),
      referenceQuality: (referenceQuality ?? this.referenceQuality).clamp(
        40,
        100,
      ),
      referencePreviewSize: _normalizeReferencePreviewSize(
        referencePreviewSize ?? this.referencePreviewSize,
      ),
      appLanguage: _normalizeAppLanguage(appLanguage ?? this.appLanguage),
      referenceAutoDegradeOnRetry:
          referenceAutoDegradeOnRetry ?? this.referenceAutoDegradeOnRetry,
      sendIdempotencyKey: sendIdempotencyKey ?? this.sendIdempotencyKey,
      snackBarPosition: _normalizeSnackBarPosition(
        snackBarPosition ?? this.snackBarPosition,
      ),
      retryBaseDelayMs: normalizedBaseDelayMs,
      retryMaxDelayMs: normalizedMaxDelayMs,
      retryJitterPercent: _normalizeRetryJitterPercent(
        retryJitterPercent ?? this.retryJitterPercent,
      ),
      backgroundKeepAliveEnabled:
          backgroundKeepAliveEnabled ?? this.backgroundKeepAliveEnabled,
      notificationResidentEnabled:
          notificationResidentEnabled ?? this.notificationResidentEnabled,
      cachedBananaModels: cachedBananaModels ?? this.cachedBananaModels,
      cachedBananaModelsConfigKey:
          cachedBananaModelsConfigKey ?? this.cachedBananaModelsConfigKey,
      cachedBananaModelsFetchedAtMs:
          cachedBananaModelsFetchedAtMs ?? this.cachedBananaModelsFetchedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'apiUserId': apiUserId,
        'providerId': providerId,
        'model': model,
        'aspectRatio': aspectRatio,
        'imageSize': imageSize,
        'responseFormat': responseFormat,
        'showBalanceOnHome': showBalanceOnHome,
        'autoRetryEnabled': autoRetryEnabled,
        'requestTimeoutSeconds': requestTimeoutSeconds,
        'maxRetryCount': maxRetryCount,
        'enforceHttps': enforceHttps,
        'referenceCompatEnhanced': referenceCompatEnhanced,
        'referenceUploadMode': referenceUploadMode,
        'referencePreprocessOnPick': referencePreprocessOnPick,
        'referencePreprocessEnabled': referencePreprocessEnabled,
        'referenceMaxSingleImageMb': referenceMaxSingleImageMb,
        'referenceNormalizeFormat': referenceNormalizeFormat,
        'referenceMaxDimension': referenceMaxDimension,
        'referenceQuality': referenceQuality,
        'referencePreviewSize': referencePreviewSize,
        'appLanguage': appLanguage,
        'referenceAutoDegradeOnRetry': referenceAutoDegradeOnRetry,
        'sendIdempotencyKey': sendIdempotencyKey,
        'snackBarPosition': snackBarPosition,
        'retryBaseDelayMs': retryBaseDelayMs,
        'retryMaxDelayMs': retryMaxDelayMs,
        'retryJitterPercent': retryJitterPercent,
        'backgroundKeepAliveEnabled': backgroundKeepAliveEnabled,
        'notificationResidentEnabled': notificationResidentEnabled,
        'cachedBananaModels': cachedBananaModels,
        'cachedBananaModelsConfigKey': cachedBananaModelsConfigKey,
        'cachedBananaModelsFetchedAtMs': cachedBananaModelsFetchedAtMs,
      };

  factory ApiConfig.fromJson(Map<String, dynamic> json) => ApiConfig(
        baseUrl: json['baseUrl']?.toString() ?? '',
        apiKey: json['apiKey']?.toString() ?? '',
        apiUserId: json['apiUserId']?.toString() ?? '',
        providerId:
            json['providerId']?.toString() ?? providerNanoBananaCompatible,
        model: json['model']?.toString() ?? 'nano-banana',
        aspectRatio: json['aspectRatio']?.toString() ?? '1:1',
        imageSize: json['imageSize']?.toString() ?? '1K',
        responseFormat: _normalizeResponseFormat(json['responseFormat']),
        showBalanceOnHome: json['showBalanceOnHome'] == true,
        autoRetryEnabled: json['autoRetryEnabled'] == true,
        requestTimeoutSeconds:
            _toInt(json['requestTimeoutSeconds'], 600).clamp(30, 900),
        maxRetryCount: _toInt(json['maxRetryCount'], 10).clamp(0, 10),
        enforceHttps: json['enforceHttps'] == true,
        referenceCompatEnhanced: json['referenceCompatEnhanced'] == true,
        referenceUploadMode:
            _normalizeReferenceUploadMode(json['referenceUploadMode']),
        referencePreprocessOnPick: json['referencePreprocessOnPick'] == true,
        referencePreprocessEnabled: json['referencePreprocessEnabled'] == true,
        referenceMaxSingleImageMb:
            _toInt(json['referenceMaxSingleImageMb'], 20).clamp(20, 60),
        referenceNormalizeFormat:
            _normalizeReferenceFormat(json['referenceNormalizeFormat']),
        referenceMaxDimension:
            _toInt(json['referenceMaxDimension'], 0).clamp(0, 4096),
        referenceQuality: _toInt(json['referenceQuality'], 90).clamp(40, 100),
        referencePreviewSize:
            _normalizeReferencePreviewSize(json['referencePreviewSize']),
        appLanguage: _normalizeAppLanguage(json['appLanguage']),
        referenceAutoDegradeOnRetry:
            json['referenceAutoDegradeOnRetry'] == true,
        sendIdempotencyKey: json.containsKey('sendIdempotencyKey')
            ? json['sendIdempotencyKey'] == true
            : true,
        snackBarPosition: _normalizeSnackBarPosition(json['snackBarPosition']),
        retryBaseDelayMs: _normalizeRetryBaseDelayMs(
          _toInt(json['retryBaseDelayMs'], defaultRetryBaseDelayMs),
        ),
        retryMaxDelayMs: _normalizeRetryMaxDelayMs(
          _toInt(json['retryMaxDelayMs'], defaultRetryMaxDelayMs),
          _normalizeRetryBaseDelayMs(
            _toInt(json['retryBaseDelayMs'], defaultRetryBaseDelayMs),
          ),
        ),
        retryJitterPercent: _normalizeRetryJitterPercent(
          _toInt(json['retryJitterPercent'], defaultRetryJitterPercent),
        ),
        backgroundKeepAliveEnabled: json['backgroundKeepAliveEnabled'] == true,
        notificationResidentEnabled:
            json['notificationResidentEnabled'] == true,
        cachedBananaModels: _normalizeModelCache(json['cachedBananaModels']),
        cachedBananaModelsConfigKey:
            json['cachedBananaModelsConfigKey']?.toString() ?? '',
        cachedBananaModelsFetchedAtMs:
            _toInt(json['cachedBananaModelsFetchedAtMs'], 0),
      );

  factory ApiConfig.empty() => ApiConfig(baseUrl: '', apiKey: '');

  static const List<Map<String, String>> availableModels = [
    {'id': 'nano-banana', 'name': 'Nano Banana (Base)'},
    {'id': 'nano-banana-hd', 'name': 'Nano Banana HD'},
    {'id': 'nano-banana-2', 'name': 'Nano Banana 2'},
    {
      'id': 'gemini-3.1-flash-image-preview',
      'name': 'Gemini 3.1 Flash Image Preview',
    },
  ];

  static const List<Map<String, String>> availableProviders = [
    {'id': providerNanoBananaCompatible, 'name': 'Nano Banana Compatible'},
  ];

  static const List<String> availableAspectRatios = [
    autoAspectRatio,
    '1:1',
    '4:3',
    '3:4',
    '16:9',
    '9:16',
    '2:3',
    '3:2',
    '4:5',
    '5:4',
    '21:9',
    '9:21',
    '4:1',
    '1:4',
    '8:1',
    '1:8',
  ];

  static const List<String> availableImageSizes = [
    '512px',
    '1K',
    '2K',
    '4K',
  ];

  static const List<Map<String, String>> availableReferenceUploadModes = [
    {'id': referenceUploadModeAuto, 'name': '自动（推荐）'},
    {'id': referenceUploadModeList, 'name': '列表载荷（image[]）'},
    {'id': referenceUploadModeSingle, 'name': '单项载荷（image）'},
  ];

  static const List<Map<String, String>> availableReferenceFormats = [
    {'id': referenceFormatKeep, 'name': '保持原格式'},
    {'id': referenceFormatJpeg, 'name': 'JPEG'},
    {'id': referenceFormatPng, 'name': 'PNG'},
    {'id': referenceFormatWebp, 'name': 'WEBP'},
  ];

  static const List<int> availableReferenceMaxDimensions = [
    0,
    1024,
    1536,
    2048,
    3072,
    4096,
  ];

  static const List<int> availableReferenceQualities = [
    60,
    70,
    80,
    85,
    90,
    95,
    100,
  ];

  static const List<Map<String, String>> availableReferencePreviewSizes = [
    {'id': referencePreviewSizeSmall, 'name': '小'},
    {'id': referencePreviewSizeMedium, 'name': '中'},
    {'id': referencePreviewSizeLarge, 'name': '大'},
  ];

  static const List<Map<String, String>> availableAppLanguages = [
    {'id': appLanguageSystem, 'name': '跟随系统'},
    {'id': appLanguageZh, 'name': '简体中文'},
    {'id': appLanguageEn, 'name': 'English'},
  ];

  static const List<int> availableReferenceSingleLimitMb = [
    20,
    30,
    40,
    50,
    60,
  ];

  static const List<Map<String, String>> availableSnackBarPositions = [
    {'id': snackBarPositionBottom, 'name': '底部'},
    {'id': snackBarPositionTop, 'name': '顶部'},
  ];

  static const List<int> availableRetryBaseDelayMs = [
    500,
    800,
    1000,
    1500,
    2000,
    3000,
  ];

  static const List<int> availableRetryMaxDelayMs = [
    1500,
    2000,
    3000,
    5000,
    8000,
    10000,
  ];

  static const List<int> availableRetryJitterPercent = [
    0,
    10,
    20,
    30,
    40,
    50,
  ];

  static String _normalizeResponseFormat(dynamic value) {
    final input = value?.toString().trim().toLowerCase() ?? '';
    if (input == 'b64_json') return 'b64_json';
    return 'url';
  }

  static String _normalizeReferenceUploadMode(dynamic value) {
    final input = value?.toString().trim().toLowerCase() ?? '';
    switch (input) {
      case referenceUploadModeAuto:
      case referenceUploadModeList:
      case referenceUploadModeSingle:
        return input;
      default:
        return referenceUploadModeAuto;
    }
  }

  static String _normalizeReferenceFormat(dynamic value) {
    final input = value?.toString().trim().toLowerCase() ?? '';
    switch (input) {
      case referenceFormatKeep:
      case referenceFormatJpeg:
      case referenceFormatPng:
      case referenceFormatWebp:
        return input;
      default:
        return referenceFormatKeep;
    }
  }

  static String _normalizeReferencePreviewSize(dynamic value) {
    final input = value?.toString().trim().toLowerCase() ?? '';
    switch (input) {
      case referencePreviewSizeSmall:
      case referencePreviewSizeMedium:
      case referencePreviewSizeLarge:
        return input;
      default:
        return referencePreviewSizeMedium;
    }
  }

  static String _normalizeAppLanguage(dynamic value) {
    final input = value?.toString().trim().toLowerCase() ?? '';
    switch (input) {
      case appLanguageSystem:
      case appLanguageZh:
      case appLanguageEn:
        return input;
      default:
        return appLanguageSystem;
    }
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<Map<String, String>> _normalizeModelCache(dynamic value) {
    if (value is! List) return const <Map<String, String>>[];
    final out = <Map<String, String>>[];
    for (final item in value) {
      if (item is! Map) continue;
      final id = item['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final name = item['name']?.toString().trim();
      out.add({
        'id': id,
        'name': (name == null || name.isEmpty) ? id : name,
      });
    }
    return out;
  }

  static String _normalizeSnackBarPosition(dynamic value) {
    final input = value?.toString().trim().toLowerCase() ?? '';
    switch (input) {
      case snackBarPositionTop:
      case snackBarPositionBottom:
        return input;
      default:
        return snackBarPositionBottom;
    }
  }

  static int _normalizeRetryBaseDelayMs(int value) {
    return value.clamp(200, 10000);
  }

  static int _normalizeRetryMaxDelayMs(int value, int baseDelayMs) {
    final normalizedBase = _normalizeRetryBaseDelayMs(baseDelayMs);
    return value.clamp(normalizedBase, 30000);
  }

  static int _normalizeRetryJitterPercent(int value) {
    return value.clamp(0, 60);
  }
}
