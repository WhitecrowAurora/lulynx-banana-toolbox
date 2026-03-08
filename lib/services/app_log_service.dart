import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppLogService {
  static const int _maxLogSizeBytes = 2 * 1024 * 1024;
  static const int _retainLogSizeBytes = 1 * 1024 * 1024;

  Future<Directory> _logsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, 'logs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _activeLogFile() async {
    final dir = await _logsDir();
    return File(path.join(dir.path, 'app.log'));
  }

  Future<void> append({
    required String level,
    required String message,
    Map<String, dynamic>? extra,
  }) async {
    final file = await _activeLogFile();
    await _trimLogIfNeeded(file);
    final now = DateTime.now().toIso8601String();
    final entry = <String, dynamic>{
      'time': now,
      'level': level,
      'message': _redact(message),
      if (extra != null) 'extra': _redactJson(extra),
    };
    await file.writeAsString('${jsonEncode(entry)}\n', mode: FileMode.append);
  }

  Future<void> _trimLogIfNeeded(File file) async {
    if (!await file.exists()) return;
    final size = await file.length();
    if (size <= _maxLogSizeBytes) return;

    final bytes = await file.readAsBytes();
    if (bytes.length <= _retainLogSizeBytes) return;
    final start = bytes.length - _retainLogSizeBytes;
    final tail = bytes.sublist(start);
    await file.writeAsBytes(tail, mode: FileMode.write, flush: true);
  }

  Future<String> readAll() async {
    final file = await _activeLogFile();
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<String?> exportLog() async {
    final source = await _activeLogFile();
    if (!await source.exists()) return null;

    final dir = await _logsDir();
    final export = File(
      path.join(
        dir.path,
        'app_log_export_${DateTime.now().millisecondsSinceEpoch}.log',
      ),
    );
    await source.copy(export.path);
    return export.path;
  }

  Future<void> clearLogs() async {
    final dir = await _logsDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }

  Future<int> getLogSizeBytes() async {
    final dir = await _logsDir();
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Map<String, dynamic> _redactJson(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      final lower = key.toLowerCase();
      if (lower.contains('authorization') ||
          lower.contains('api') && lower.contains('key')) {
        result[key] = '***REDACTED***';
      } else if (lower.contains('prompt') && value is String) {
        result[key] = _truncate(value);
      } else if (value is String) {
        result[key] = _redact(value);
      } else if (value is Map<String, dynamic>) {
        result[key] = _redactJson(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  String _redact(String input) {
    var out = input;
    final authPattern = RegExp(r'(Authorization\s*[:=]\s*Bearer\s+)([^\s,}]+)',
        caseSensitive: false);
    out =
        out.replaceAllMapped(authPattern, (m) => '${m.group(1)}***REDACTED***');

    final skPattern = RegExp(r'\bsk-[A-Za-z0-9\-_]{10,}\b');
    out = out.replaceAllMapped(skPattern, (_) => 'sk-***REDACTED***');
    return out;
  }

  String _truncate(String input, {int max = 120}) {
    final oneLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= max) return oneLine;
    return '${oneLine.substring(0, max)}...';
  }
}
