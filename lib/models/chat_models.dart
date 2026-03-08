import 'dart:typed_data';

/// 单条消息（一次生成记录）
class ChatMessage {
  final int? id;
  final int sessionId;
  final String prompt;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final List<String> referenceImagePaths;
  final bool isSuccess;
  final String? errorMessage;
  final int? generationDurationMs;
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.sessionId,
    required this.prompt,
    this.imageUrl,
    this.imageBytes,
    this.referenceImagePaths = const [],
    this.isSuccess = true,
    this.errorMessage,
    this.generationDurationMs,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'prompt': prompt,
        'image_url': imageUrl,
        'reference_image_paths': referenceImagePaths.join('|'),
        'is_success': isSuccess ? 1 : 0,
        'error_message': errorMessage,
        'generation_duration_ms': generationDurationMs,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        prompt: map['prompt'] as String,
        imageUrl: map['image_url'] as String?,
        referenceImagePaths: (map['reference_image_paths'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        isSuccess: map['is_success'] == 1,
        errorMessage: map['error_message'] as String?,
        generationDurationMs: _parseDurationMs(map['generation_duration_ms']),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  static int? _parseDurationMs(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// 对话会话
class ChatSession {
  final int? id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    this.id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
        id: map['id'] as int?,
        title: map['title'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  ChatSession copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ChatSession(
        id: id ?? this.id,
        title: title ?? this.title,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
