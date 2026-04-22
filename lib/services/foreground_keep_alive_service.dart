import 'dart:io';

import 'package:flutter/services.dart';

class ForegroundKeepAliveService {
  static const MethodChannel _channel =
      MethodChannel('com.nanobanana/foreground_service');

  static bool _running = false;

  /// Status constants matching Kotlin implementation
  static const String statusIdle = 'idle';
  static const String statusRunning = 'running';
  static const String statusSuccess = 'success';
  static const String statusError = 'error';

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

  /// Update notification with generation progress (dynamic island style)
  static Future<void> updateGenerationStatus({
    required String status,
    int queueCount = 0,
    int progress = 0,
    String message = '',
  }) async {
    if (!Platform.isAndroid || !_running) return;
    try {
      await _channel.invokeMethod<bool>(
        'updateGenerationStatus',
        <String, dynamic>{
          'status': status,
          'queueCount': queueCount,
          'progress': progress,
          'message': message,
        },
      );
    } catch (_) {
      // Ignore update failures
    }
  }

  /// Show floating window (mini dynamic island overlay)
  static Future<void> showFloatingWindow({
    required String status,
    int queueCount = 0,
    int progress = 0,
    int? estimatedSeconds,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'showFloatingWindow',
        <String, dynamic>{
          'status': status,
          'queueCount': queueCount,
          'progress': progress,
          'estimatedSeconds': estimatedSeconds,
        },
      );
    } catch (_) {
      // Floating window may not have permission, ignore
    }
  }

  /// Update floating window
  static Future<void> updateFloatingWindow({
    required String status,
    int queueCount = 0,
    int progress = 0,
    int? estimatedSeconds,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'updateFloatingWindow',
        <String, dynamic>{
          'status': status,
          'queueCount': queueCount,
          'progress': progress,
          'estimatedSeconds': estimatedSeconds,
        },
      );
    } catch (_) {
      // Floating window may not have permission, ignore
    }
  }

  /// Hide floating window
  static Future<void> hideFloatingWindow() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('hideFloatingWindow');
    } catch (_) {
      // Ignore
    }
  }

  /// Check if floating window permission is granted
  static Future<bool> canShowFloatingWindow() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('canShowFloatingWindow');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request floating window permission
  static Future<void> requestFloatingWindowPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestFloatingWindowPermission');
    } catch (_) {
      // Ignore
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
