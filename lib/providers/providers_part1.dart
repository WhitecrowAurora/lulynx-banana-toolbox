import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../services/app_log_service.dart';
import '../services/backup_service.dart';
import '../services/chat_database_service.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());
final chatDatabaseProvider = Provider((ref) => ChatDatabaseService());
final appLogServiceProvider = Provider((ref) => AppLogService());
final backupServiceProvider = Provider((ref) {
  final db = ref.watch(chatDatabaseProvider);
  final storage = ref.watch(storageServiceProvider);
  return BackupService(db: db, storage: storage);
});

final apiConfigProvider =
    StateNotifierProvider<ApiConfigNotifier, ApiConfig>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiConfigNotifier(storage);
});

class ApiConfigNotifier extends StateNotifier<ApiConfig> {
  final StorageService _storage;
  final Completer<void> _loadedCompleter = Completer<void>();

  ApiConfigNotifier(this._storage) : super(ApiConfig.empty()) {
    _loadConfig();
  }

  Future<void> get loaded => _loadedCompleter.future;

  Future<void> _loadConfig() async {
    try {
      final config = await _storage.loadConfig();
      HapticService.setEnabled(config.hapticFeedbackEnabled);
      state = config;
    } finally {
      if (!_loadedCompleter.isCompleted) {
        _loadedCompleter.complete();
      }
    }
  }

  Future<void> updateConfig(ApiConfig config) async {
    HapticService.setEnabled(config.hapticFeedbackEnabled);
    state = config;
    await _storage.saveConfig(config);
  }

  void setBaseUrl(String url) => updateConfig(state.copyWith(baseUrl: url));
  void setApiKey(String key) => updateConfig(state.copyWith(apiKey: key));
  void setApiUserId(String userId) =>
      updateConfig(state.copyWith(apiUserId: userId));
  void setProviderId(String providerId) =>
      updateConfig(state.copyWith(providerId: providerId));
  void setModel(String model) => updateConfig(state.copyWith(model: model));
  void setAspectRatio(String ratio) =>
      updateConfig(state.copyWith(aspectRatio: ratio));
  void setImageSize(String size) =>
      updateConfig(state.copyWith(imageSize: size));
  void setShowBalanceOnHome(bool show) =>
      updateConfig(state.copyWith(showBalanceOnHome: show));

  void setAutoRetryEnabled(bool enabled) =>
      updateConfig(state.copyWith(autoRetryEnabled: enabled));

  void setRequestTimeoutSeconds(int seconds) {
    updateConfig(
      state.copyWith(requestTimeoutSeconds: seconds.clamp(30, 900).toInt()),
    );
  }

  void setMaxRetryCount(int count) {
    updateConfig(state.copyWith(maxRetryCount: count.clamp(0, 10).toInt()));
  }

  void setEnforceHttps(bool enabled) =>
      updateConfig(state.copyWith(enforceHttps: enabled));

  void setReferenceCompatEnhanced(bool enabled) =>
      updateConfig(state.copyWith(referenceCompatEnhanced: enabled));

  void setReferenceUploadMode(String mode) =>
      updateConfig(state.copyWith(referenceUploadMode: mode));

  void setReferencePreprocessOnPick(bool enabled) =>
      updateConfig(state.copyWith(referencePreprocessOnPick: enabled));

  void setReferencePreprocessEnabled(bool enabled) =>
      updateConfig(state.copyWith(referencePreprocessEnabled: enabled));

  void setReferenceMaxSingleImageMb(int mb) =>
      updateConfig(state.copyWith(referenceMaxSingleImageMb: mb));

  void setReferenceNormalizeFormat(String format) =>
      updateConfig(state.copyWith(referenceNormalizeFormat: format));

  void setReferenceMaxDimension(int dim) =>
      updateConfig(state.copyWith(referenceMaxDimension: dim));

  void setReferenceQuality(int quality) =>
      updateConfig(state.copyWith(referenceQuality: quality));

  void setReferencePreviewSize(String size) =>
      updateConfig(state.copyWith(referencePreviewSize: size));

  void setAppLanguage(String lang) =>
      updateConfig(state.copyWith(appLanguage: lang));

  void setReferenceAutoDegradeOnRetry(bool enabled) =>
      updateConfig(state.copyWith(referenceAutoDegradeOnRetry: enabled));

  void setSendIdempotencyKey(bool enabled) =>
      updateConfig(state.copyWith(sendIdempotencyKey: enabled));

  void setSnackBarPosition(String position) =>
      updateConfig(state.copyWith(snackBarPosition: position));

  void setRetryBaseDelayMs(int ms) =>
      updateConfig(state.copyWith(retryBaseDelayMs: ms));

  void setRetryMaxDelayMs(int ms) =>
      updateConfig(state.copyWith(retryMaxDelayMs: ms));

  void setRetryJitterPercent(int percent) =>
      updateConfig(state.copyWith(retryJitterPercent: percent));

  void setBackgroundKeepAliveEnabled(bool enabled) =>
      updateConfig(state.copyWith(backgroundKeepAliveEnabled: enabled));

  void setNotificationResidentEnabled(bool enabled) =>
      updateConfig(state.copyWith(notificationResidentEnabled: enabled));

  void setHapticFeedbackEnabled(bool enabled) {
    HapticService.setEnabled(enabled);
    updateConfig(state.copyWith(hapticFeedbackEnabled: enabled));
  }

  void setShareSignature(String signature) =>
      updateConfig(state.copyWith(shareSignature: signature));

  void setCachedBananaModels(
    List<Map<String, String>> models,
    String configKey,
  ) {
    updateConfig(state.copyWith(
      cachedBananaModels: models,
      cachedBananaModelsConfigKey: configKey,
      cachedBananaModelsFetchedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }
}
