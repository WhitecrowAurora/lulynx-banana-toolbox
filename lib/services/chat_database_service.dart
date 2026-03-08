import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/chat_models.dart';
import '../models/usage_stats.dart';

class ChatDatabaseService {
  static Database? _database;
  static const String _dbName = 'nano_banana_chat.db';
  static const int _dbVersion = 3;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            prompt TEXT NOT NULL,
            image_url TEXT,
            image_path TEXT,
            reference_image_paths TEXT,
            is_success INTEGER NOT NULL DEFAULT 1,
            error_message TEXT,
            generation_duration_ms INTEGER,
            created_at TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureMessagesColumns(db);
      },
      onOpen: (db) async {
        await _ensureMessagesColumns(db);
      },
    );
  }

  Future<void> _ensureMessagesColumns(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(messages)');
    final names = columns
        .map((column) => column['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('image_path')) {
      await db.execute('ALTER TABLE messages ADD COLUMN image_path TEXT');
    }
    if (!names.contains('reference_image_paths')) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN reference_image_paths TEXT',
      );
    }
    if (!names.contains('is_success')) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN is_success INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (!names.contains('error_message')) {
      await db.execute('ALTER TABLE messages ADD COLUMN error_message TEXT');
    }
    if (!names.contains('generation_duration_ms')) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN generation_duration_ms INTEGER',
      );
    }
  }

  Future<Directory> _imagesRootDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(path.join(dir.path, 'images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  Future<Directory> _sessionDir(int sessionId) async {
    final root = await _imagesRootDir();
    final sessionDir = Directory(path.join(root.path, sessionId.toString()));
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir;
  }

  // ========== 会话操作 ==========

  Future<ChatSession> createSession({String? title}) async {
    final db = await database;
    final now = DateTime.now();
    final session = ChatSession(
      title: title ??
          '新对话 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      updatedAt: now,
    );

    final id = await db.insert('sessions', session.toMap());
    return session.copyWith(id: id);
  }

  Future<List<ChatSession>> getAllSessions() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'updated_at DESC');
    return maps.map((m) => ChatSession.fromMap(m)).toList();
  }

  Future<void> updateSession(ChatSession session) async {
    final db = await database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> touchSession(int sessionId) async {
    final db = await database;
    await db.update(
      'sessions',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await database;
    final sessionFolder = await _sessionDir(sessionId);
    if (await sessionFolder.exists()) {
      await sessionFolder.delete(recursive: true);
    }

    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    await db
        .delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  // ========== 消息操作 ==========

  Future<ChatMessage> addMessage({
    required int sessionId,
    required String prompt,
    String? imageUrl,
    Uint8List? imageBytes,
    List<String> referenceImagePaths = const [],
    List<Uint8List> referenceImagesBytes = const [],
    bool isSuccess = true,
    String? errorMessage,
    int? generationDurationMs,
  }) async {
    final db = await database;

    String? savedImagePath;
    if (imageBytes != null) {
      savedImagePath = await _saveImage(imageBytes, sessionId);
    }
    final effectiveImageUrl = savedImagePath ?? imageUrl;

    List<String> refPaths = referenceImagePaths;
    if (refPaths.isEmpty && referenceImagesBytes.isNotEmpty) {
      refPaths = [];
      for (final bytes in referenceImagesBytes) {
        refPaths.add(await _saveReferenceImage(bytes, sessionId));
      }
    }

    final message = ChatMessage(
      sessionId: sessionId,
      prompt: prompt,
      imageUrl: effectiveImageUrl,
      referenceImagePaths: refPaths,
      isSuccess: isSuccess,
      errorMessage: errorMessage,
      generationDurationMs: generationDurationMs,
    );

    final map = message.toMap();
    map['image_path'] = savedImagePath;

    final id = await db.insert('messages', map);
    await touchSession(sessionId);

    return ChatMessage(
      id: id,
      sessionId: sessionId,
      prompt: prompt,
      imageUrl: effectiveImageUrl,
      imageBytes: imageBytes,
      referenceImagePaths: refPaths,
      isSuccess: isSuccess,
      errorMessage: errorMessage,
      generationDurationMs: generationDurationMs,
      createdAt: message.createdAt,
    );
  }

  Future<List<ChatMessage>> getMessages(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }


  Future<List<MessageSearchHit>> searchMessages(String keyword, {int limit = 200}) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const [];

    final db = await database;
    final pattern = '%$trimmed%';
    final rows = await db.rawQuery(
      '''
      SELECT
        m.id AS message_id,
        m.session_id AS session_id,
        COALESCE(s.title, '') AS session_title,
        m.prompt AS prompt,
        m.created_at AS created_at
      FROM messages m
      LEFT JOIN sessions s ON s.id = m.session_id
      WHERE TRIM(m.prompt) != ''
        AND (m.prompt LIKE ? OR COALESCE(s.title, '') LIKE ?)
      ORDER BY datetime(m.created_at) DESC, m.id DESC
      LIMIT ?
      ''',
      [pattern, pattern, limit],
    );
    return rows
        .map((row) => MessageSearchHit.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<String>> getRecentPromptHistory({int limit = 50}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT prompt, MAX(created_at) AS last_used_at
      FROM messages
      WHERE TRIM(prompt) != ''
      GROUP BY prompt
      ORDER BY datetime(last_used_at) DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows
        .map((row) => row['prompt']?.toString().trim() ?? '')
        .where((prompt) => prompt.isNotEmpty)
        .toList();
  }


  Future<List<HistoryGenerationItem>> getRecentGeneratedHistory({int limit = 100}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        m.id AS message_id,
        m.session_id AS session_id,
        COALESCE(s.title, '') AS session_title,
        m.prompt AS prompt,
        m.image_url AS image_url,
        m.created_at AS created_at
      FROM messages m
      LEFT JOIN sessions s ON s.id = m.session_id
      WHERE m.is_success = 1
        AND COALESCE(TRIM(m.image_url), '') != ''
        AND TRIM(m.prompt) != ''
      ORDER BY datetime(m.created_at) DESC, m.id DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows
        .map((row) => HistoryGenerationItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }


  Future<String> _saveImage(Uint8List bytes, int sessionId) async {
    final sessionDir = await _sessionDir(sessionId);
    final outputsDir = Directory(path.join(sessionDir.path, 'outputs'));
    if (!await outputsDir.exists()) {
      await outputsDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path.join(outputsDir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> _saveReferenceImage(Uint8List bytes, int sessionId) async {
    final sessionDir = await _sessionDir(sessionId);
    final refsDir = Directory(path.join(sessionDir.path, 'refs'));
    if (!await refsDir.exists()) {
      await refsDir.create(recursive: true);
    }
    final fileName =
        'ref_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.png';
    final file = File(path.join(refsDir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Uint8List?> loadImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  Future<List<Uint8List>> loadImages(List<String> imagePaths) async {
    final result = <Uint8List>[];
    for (final imagePath in imagePaths) {
      final bytes = await loadImage(imagePath);
      if (bytes != null) {
        result.add(bytes);
      }
    }
    return result;
  }

  // ========== 统计 ==========

  Future<UsageStats> getUsageStats({int? sessionId}) async {
    final db = await database;
    final where = sessionId == null ? '' : 'WHERE session_id = ?';
    final whereArgs = sessionId == null ? <Object>[] : <Object>[sessionId];
    final maps = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) AS total_count,
        SUM(CASE WHEN is_success = 1 THEN 1 ELSE 0 END) AS success_count,
        SUM(CASE WHEN is_success = 0 THEN 1 ELSE 0 END) AS failure_count,
        COALESCE(AVG(CASE WHEN generation_duration_ms IS NOT NULL THEN generation_duration_ms ELSE NULL END), 0) AS avg_duration_ms
      FROM messages
      $where
      ''',
      whereArgs,
    );

    final row = maps.first;
    return UsageStats(
      totalCount: (row['total_count'] as int?) ?? 0,
      successCount: (row['success_count'] as int?) ?? 0,
      failureCount: (row['failure_count'] as int?) ?? 0,
      avgDurationMs: ((row['avg_duration_ms'] as num?) ?? 0).round(),
    );
  }

  // ========== 缓存/清理 ==========

  Future<int> getImageCacheSizeBytes() async {
    final dir = await _imagesRootDir();
    if (!await dir.exists()) return 0;
    return _calcDirectorySize(dir);
  }

  Future<void> clearImageCache() async {
    final db = await database;
    final imagesDir = await _imagesRootDir();
    if (await imagesDir.exists()) {
      await imagesDir.delete(recursive: true);
    }
    await imagesDir.create(recursive: true);

    await db.rawUpdate(
      "UPDATE messages SET image_url = NULL WHERE image_url LIKE ? OR image_url LIKE ?",
      ['/%', '%:\\%'],
    );
  }

  Future<int> _calcDirectorySize(Directory dir) async {
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

  // ========== 备份与恢复 ==========

  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    final sessions = await db.query('sessions', orderBy: 'id ASC');
    final messages = await db.query('messages', orderBy: 'id ASC');

    final output = <Map<String, dynamic>>[];
    for (final m in messages) {
      final row = Map<String, dynamic>.from(m);
      final imageUrl = row['image_url']?.toString();

      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          _isLikelyLocalPath(imageUrl)) {
        final bytes = await loadImage(imageUrl);
        if (bytes != null) {
          row['image_base64'] = base64Encode(bytes);
        }
      }

      final refPaths = (row['reference_image_paths'] as String?)
              ?.split('|')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];
      if (refPaths.isNotEmpty) {
        final refs = <String>[];
        for (final p in refPaths) {
          final bytes = await loadImage(p);
          if (bytes != null) {
            refs.add(base64Encode(bytes));
          }
        }
        if (refs.isNotEmpty) {
          row['reference_images_base64'] = refs;
        }
      }

      output.add(row);
    }

    return {
      'schema': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'sessions': sessions,
      'messages': output,
    };
  }

  Future<void> importData(
    Map<String, dynamic> data, {
    bool overwrite = true,
  }) async {
    final db = await database;
    final sessions = (data['sessions'] as List?)?.cast<Map>() ?? const [];
    final messages = (data['messages'] as List?)?.cast<Map>() ?? const [];

    await db.transaction((txn) async {
      if (overwrite) {
        await txn.delete('messages');
        await txn.delete('sessions');
      }

      final sessionIdMap = <int, int>{};
      for (final rawSession in sessions) {
        final sessionMap = Map<String, dynamic>.from(rawSession);
        final oldId = (sessionMap['id'] as num?)?.toInt() ?? 0;
        sessionMap.remove('id');
        final newId = await txn.insert('sessions', sessionMap);
        if (oldId > 0) {
          sessionIdMap[oldId] = newId;
        }
      }

      for (final rawMessage in messages) {
        final messageMap = Map<String, dynamic>.from(rawMessage);
        messageMap.remove('id');

        final oldSessionId = (messageMap['session_id'] as num?)?.toInt() ?? 0;
        final mappedSessionId = sessionIdMap[oldSessionId];
        if (mappedSessionId == null) continue;
        messageMap['session_id'] = mappedSessionId;

        final imageBase64 = messageMap.remove('image_base64')?.toString();
        if (imageBase64 != null && imageBase64.isNotEmpty) {
          try {
            final bytes = base64Decode(imageBase64);
            messageMap['image_url'] = await _saveImage(bytes, mappedSessionId);
          } catch (_) {}
        }

        final refBase64List =
            (messageMap.remove('reference_images_base64') as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
        if (refBase64List.isNotEmpty) {
          final paths = <String>[];
          for (final b64 in refBase64List) {
            try {
              final bytes = base64Decode(b64);
              paths.add(await _saveReferenceImage(bytes, mappedSessionId));
            } catch (_) {}
          }
          messageMap['reference_image_paths'] = paths.join('|');
        }

        await txn.insert('messages', messageMap);
      }
    });
  }

  bool _isLikelyLocalPath(String value) {
    return value.startsWith('/') || value.contains(':\\');
  }
}
