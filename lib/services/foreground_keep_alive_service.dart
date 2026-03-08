import 'dart:io';

import 'package:flutter/services.dart';

class ForegroundKeepAliveService {
  static const MethodChannel _channel =
      MethodChannel('com.nanobanana/foreground_service');

  static bool _running = false;

  static Future<void> startIfNeeded() async {
    if (!Platform.isAndroid || _running) return;
    try {
      await _channel.invokeMethod<bool>(
        'startKeepAliveService',
        <String, dynamic>{
          'title': 'Nano Banana 正在后台运行',
          'text': '正在处理生成任务，请勿关闭应用',
        },
      );
      _running = true;
    } catch (_) {
      // Keep generation flow unaffected if foreground service is unavailable.
    }
  }

  static Future<void> stopIfRunning() async {
    if (!Platform.isAndroid || !_running) return;
    try {
      await _channel.invokeMethod<bool>('stopKeepAliveService');
    } catch (_) {
      // Ignore stop failures.
    } finally {
      _running = false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? ignoring = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return ignoring ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {
      // Keep settings entry non-blocking if native intent launch fails.
    }
  }
}
