import 'dart:convert';
import 'dart:typed_data';

enum QueueTaskStatus {
  pending,
  running,
}

class GenerationQueueTask {
  final String id;
  final String prompt;
  final List<Uint8List> referenceImages;
  final DateTime createdAt;
  final QueueTaskStatus status;
  final bool fromRetry;

  GenerationQueueTask({
    required this.id,
    required this.prompt,
    required this.referenceImages,
    required this.createdAt,
    this.status = QueueTaskStatus.pending,
    this.fromRetry = false,
  });

  GenerationQueueTask copyWith({
    String? id,
    String? prompt,
    List<Uint8List>? referenceImages,
    DateTime? createdAt,
    QueueTaskStatus? status,
    bool? fromRetry,
  }) {
    return GenerationQueueTask(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      referenceImages: referenceImages ?? this.referenceImages,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      fromRetry: fromRetry ?? this.fromRetry,
    );
  }

  String signature() {
    final buffer = StringBuffer(prompt.trim());
    for (final image in referenceImages) {
      buffer.write('|len:${image.length}');
      if (image.isNotEmpty) {
        buffer
          ..write(':f${image.first}')
          ..write(':m${image[image.length ~/ 2]}')
          ..write(':l${image.last}');
      }
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'referenceImages':
          referenceImages.map((image) => base64Encode(image)).toList(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'fromRetry': fromRetry,
    };
  }

  factory GenerationQueueTask.fromJson(Map<String, dynamic> json) {
    final rawImages = json['referenceImages'];
    final referenceImages = <Uint8List>[];
    if (rawImages is List) {
      for (final entry in rawImages) {
        if (entry == null) {
          continue;
        }
        final encoded = entry.toString();
        try {
          referenceImages.add(Uint8List.fromList(base64Decode(encoded)));
        } catch (_) {
          continue;
        }
      }
    }

    final createdAtRaw = json['createdAt']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();

    final statusRaw = json['status']?.toString() ?? '';
    final status = QueueTaskStatus.values.firstWhere(
      (value) => value.name == statusRaw,
      orElse: () => QueueTaskStatus.pending,
    );

    return GenerationQueueTask(
      id: json['id']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      referenceImages: referenceImages,
      createdAt: createdAt,
      status: status,
      fromRetry: json['fromRetry'] == true,
    );
  }
}
