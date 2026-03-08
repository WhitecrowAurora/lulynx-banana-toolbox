import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/api_config.dart';
import 'chat_database_service.dart';
import 'storage_service.dart';

class BackupService {
  final ChatDatabaseService _db;
  final StorageService _storage;

  BackupService({
    required ChatDatabaseService db,
    required StorageService storage,
  })  : _db = db,
        _storage = storage;

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> createBackupFile() async {
    final config = await _storage.loadConfig();
    final chatData = await _db.exportData();
    final data = {
      'schema': 1,
      'created_at': DateTime.now().toIso8601String(),
      'config': config.toJson(),
      'chat': chatData,
    };

    final dir = await _backupDir();
    final file = File(
      path.join(dir.path,
          'nano_banana_backup_${DateTime.now().millisecondsSinceEpoch}.json'),
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<void> restoreFromFile(String filePath) async {
    final file = File(filePath);
    final raw = await file.readAsString();
    final data = Map<String, dynamic>.from(jsonDecode(raw));

    final configMap = Map<String, dynamic>.from(data['config'] as Map? ?? {});
    final config = ApiConfig.fromJson(configMap);
    await _storage.saveConfig(config);

    final chat = Map<String, dynamic>.from(data['chat'] as Map? ?? {});
    await _db.importData(chat, overwrite: true);
  }
}
