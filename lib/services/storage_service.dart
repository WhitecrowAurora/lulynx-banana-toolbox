import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_config.dart';
import '../models/generation_queue_task.dart';

class StorageService {
  static const _configKey = 'api_config';
  static const _lastSessionIdKey = 'last_session_id';
  static const _apiKeyEncodeMarker = 'v1:';
  static const _apiKeyObfuscationSeed = 'nano_banana_local_seed_2026';
  static const _queueSnapshotFileName = 'generation_queue_v1.json';

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
}
