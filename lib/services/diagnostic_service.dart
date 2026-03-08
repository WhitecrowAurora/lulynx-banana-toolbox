import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/api_config.dart';
import '../models/generation_queue_task.dart';
import '../models/usage_stats.dart';

class DiagnosticService {
  Future<String> buildReport({
    required ApiConfig config,
    required UsageStats? usageStats,
    required List<GenerationQueueTask> queue,
    required bool isGenerating,
    required int imageCacheBytes,
    required int logBytes,
    required String recentLogs,
  }) async {
    final package = await _safePackageInfo();
    final device = await _safeDeviceInfo();
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'generatedAt': now,
      'app': {
        'appName': package?.appName ?? 'nano_banana_app',
        'packageName': package?.packageName ?? 'unknown',
        'version': package?.version ?? 'unknown',
        'buildNumber': package?.buildNumber ?? 'unknown',
      },
      'device': device,
      'config': _redactedConfig(config),
      'runtime': {
        'isGenerating': isGenerating,
        'queueLength': queue.length,
        'pendingCount':
            queue.where((e) => e.status == QueueTaskStatus.pending).length,
        'runningCount':
            queue.where((e) => e.status == QueueTaskStatus.running).length,
      },
      'storage': {
        'imageCacheBytes': imageCacheBytes,
        'logBytes': logBytes,
      },
      'usageStats': usageStats == null
          ? null
          : {
              'totalCount': usageStats.totalCount,
              'successCount': usageStats.successCount,
              'failureCount': usageStats.failureCount,
              'avgDurationMs': usageStats.avgDurationMs,
            },
      'queuePreview': queue
          .map(
            (e) => {
              'id': e.id,
              'status': e.status.name,
              'fromRetry': e.fromRetry,
              'createdAt': e.createdAt.toIso8601String(),
              'promptLength': e.prompt.length,
              'refs': e.referenceImages.length,
            },
          )
          .toList(),
      'recentLogs': recentLogs,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, dynamic> _redactedConfig(ApiConfig config) {
    final map = config.toJson();
    if (map.containsKey('apiKey')) {
      map['apiKey'] = _maskSecret((map['apiKey'] ?? '').toString());
    }
    if (map.containsKey('baseUrl')) {
      map['baseUrl'] = (map['baseUrl'] ?? '').toString().trim();
    }
    return map;
  }

  String _maskSecret(String secret) {
    if (secret.isEmpty) return '';
    if (secret.length <= 8) return '***';
    return '${secret.substring(0, 3)}***${secret.substring(secret.length - 3)}';
  }

  Future<PackageInfo?> _safePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _safeDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return {
          'platform': 'android',
          'brand': info.brand,
          'model': info.model,
          'manufacturer': info.manufacturer,
          'sdkInt': info.version.sdkInt,
          'release': info.version.release,
        };
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return {
          'platform': 'ios',
          'name': info.name,
          'model': info.model,
          'systemName': info.systemName,
          'systemVersion': info.systemVersion,
        };
      }
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      };
    } catch (_) {
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      };
    }
  }
}
