import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_config.dart';
import '../models/api_profile.dart';
import '../models/generation_queue_task.dart';

class StorageService {
  static const _configKey = 'api_config';
  static const _apiProfilesKey = 'api_profiles_v1';
  static const _lastSessionIdKey = 'last_session_id';
  static const _apiKeyEncodeMarker = 'v1:';
  static const _apiKeyObfuscationSeed = 'nano_banana_local_seed_2026';
  static const _queueSnapshotFileName = 'generation_queue_v1.json';
  static const _generationStatsKey = 'generation_time_stats_v1';
  static const _maxStatsHistory = 50; // Keep last 50 records per type

  Future<ApiConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_configKey);

    if (configJson != null) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(configJson));
        final rawApiKey = map['apiKey']?.toString() ?? '';
        if (rawApiKey.startsWith(_apiKeyEncodeMarker)) {
          map['apiKey'] = _decodeApiKey(rawApiKey);
        }
        final config = ApiConfig.fromJson(map);
        final timeoutInStorage = _toInt(map['requestTimeoutSeconds']);
        final retryInStorage = _toInt(map['maxRetryCount']);
        final hasAutoRetryFlag = map.containsKey('autoRetryEnabled');

        final upgradeTimeout = timeoutInStorage == 180;
        final upgradeRetry = retryInStorage == 2;
        if (upgradeTimeout || upgradeRetry || !hasAutoRetryFlag) {
          final upgraded = config.copyWith(
            requestTimeoutSeconds:
                upgradeTimeout ? 600 : config.requestTimeoutSeconds,
            maxRetryCount: upgradeRetry ? 10 : config.maxRetryCount,
            autoRetryEnabled:
                hasAutoRetryFlag ? config.autoRetryEnabled : false,
          );
          await saveConfig(upgraded);
          return upgraded;
        }

        return config;
      } catch (e) {
        return ApiConfig.empty();
      }
    }

    return ApiConfig.empty();
  }

  Future<void> saveConfig(ApiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final map = Map<String, dynamic>.from(config.toJson());
    map['apiKey'] = _encodeApiKey(config.apiKey);
    await prefs.setString(_configKey, jsonEncode(map));
  }

  Future<List<ApiProfile>> loadApiProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_apiProfilesKey);
    if (raw == null || raw.trim().isEmpty) return const <ApiProfile>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ApiProfile>[];
      final profiles = <ApiProfile>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rawApiKey = map['apiKey']?.toString() ?? '';
        if (rawApiKey.startsWith(_apiKeyEncodeMarker)) {
          map['apiKey'] = _decodeApiKey(rawApiKey);
        }
        final profile = ApiProfile.fromJson(map);
        if (profile.id.trim().isEmpty) continue;
        profiles.add(profile);
      }
      return profiles;
    } catch (_) {
      return const <ApiProfile>[];
    }
  }

  Future<void> saveApiProfiles(List<ApiProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = profiles
        .map((profile) {
          final map = Map<String, dynamic>.from(profile.toJson());
          map['apiKey'] = _encodeApiKey(profile.apiKey);
          return map;
        })
        .toList(growable: false);
    await prefs.setString(_apiProfilesKey, jsonEncode(payload));
  }

  Future<int?> loadLastSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSessionIdKey);
  }

  Future<void> saveLastSessionId(int? sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (sessionId == null) {
      await prefs.remove(_lastSessionIdKey);
      return;
    }
    await prefs.setInt(_lastSessionIdKey, sessionId);
  }

  Future<void> savePendingQueue(List<GenerationQueueTask> queue) async {
    final file = await _queueSnapshotFile();
    if (queue.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    final payload = queue
        .map(
          (task) => task.copyWith(status: QueueTaskStatus.pending).toJson(),
        )
        .toList(growable: false);
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<List<GenerationQueueTask>> loadPendingQueue() async {
    try {
      final file = await _queueSnapshotFile();
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final queue = <GenerationQueueTask>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final task = GenerationQueueTask.fromJson(
          map,
        ).copyWith(status: QueueTaskStatus.pending);
        if (task.prompt.trim().isEmpty) continue;
        queue.add(task);
      }
      return queue;
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearPendingQueue() async {
    final file = await _queueSnapshotFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _queueSnapshotFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'runtime'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, _queueSnapshotFileName));
  }

  String _encodeApiKey(String plain) {
    if (plain.isEmpty) return plain;
    final plainBytes = utf8.encode(plain);
    final keyBytes = utf8.encode(_apiKeyObfuscationSeed);
    final encodedBytes = List<int>.generate(
      plainBytes.length,
      (i) => plainBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return '$_apiKeyEncodeMarker${base64Encode(encodedBytes)}';
  }

  String _decodeApiKey(String encoded) {
    if (!encoded.startsWith(_apiKeyEncodeMarker)) return encoded;
    final payload = encoded.substring(_apiKeyEncodeMarker.length);
    if (payload.isEmpty) return '';

    try {
      final encodedBytes = base64Decode(payload);
      final keyBytes = utf8.encode(_apiKeyObfuscationSeed);
      final plainBytes = List<int>.generate(
        encodedBytes.length,
        (i) => encodedBytes[i] ^ keyBytes[i % keyBytes.length],
      );
      return utf8.decode(plainBytes);
    } catch (_) {
      return '';
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  // ========== Generation Time Statistics ==========

  /// Record a generation time for statistics
  Future<void> recordGenerationTime({
    required bool hasReferenceImages,
    required int durationMs,
    required bool success,
  }) async {
    if (!success || durationMs <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final type = hasReferenceImages ? 'with_refs' : 'text_only';
    final key = '${_generationStatsKey}_$type';

    try {
      final existing = prefs.getStringList(key) ?? [];
      final record = '${DateTime.now().millisecondsSinceEpoch}:$durationMs';

      // Keep only last _maxStatsHistory records
      final updated = [...existing, record];
      if (updated.length > _maxStatsHistory) {
        updated.removeAt(0);
      }

      await prefs.setStringList(key, updated);
    } catch (_) {
      // Ignore storage errors
    }
  }

  /// Get estimated generation time based on historical data
  /// Returns estimated seconds with weighted average (recent records have higher weight)
  Future<int> getEstimatedGenerationTime(bool hasReferenceImages) async {
    final prefs = await SharedPreferences.getInstance();
    final type = hasReferenceImages ? 'with_refs' : 'text_only';
    final key = '${_generationStatsKey}_$type';

    try {
      final records = prefs.getStringList(key);
      if (records == null || records.isEmpty) {
        // No historical data, return default estimates
        return hasReferenceImages ? 35 : 22;
      }

      // Parse records and calculate weighted average
      // More recent records get higher weight
      var totalWeight = 0.0;
      var weightedSum = 0.0;

      for (var i = 0; i < records.length; i++) {
        final parts = records[i].split(':');
        if (parts.length != 2) continue;

        final durationMs = int.tryParse(parts[1]);
        if (durationMs == null || durationMs <= 0) continue;

        // Weight: recent records have higher weight
        // Linear weight from 1.0 (oldest) to 2.0 (newest)
        final weight = 1.0 + (i / records.length);
        totalWeight += weight;
        weightedSum += durationMs * weight;
      }

      if (totalWeight == 0) {
        return hasReferenceImages ? 35 : 22;
      }

      // Convert to seconds and round
      final avgMs = weightedSum / totalWeight;
      final avgSeconds = (avgMs / 1000).round();

      // Clamp to reasonable bounds
      final minSeconds = hasReferenceImages ? 10 : 5;
      final maxSeconds = hasReferenceImages ? 180 : 120;
      return avgSeconds.clamp(minSeconds, maxSeconds);
    } catch (_) {
      return hasReferenceImages ? 35 : 22;
    }
  }

  /// Get statistics summary for display
  Future<Map<String, dynamic>> getGenerationStats() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, dynamic>{};

    for (final type in ['text_only', 'with_refs']) {
      final key = '${_generationStatsKey}_$type';
      final records = prefs.getStringList(key);

      if (records == null || records.isEmpty) {
        result[type] = {
          'count': 0,
          'avgSeconds': type == 'with_refs' ? 35 : 22,
          'minSeconds': null,
          'maxSeconds': null,
        };
        continue;
      }

      final durations = <int>[];
      for (final record in records) {
        final parts = record.split(':');
        if (parts.length != 2) continue;
        final durationMs = int.tryParse(parts[1]);
        if (durationMs != null && durationMs > 0) {
          durations.add((durationMs / 1000).round());
        }
      }

      if (durations.isEmpty) {
        result[type] = {
          'count': 0,
          'avgSeconds': type == 'with_refs' ? 35 : 22,
          'minSeconds': null,
          'maxSeconds': null,
        };
        continue;
      }

      durations.sort();
      result[type] = {
        'count': durations.length,
        'avgSeconds': durations.reduce((a, b) => a + b) ~/ durations.length,
        'minSeconds': durations.first,
        'maxSeconds': durations.last,
        'medianSeconds': durations[durations.length ~/ 2],
      };
    }

    return result;
  }

  /// Clear all generation statistics
  Future<void> clearGenerationStats() async {
    final prefs = await SharedPreferences.getInstance();
    for (final type in ['text_only', 'with_refs']) {
      await prefs.remove('${_generationStatsKey}_$type');
    }
  }
}
