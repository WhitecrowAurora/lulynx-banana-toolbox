import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../models/chat_models.dart';
import '../models/generation_queue_task.dart';
import '../models/generation_result.dart';
import '../models/usage_stats.dart';
import '../services/app_log_service.dart';
import '../services/backup_service.dart';
import '../services/chat_database_service.dart';
import '../services/foreground_keep_alive_service.dart';
import '../services/haptic_service.dart';
import '../services/nano_banana_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());
final chatDatabaseProvider = Provider((ref) => ChatDatabaseService());
final appLogServiceProvider = Provider((ref) => AppLogService());
final backupServiceProvider = Provider((ref) {
  final db = ref.watch(chatDatabaseProvider);
  final storage = ref.watch(storageServiceProvider);
  return BackupService(db: db, storage: storage);
});

/// Task run result helper class
class _TaskRunResult {
  final GenerationResult result;
  final int retryCount;

  _TaskRunResult({
    required this.result,
    required this.retryCount,
  });
}

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
      state = config;
    } finally {
      if (!_loadedCompleter.isCompleted) {
        _loadedCompleter.complete();
      }
    }
  }

  Future<void> updateConfig(ApiConfig config) async {
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

  void setReferenceMaxDimension(int dimension) =>
      updateConfig(state.copyWith(referenceMaxDimension: dimension));

  void setReferenceQuality(int quality) =>
      updateConfig(state.copyWith(referenceQuality: quality));

  void setReferencePreviewSize(String size) =>
      updateConfig(state.copyWith(referencePreviewSize: size));

  void setAppLanguage(String language) =>
      updateConfig(state.copyWith(appLanguage: language));

  void setReferenceAutoDegradeOnRetry(bool enabled) =>
      updateConfig(state.copyWith(referenceAutoDegradeOnRetry: enabled));

  void setSendIdempotencyKey(bool enabled) =>
      updateConfig(state.copyWith(sendIdempotencyKey: enabled));

  void setSnackBarPosition(String position) =>
      updateConfig(state.copyWith(snackBarPosition: position));

  void setRetryBaseDelayMs(int value) =>
      updateConfig(state.copyWith(retryBaseDelayMs: value));

  void setRetryMaxDelayMs(int value) =>
      updateConfig(state.copyWith(retryMaxDelayMs: value));

  void setRetryJitterPercent(int value) =>
      updateConfig(state.copyWith(retryJitterPercent: value));

  void setHapticFeedbackEnabled(bool enabled) {
    HapticService.setEnabled(enabled);
    updateConfig(state.copyWith(hapticFeedbackEnabled: enabled));
  }

  void setShareSignature(String signature) =>
      updateConfig(state.copyWith(shareSignature: signature));

  void setBackgroundKeepAliveEnabled(bool enabled) =>
      updateConfig(state.copyWith(backgroundKeepAliveEnabled: enabled));

  void setNotificationResidentEnabled(bool enabled) =>
      updateConfig(state.copyWith(notificationResidentEnabled: enabled));

  void setCachedBananaModels({
    required String cacheKey,
    required List<Map<String, String>> models,
    required int fetchedAtMs,
  }) =>
      updateConfig(
        state.copyWith(
          cachedBananaModelsConfigKey: cacheKey,
          cachedBananaModels: models,
          cachedBananaModelsFetchedAtMs: fetchedAtMs,
        ),
      );
}

final nanoBananaServiceProvider = Provider<NanoBananaService>((ref) {
  final service = NanoBananaService(config: ref.read(apiConfigProvider));
  ref.listen<ApiConfig>(apiConfigProvider, (previous, next) {
    service.updateConfig(next);
  });
  return service;
});

Locale _resolveSystemLocale() {
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final locales = dispatcher.locales;

  for (final locale in locales) {
    final code = locale.languageCode.toLowerCase();
    if (code.startsWith('zh')) {
      return const Locale('zh');
    }
    if (code.startsWith('en')) {
      return const Locale('en');
    }
  }

  final primary = dispatcher.locale.languageCode.toLowerCase();
  if (primary.startsWith('zh')) {
    return const Locale('zh');
  }
  return const Locale('en');
}

final appLocaleProvider = Provider<Locale?>((ref) {
  final language = ref.watch(apiConfigProvider.select((c) => c.appLanguage));
  switch (language) {
    case ApiConfig.appLanguageZh:
      return const Locale('zh');
    case ApiConfig.appLanguageEn:
      return const Locale('en');
    case ApiConfig.appLanguageSystem:
    default:
      return _resolveSystemLocale();
  }
});

final apiConfigReadyProvider = FutureProvider<void>((ref) async {
  await ref.watch(apiConfigProvider.notifier).loaded;
});

class BalanceState {
  final bool isLoading;
  final double? balance;
  final double? usedQuota;
  final double sessionTotalCost;
  final double lastCost;
  final double? _sessionStartUsedQuota;
  final String? error;

  BalanceState({
    this.isLoading = false,
    this.balance,
    this.usedQuota,
    this.sessionTotalCost = 0,
    this.lastCost = 0,
    double? sessionStartUsedQuota,
    this.error,
  }) : _sessionStartUsedQuota = sessionStartUsedQuota;

  BalanceState copyWith({
    bool? isLoading,
    double? balance,
    double? usedQuota,
    double? sessionTotalCost,
    double? lastCost,
    double? sessionStartUsedQuota,
    String? error,
    bool clearError = false,
  }) {
    return BalanceState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      usedQuota: usedQuota ?? this.usedQuota,
      sessionTotalCost: sessionTotalCost ?? this.sessionTotalCost,
      lastCost: lastCost ?? this.lastCost,
      sessionStartUsedQuota:
          sessionStartUsedQuota ?? _sessionStartUsedQuota ?? this.usedQuota,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final balanceProvider =
    StateNotifierProvider<BalanceNotifier, BalanceState>((ref) {
  final service = ref.watch(nanoBananaServiceProvider);
  return BalanceNotifier(service);
});

class BalanceNotifier extends StateNotifier<BalanceState> {
  final NanoBananaService _service;

  BalanceNotifier(this._service) : super(BalanceState());

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _service.getTokenQuota();

    if (result['success'] == true) {
      final balance = (result['quota'] as num?)?.toDouble();
      final used = (result['usedQuota'] as num?)?.toDouble();
      final start = state._sessionStartUsedQuota ?? used;
      final total = (start != null && used != null) ? (used - start) : 0.0;
      final prevUsed = state.usedQuota;
      final delta =
          (prevUsed != null && used != null) ? (used - prevUsed) : 0.0;
      state = state.copyWith(
        isLoading: false,
        balance: balance,
        usedQuota: used,
        sessionStartUsedQuota: start,
        sessionTotalCost: total < 0 ? 0.0 : total,
        lastCost: delta < 0 ? 0.0 : delta,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result['error'] as String?,
      );
    }
  }
}

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<ChatSession>>((ref) {
  final db = ref.watch(chatDatabaseProvider);
  return SessionsNotifier(db);
});

class SessionsNotifier extends StateNotifier<List<ChatSession>> {
  final ChatDatabaseService _db;

  SessionsNotifier(this._db) : super([]) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    state = await _db.getAllSessions();
  }

  Future<ChatSession> createSession({String? title}) async {
    final session = await _db.createSession(title: title);
    state = [session, ...state];
    return session;
  }

  Future<void> deleteSession(int sessionId) async {
    await _db.deleteSession(sessionId);
    state = state.where((s) => s.id != sessionId).toList();
  }

  Future<void> renameSession(int sessionId, String newTitle) async {
    final index = state.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;

    final updated = state[index].copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    await _db.updateSession(updated);
    state = [...state]..[index] = updated;
  }
}

final currentSessionIdProvider = StateProvider<int?>((ref) => null);

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<ChatMessage>>((ref) {
  final db = ref.watch(chatDatabaseProvider);
  final sessionId = ref.watch(currentSessionIdProvider);
  final notifier = MessagesNotifier(db, sessionId);
  if (sessionId != null) {
    notifier.loadMessages();
  }
  return notifier;
});

class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatDatabaseService _db;
  final int? _sessionId;

  MessagesNotifier(this._db, this._sessionId) : super([]);

  Future<void> loadMessages() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    state = await _db.getMessages(sessionId);
  }

  Future<void> addMessage(ChatMessage message) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    if (sessionId == message.sessionId) {
      await loadMessages();
      return;
    }
  }

  void refresh() {
    loadMessages();
  }
}

final usageStatsProvider = FutureProvider<UsageStats>((ref) async {
  final db = ref.watch(chatDatabaseProvider);
  final sessionId = ref.watch(currentSessionIdProvider);
  return db.getUsageStats(sessionId: sessionId);
});

class GenerationState {
  final bool isLoading;
  final GenerationResult? result;
  final List<Uint8List> referenceImages;
  final List<GenerationQueueTask> queue;
  final String? activeTaskId;
  final ChatMessage? lastFailedMessage;

  GenerationState({
    this.isLoading = false,
    this.result,
    this.referenceImages = const [],
    this.queue = const [],
    this.activeTaskId,
    this.lastFailedMessage,
  });

  GenerationState copyWith({
    bool? isLoading,
    GenerationResult? result,
    List<Uint8List>? referenceImages,
    List<GenerationQueueTask>? queue,
    String? activeTaskId,
    ChatMessage? lastFailedMessage,
    bool clearActiveTaskId = false,
    bool clearResult = false,
    bool clearLastFailed = false,
  }) {
    return GenerationState(
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      referenceImages: referenceImages ?? this.referenceImages,
      queue: queue ?? this.queue,
      activeTaskId:
          clearActiveTaskId ? null : (activeTaskId ?? this.activeTaskId),
      lastFailedMessage: clearLastFailed
          ? null
          : (lastFailedMessage ?? this.lastFailedMessage),
    );
  }
}

final generationProvider =
    StateNotifierProvider<GenerationNotifier, GenerationState>((ref) {
  final service = ref.read(nanoBananaServiceProvider);
  final db = ref.read(chatDatabaseProvider);
  return GenerationNotifier(service, db, ref);
});

class GenerationNotifier extends StateNotifier<GenerationState> {
  final NanoBananaService _service;
  final ChatDatabaseService _db;
  final Ref _ref;

  static const int _maxReferenceCount = 6;
  static const int _defaultMaxSingleReferenceMb = 20;
  static const int _defaultMaxTotalReferenceMb = 32;

  CancelToken? _currentCancelToken;
  bool _isQueueProcessorRunning = false;
  int _taskSeed = 0;
  final Random _random = Random();

  GenerationNotifier(this._service, this._db, this._ref)
      : super(GenerationState()) {
    unawaited(_restorePersistedQueue());
  }

  String? addReferenceImage(
    Uint8List image, {
    String source = 'unknown',
    Map<String, dynamic>? extra,
  }) {
    final config = _ref.read(apiConfigProvider);
    final maxSingleMb = config.referenceMaxSingleImageMb
        .clamp(_defaultMaxSingleReferenceMb, 60);
    final maxSingleBytes = maxSingleMb * 1024 * 1024;
    final maxTotalMb = maxSingleMb > _defaultMaxTotalReferenceMb
        ? maxSingleMb
        : _defaultMaxTotalReferenceMb;
    final maxTotalBytes = maxTotalMb * 1024 * 1024;

    final currentRefs = state.referenceImages;
    final currentTotalBytes =
        currentRefs.fold<int>(0, (sum, item) => sum + item.length);
    final imageFingerprint = _bytesFingerprint(image);
    final hasSameImage = currentRefs.any(
      (item) => _bytesFingerprint(item) == imageFingerprint,
    );
    if (hasSameImage) {
      unawaited(
        _log(
          level: 'warn',
          message: 'reference image rejected',
          extra: {
            'reason': 'duplicate',
            'source': source,
            'bytes': image.length,
            'fingerprint': imageFingerprint,
          },
        ),
      );
      return '该参考图已添加';
    }
    if (currentRefs.length >= _maxReferenceCount) {
      unawaited(
        _log(
          level: 'warn',
          message: 'reference image rejected',
          extra: {
            'reason': 'count_limit',
            'source': source,
            'limit': _maxReferenceCount,
            'current': currentRefs.length,
          },
        ),
      );
      return '参考图最多 $_maxReferenceCount 张';
    }
    if (image.length > maxSingleBytes) {
      unawaited(
        _log(
          level: 'warn',
          message: 'reference image rejected',
          extra: {
            'reason': 'single_size_limit',
            'source': source,
            'bytes': image.length,
            'limitBytes': maxSingleBytes,
            'limitMb': maxSingleMb,
          },
        ),
      );
      return '单张参考图不能超过 ${maxSingleMb.toStringAsFixed(0)}MB';
    }
    if (currentTotalBytes + image.length > maxTotalBytes) {
      unawaited(
        _log(
          level: 'warn',
          message: 'reference image rejected',
          extra: {
            'reason': 'total_size_limit',
            'source': source,
            'bytes': image.length,
            'currentTotalBytes': currentTotalBytes,
            'limitBytes': maxTotalBytes,
            'limitMb': maxTotalMb,
          },
        ),
      );
      return '参考图总大小不能超过 ${maxTotalMb.toStringAsFixed(0)}MB';
    }

    state = state.copyWith(referenceImages: [...state.referenceImages, image]);
    unawaited(
      _log(
        level: 'info',
        message: 'reference image added',
        extra: {
          'source': source,
          'bytes': image.length,
          'fingerprint': _bytesFingerprint(image),
          'totalRefs': state.referenceImages.length,
          if (extra != null) ...extra,
        },
      ),
    );
    return null;
  }

  void removeReferenceImage(int index) {
    final images = List<Uint8List>.from(state.referenceImages);
    if (index < 0 || index >= images.length) return;
    final removed = images[index];
    images.removeAt(index);
    state = state.copyWith(referenceImages: images);
    unawaited(
      _log(
        level: 'info',
        message: 'reference image removed',
        extra: {
          'index': index,
          'removedBytes': removed.length,
          'removedFingerprint': _bytesFingerprint(removed),
          'remainingRefs': images.length,
        },
      ),
    );
  }

  void reorderReferenceImages(int oldIndex, int newIndex) {
    final images = List<Uint8List>.from(state.referenceImages);
    if (images.length < 2) return;
    if (oldIndex < 0 || oldIndex >= images.length) return;
    if (newIndex < 0 || newIndex > images.length) return;

    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex == oldIndex) return;

    final moved = images.removeAt(oldIndex);
    images.insert(targetIndex, moved);
    state = state.copyWith(referenceImages: images);
    unawaited(
      _log(
        level: 'info',
        message: 'reference images reordered',
        extra: {
          'from': oldIndex,
          'to': targetIndex,
          'totalRefs': images.length,
        },
      ),
    );
  }

  void clearReferenceImages() {
    final count = state.referenceImages.length;
    state = state.copyWith(referenceImages: []);
    unawaited(
      _log(
        level: 'info',
        message: 'reference images cleared',
        extra: {'clearedCount': count},
      ),
    );
  }

  void clearResult() {
    state = state.copyWith(clearResult: true);
  }

  void clearQueue({bool cancelCurrent = false}) {
    if (cancelCurrent) {
      _currentCancelToken?.cancel('用户清空队列');
      state = state.copyWith(
        queue: [],
        isLoading: false,
        clearActiveTaskId: true,
      );
      unawaited(_persistQueueSnapshot());
      return;
    }

    // 仅清理待执行任务，保留当前运行任务避免状态错乱。
    final runningTasks =
        state.queue.where((t) => t.status == QueueTaskStatus.running).toList();
    state = state.copyWith(queue: runningTasks);
    unawaited(_persistQueueSnapshot());
  }

  Future<bool> useHistoryImageAsReference(String imagePath) async {
    final bytes = await _db.loadImage(imagePath);
    if (bytes == null || bytes.isEmpty) {
      return false;
    }
    final error = addReferenceImage(
      bytes,
      source: 'history',
      extra: {'path': imagePath},
    );
    return error == null;
  }

  String _bytesFingerprint(Uint8List bytes) {
    final take = bytes.length < 8 ? bytes.length : 8;
    final head =
        bytes.take(take).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${bytes.length}:$head';
  }

  Future<bool> generate(String prompt) async {
    return enqueueTask(
      prompt: prompt,
      referenceImages: state.referenceImages,
      fromRetry: false,
    );
  }

  Future<bool> enqueueTask({
    required String prompt,
    required List<Uint8List> referenceImages,
    required bool fromRetry,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) return false;
    final sessionId = await _ensureSession();

    final task = GenerationQueueTask(
      id: _nextTaskId(),
      prompt: trimmedPrompt,
      referenceImages: List<Uint8List>.from(referenceImages),
      createdAt: DateTime.now(),
      sessionId: sessionId,
      fromRetry: fromRetry,
    );

    state = state.copyWith(queue: [...state.queue, task]);
    unawaited(_persistQueueSnapshot());
    await _log(
      level: 'info',
      message: fromRetry ? 'enqueue retry task' : 'enqueue task',
      extra: {
        'taskId': task.id,
        'promptPreview': _safePromptPreview(trimmedPrompt),
        'promptLength': trimmedPrompt.length,
        'refs': referenceImages.length
      },
    );
    _processQueue();
    return true;
  }

  Future<bool> retryMessage(ChatMessage message) async {
    final refs = await _db.loadImages(message.referenceImagePaths);
    return enqueueTask(
      prompt: message.prompt,
      referenceImages: refs,
      fromRetry: true,
    );
  }

  Future<bool> duplicateQueuedTask(String taskId) async {
    final index = state.queue.indexWhere((t) => t.id == taskId);
    if (index < 0) return false;
    final task = state.queue[index];

    final duplicated = await enqueueTask(
      prompt: task.prompt,
      referenceImages: task.referenceImages,
      fromRetry: false,
    );

    if (duplicated) {
      await _log(
        level: 'info',
        message: 'duplicate queued task',
        extra: {
          'sourceTaskId': taskId,
          'promptLength': task.prompt.length,
          'refs': task.referenceImages.length,
        },
      );
    }
    return duplicated;
  }

  void cancelCurrentTask() {
    _log(level: 'info', message: 'cancel current task requested');
    _currentCancelToken?.cancel('用户取消任务');
  }

  void cancelQueuedTask(String taskId) {
    if (taskId == state.activeTaskId) {
      cancelCurrentTask();
      return;
    }

    final queue = List<GenerationQueueTask>.from(state.queue)
      ..removeWhere((task) => task.id == taskId);
    state = state.copyWith(queue: queue);
    unawaited(_persistQueueSnapshot());
  }

  void moveQueuedTaskUp(String taskId) {
    final queue = List<GenerationQueueTask>.from(state.queue);
    final index = queue.indexWhere((t) => t.id == taskId);
    if (index <= 0) return;
    if (queue[index].status == QueueTaskStatus.running ||
        queue[index - 1].status == QueueTaskStatus.running) {
      return;
    }

    final task = queue.removeAt(index);
    queue.insert(index - 1, task);
    state = state.copyWith(queue: queue);
    unawaited(_persistQueueSnapshot());
  }

  void moveQueuedTaskDown(String taskId) {
    final queue = List<GenerationQueueTask>.from(state.queue);
    final index = queue.indexWhere((t) => t.id == taskId);
    if (index < 0 || index >= queue.length - 1) return;
    if (queue[index].status == QueueTaskStatus.running ||
        queue[index + 1].status == QueueTaskStatus.running) {
      return;
    }

    final task = queue.removeAt(index);
    queue.insert(index + 1, task);
    state = state.copyWith(queue: queue);
    unawaited(_persistQueueSnapshot());
  }

  void moveQueuedTaskToFront(String taskId) {
    final queue = List<GenerationQueueTask>.from(state.queue);
    final index = queue.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final task = queue[index];
    if (task.status == QueueTaskStatus.running) return;

    var targetIndex =
        queue.indexWhere((t) => t.status == QueueTaskStatus.pending);
    if (targetIndex < 0 || index == targetIndex) return;

    queue.removeAt(index);
    if (index < targetIndex) {
      targetIndex -= 1;
    }
    queue.insert(targetIndex, task);
    state = state.copyWith(queue: queue);
    unawaited(_persistQueueSnapshot());
  }

  void updateQueuedTaskPrompt(String taskId, String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    final queue = state.queue.map((task) {
      if (task.id == taskId && task.status == QueueTaskStatus.pending) {
        return task.copyWith(prompt: trimmed);
      }
      return task;
    }).toList();
    state = state.copyWith(queue: queue);
    unawaited(_persistQueueSnapshot());
  }

  Future<void> _processQueue() async {
    if (_isQueueProcessorRunning) return;
    _isQueueProcessorRunning = true;
    final configAtStart = _ref.read(apiConfigProvider);
    final keepAliveEnabled = configAtStart.backgroundKeepAliveEnabled;
    final residentEnabled = configAtStart.notificationResidentEnabled;
    if (keepAliveEnabled || residentEnabled) {
      await ForegroundKeepAliveService.startIfNeeded();
    }

    // 显示灵动岛/悬浮窗初始状态
    await ForegroundKeepAliveService.showFloatingWindow(
      status: ForegroundKeepAliveService.statusRunning,
      queueCount: state.queue.length,
      progress: 0,
      estimatedSeconds: await _estimateGenerationTime(state.queue.first.referenceImages.isNotEmpty),
    );

    try {
      while (true) {
        final nextTask = _nextPendingTask();
        if (nextTask == null) break;

        final config = _ref.read(apiConfigProvider);
        _service.updateConfig(config);

        state = state.copyWith(
          isLoading: true,
          activeTaskId: nextTask.id,
          clearResult: true,
          queue: state.queue.map((task) {
            if (task.id == nextTask.id) {
              return task.copyWith(status: QueueTaskStatus.running);
            }
            return task;
          }).toList(),
        );
        unawaited(_persistQueueSnapshot());
        await _log(
          level: 'info',
          message: 'start task',
          extra: {
            'taskId': nextTask.id,
            'fromRetry': nextTask.fromRetry,
            'refs': nextTask.referenceImages.length,
          },
        );

        final sessionId = nextTask.sessionId ?? await _ensureSession();
        final stopwatch = Stopwatch()..start();

        _currentCancelToken = CancelToken();
        final taskResult = await _runTaskWithRetry(
          task: nextTask,
          config: config,
          cancelToken: _currentCancelToken!,
        );
        _currentCancelToken = null;

        stopwatch.stop();
        var result = taskResult.result;
        final generationDurationMs = stopwatch.elapsedMilliseconds;

        if (!result.success && taskResult.retryCount > 0) {
          result = GenerationResult.error(
            '${result.errorMessage ?? '生成失败'}\n\n已自动重试 ${taskResult.retryCount} 次。',
            errorCode: result.errorCode,
            retryable: result.retryable,
            retryCount: taskResult.retryCount,
          );
        }

        state = state.copyWith(result: result);

        final message = await _db.addMessage(
          sessionId: sessionId,
          prompt: nextTask.prompt,
          imageUrl: result.imageUrl,
          imageBytes: result.imageBytes,
          isSuccess: result.success,
          errorMessage: result.errorMessage,
          generationDurationMs: generationDurationMs,
          referenceImagesBytes: nextTask.referenceImages,
        );

        await _ref.read(messagesProvider.notifier).addMessage(message);
        _ref.read(sessionsProvider.notifier).loadSessions();
        _ref.invalidate(usageStatsProvider);

        // 振动反馈：生成成功
        await HapticService.success();

        await _log(
          level: result.success ? 'info' : 'error',
          message: result.success ? 'task success' : 'task failed',
          extra: {
            'taskId': nextTask.id,
            'retryCount': taskResult.retryCount,
            'durationMs': generationDurationMs,
            'errorCode': result.errorCode,
          },
        );

        // 记录成功生成的时间到统计
        if (result.success) {
          await _ref.read(storageServiceProvider).recordGenerationTime(
            hasReferenceImages: nextTask.referenceImages.isNotEmpty,
            durationMs: generationDurationMs,
            success: true,
          );
        }

        // 更新灵动岛/悬浮窗状态
        if (result.success) {
          await ForegroundKeepAliveService.updateGenerationStatus(
            status: ForegroundKeepAliveService.statusSuccess,
            queueCount: state.queue.length - 1,
            progress: 100,
          );
          await ForegroundKeepAliveService.showFloatingWindow(
            status: ForegroundKeepAliveService.statusSuccess,
            queueCount: state.queue.length - 1,
            progress: 100,
          );
        } else {
          await ForegroundKeepAliveService.updateGenerationStatus(
            status: ForegroundKeepAliveService.statusError,
            queueCount: state.queue.length - 1,
            progress: 0,
            message: result.errorMessage ?? '生成失败',
          );
          await ForegroundKeepAliveService.showFloatingWindow(
            status: ForegroundKeepAliveService.statusError,
            queueCount: state.queue.length - 1,
            progress: 0,
          );
        }

        state = state.copyWith(
          isLoading: false,
          clearActiveTaskId: true,
          queue: state.queue.where((t) => t.id != nextTask.id).toList(),
        );
        unawaited(_persistQueueSnapshot());
      }
    } catch (e, stackTrace) {
      await _log(
        level: 'error',
        message: 'queue processor crashed',
        extra: {
          'error': '$e',
          'stackTrace': '$stackTrace',
        },
      );
      final activeTaskId = state.activeTaskId;
      state = state.copyWith(
        isLoading: false,
        clearActiveTaskId: true,
        result: GenerationResult.error('内部错误: $e', errorCode: 'internal_error'),
        queue: activeTaskId == null
            ? state.queue
            : state.queue.where((t) => t.id != activeTaskId).toList(),
      );

      // 振动反馈：内部错误
      await HapticService.error();

      // 更新灵动岛为错误状态
      await ForegroundKeepAliveService.updateGenerationStatus(
        status: ForegroundKeepAliveService.statusError,
        queueCount: state.queue.length,
        progress: 0,
        message: '内部错误',
      );
      await ForegroundKeepAliveService.showFloatingWindow(
        status: ForegroundKeepAliveService.statusError,
        queueCount: state.queue.length,
        progress: 0,
      );
    } finally {
      _isQueueProcessorRunning = false;
      final stillResident =
          _ref.read(apiConfigProvider).notificationResidentEnabled;
      if (keepAliveEnabled && !stillResident) {
        await ForegroundKeepAliveService.stopIfRunning();
      }
      // 延迟隐藏悬浮窗
      await Future.delayed(const Duration(seconds: 3));
      await ForegroundKeepAliveService.hideFloatingWindow();
      unawaited(_persistQueueSnapshot());
    }
  }

  GenerationQueueTask? _nextPendingTask() {
    for (final task in state.queue) {
      if (task.status == QueueTaskStatus.pending) {
        return task;
      }
    }
    return null;
  }

  Future<int> _ensureSession() async {
    var sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId != null) return sessionId;

    final session = await _ref.read(sessionsProvider.notifier).createSession();
    sessionId = session.id!;
    _ref.read(currentSessionIdProvider.notifier).state = sessionId;
    await _ref.read(storageServiceProvider).saveLastSessionId(sessionId);
    return sessionId;
  }

  Future<_TaskRunResult> _runTaskWithRetry({
    required GenerationQueueTask task,
    required ApiConfig config,
    required CancelToken cancelToken,
  }) async {
    // Freeze config at task start to prevent live settings changes from mutating
    // an already submitted/running task.
    final taskService = NanoBananaService(config: config);
    final timeout =
        Duration(seconds: config.requestTimeoutSeconds.clamp(30, 900).toInt());
    final maxRetry = config.autoRetryEnabled ? config.maxRetryCount : 0;

    var retryCount = 0;
    GenerationResult result =
        GenerationResult.error('未知错误', errorCode: 'unknown');

    while (true) {
      if (cancelToken.isCancelled) {
        await _log(level: 'warn', message: 'task cancelled before request');
        return _TaskRunResult(
          result: GenerationResult.error('任务已取消', errorCode: 'cancelled'),
          retryCount: retryCount,
        );
      }

      if (task.referenceImages.isNotEmpty) {
        result = await taskService.generateFromImages(
          prompt: task.prompt,
          referenceImages: task.referenceImages,
          timeout: timeout,
          cancelToken: cancelToken,
          idempotencyKey: config.sendIdempotencyKey ? task.id : null,
          degradeLevel: config.referenceAutoDegradeOnRetry ? retryCount : 0,
        );
      } else {
        result = await taskService.generateFromText(
          task.prompt,
          timeout: timeout,
          cancelToken: cancelToken,
          idempotencyKey: config.sendIdempotencyKey ? task.id : null,
        );
      }
      result = _decorateFailureMessage(
        result: result,
        hasReferenceImages: task.referenceImages.isNotEmpty,
        config: config,
      );

      if (result.success) {
        result = await _materializeRemoteImage(
          service: taskService,
          result: result,
        );
        return _TaskRunResult(result: result, retryCount: retryCount);
      }
      if (result.errorCode == 'cancelled') {
        return _TaskRunResult(result: result, retryCount: retryCount);
      }
      if (!config.autoRetryEnabled) {
        return _TaskRunResult(result: result, retryCount: retryCount);
      }
      if (!result.retryable || retryCount >= maxRetry) {
        return _TaskRunResult(result: result, retryCount: retryCount);
      }

      retryCount += 1;
      await _log(
        level: 'warn',
        message: 'retry task',
        extra: {
          'taskId': task.id,
          'retryCount': retryCount,
          'errorCode': result.errorCode,
        },
      );
      final delay = _buildRetryDelay(config: config, retryCount: retryCount);
      await _log(
        level: 'info',
        message: 'retry delay scheduled',
        extra: {
          'taskId': task.id,
          'retryCount': retryCount,
          'delayMs': delay.inMilliseconds,
        },
      );
      await Future.delayed(delay);
    }
  }

  Duration _buildRetryDelay({
    required ApiConfig config,
    required int retryCount,
  }) {
    final baseMs = config.retryBaseDelayMs.clamp(200, 10000);
    final maxMs = config.retryMaxDelayMs.clamp(baseMs, 30000);
    final cappedPower = retryCount.clamp(1, 12) - 1;
    var delayMs = baseMs * (1 << cappedPower);
    if (delayMs > maxMs) {
      delayMs = maxMs;
    }

    final jitterPercent = config.retryJitterPercent.clamp(0, 60);
    if (jitterPercent <= 0) {
      return Duration(milliseconds: delayMs);
    }

    final maxJitter = (delayMs * (jitterPercent / 100)).round();
    final jitter = _random.nextInt(maxJitter * 2 + 1) - maxJitter;
    final jitteredMs = (delayMs + jitter).clamp(100, maxMs);
    return Duration(milliseconds: jitteredMs);
  }

  Future<void> _restorePersistedQueue() async {
    try {
      final storage = _ref.read(storageServiceProvider);
      final restoredQueue = await storage.loadPendingQueue();
      if (restoredQueue.isEmpty) return;
      state = state.copyWith(queue: [...state.queue, ...restoredQueue]);
      await _log(
        level: 'info',
        message: 'queue restored from disk',
        extra: {'restoredCount': restoredQueue.length},
      );
      _processQueue();
    } catch (e) {
      await _log(
        level: 'warn',
        message: 'queue restore failed',
        extra: {'error': '$e'},
      );
    }
  }

  Future<void> _persistQueueSnapshot() async {
    try {
      final storage = _ref.read(storageServiceProvider);
      await storage.savePendingQueue(state.queue);
    } catch (e) {
      await _log(
        level: 'warn',
        message: 'queue snapshot save failed',
        extra: {'error': '$e'},
      );
    }
  }

  Future<void> _log({
    required String level,
    required String message,
    Map<String, dynamic>? extra,
  }) async {
    final logger = _ref.read(appLogServiceProvider);
    await logger.append(level: level, message: message, extra: extra);
  }

  Future<GenerationResult> _materializeRemoteImage({
    required NanoBananaService service,
    required GenerationResult result,
  }) async {
    final imageUrl = result.imageUrl?.trim() ?? '';
    if (!result.success || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return result;
    }
    if (result.imageBytes != null && result.imageBytes!.isNotEmpty) {
      return result;
    }

    final bytes = await service.downloadImageBytes(
      imageUrl,
      timeout: const Duration(seconds: 25),
    );
    if (bytes == null || bytes.isEmpty) {
      await _log(
        level: 'warn',
        message: 'generated image cache download failed',
        extra: {'url': imageUrl},
      );
      return result;
    }
    await _log(
      level: 'info',
      message: 'generated image cache downloaded',
      extra: {
        'url': imageUrl,
        'bytes': bytes.length,
      },
    );
    return GenerationResult(
      success: true,
      imageUrl: imageUrl,
      imageBytes: bytes,
      timestamp: result.timestamp,
    );
  }

  String _safePromptPreview(String prompt) {
    final oneLine = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= 80) return oneLine;
    return '${oneLine.substring(0, 80)}...';
  }

  GenerationResult _decorateFailureMessage({
    required GenerationResult result,
    required bool hasReferenceImages,
    required ApiConfig config,
  }) {
    if (result.success || result.errorCode == 'cancelled') {
      return result;
    }

    final code = (result.errorCode ?? '').toLowerCase();
    final category = _classifyError(code);
    final original = result.errorMessage ?? '请求失败';
    final alreadyTagged = original.startsWith('[');
    final lowerMessage = original.toLowerCase();

    var message = alreadyTagged ? original : '[$category] $original';
    if (_shouldSuggestReferenceCompat(
      hasReferenceImages: hasReferenceImages,
      config: config,
      code: code,
      lowerMessage: lowerMessage,
      formattedMessage: message,
    )) {
      message += '\n\n建议：设置 -> 请求与重试 -> 开启“参考图兼容性增强”后重试。';
    }
    if (code == 'http_429' && !message.contains('稍后再试')) {
      message += '\n\n建议：这是网关/上游限流或过载，通常请求可能未进入上游执行记录。请稍后重试，或切换分组 / Provider / 模型后再试。';
    }
    return GenerationResult.error(
      message,
      errorCode: result.errorCode,
      retryable: result.retryable,
      retryCount: result.retryCount,
    );
  }

  String _classifyError(String code) {
    if (code == 'http_429') return '限流/上游过载';
    if (code == 'http_401' || code == 'http_403') return '鉴权失败';
    if (code.startsWith('http_4')) return '请求参数/兼容性';
    if (code.startsWith('http_5')) return '服务端异常';
    if (_isNetworkLikeError(code)) return '网络异常';
    if (code == 'cancelled') return '用户取消';
    return '未知错误';
  }

  bool _shouldSuggestReferenceCompat({
    required bool hasReferenceImages,
    required ApiConfig config,
    required String code,
    required String lowerMessage,
    required String formattedMessage,
  }) {
    if (!hasReferenceImages || config.referenceCompatEnhanced) {
      return false;
    }
    if (_isNetworkLikeError(code) ||
        code == 'http_429' ||
        code == 'http_401' ||
        code == 'http_403' ||
        formattedMessage.contains('参考图兼容性增强')) {
      return false;
    }
    if (code == 'http_400' || code == 'http_415' || code == 'http_422') {
      return true;
    }
    return lowerMessage.contains('image') ||
        lowerMessage.contains('base64') ||
        lowerMessage.contains('mime') ||
        lowerMessage.contains('format') ||
        lowerMessage.contains('unsupported') ||
        lowerMessage.contains('invalid') ||
        lowerMessage.contains('图片') ||
        lowerMessage.contains('参考图') ||
        lowerMessage.contains('格式');
  }

  bool _isNetworkLikeError(String code) {
    return code == 'connection_timeout' ||
        code == 'send_timeout' ||
        code == 'receive_timeout' ||
        code == 'connection_error' ||
        code == 'connection_aborted' ||
        code == 'unknown_timeout' ||
        code == 'unknown_network_error' ||
        code == 'ssl_error' ||
        code == 'bad_certificate';
  }

  String _nextTaskId() {
    _taskSeed += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_taskSeed';
  }

  /// 估算生成所需时间（秒），基于历史数据
  Future<int> _estimateGenerationTime(bool hasReferenceImages) async {
    return _ref
        .read(storageServiceProvider)
        .getEstimatedGenerationTime(hasReferenceImages);
  }

}
