import 'dart:typed_data';

class GenerationResult {
  final bool success;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? errorMessage;
  final String? errorCode;
  final bool retryable;
  final int retryCount;
  final DateTime timestamp;

  GenerationResult({
    required this.success,
    this.imageUrl,
    this.imageBytes,
    this.errorMessage,
    this.errorCode,
    this.retryable = false,
    this.retryCount = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasUrl => imageUrl != null;
  bool get hasBytes => imageBytes != null;
  bool get hasImage => hasUrl || hasBytes;

  factory GenerationResult.successUrl(String url) => GenerationResult(
        success: true,
        imageUrl: url,
      );

  factory GenerationResult.successBytes(Uint8List bytes) => GenerationResult(
        success: true,
        imageBytes: bytes,
      );

  factory GenerationResult.error(
    String message, {
    String? errorCode,
    bool retryable = false,
    int retryCount = 0,
  }) =>
      GenerationResult(
        success: false,
        errorMessage: message,
        errorCode: errorCode,
        retryable: retryable,
        retryCount: retryCount,
      );
}
