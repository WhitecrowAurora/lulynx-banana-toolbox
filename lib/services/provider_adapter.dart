import 'dart:convert';
import 'dart:typed_data';

import '../models/api_config.dart';
import '../models/generation_result.dart';

abstract class ProviderAdapter {
  String get id;
  String imageGenerationPath(ApiConfig config);
  Map<String, dynamic> buildImageRequest({
    required ApiConfig config,
    required String prompt,
    Object? imagePayload,
  });
  GenerationResult parseImageResponse(dynamic data);
}

class NanoBananaCompatibleAdapter implements ProviderAdapter {
  @override
  String get id => ApiConfig.providerNanoBananaCompatible;

  @override
  String imageGenerationPath(ApiConfig config) {
    final base = _normalizeBaseUrl(config.baseUrl);
    if (base.endsWith('/v1')) {
      return '$base/images/generations';
    }
    return '$base/v1/images/generations';
  }

  @override
  Map<String, dynamic> buildImageRequest({
    required ApiConfig config,
    required String prompt,
    Object? imagePayload,
  }) {
    final body = <String, dynamic>{
      'model': config.model,
      'prompt': prompt,
      'response_format': config.responseFormat,
    };

    if (config.aspectRatio != ApiConfig.autoAspectRatio) {
      body['aspect_ratio'] = config.aspectRatio;
    }

    if (config.supportsImageSize) {
      body['image_size'] = config.imageSize;
    }

    if (imagePayload != null) {
      body['image'] = imagePayload;
    }

    return body;
  }

  String _normalizeBaseUrl(String value) {
    var base = value.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  @override
  GenerationResult parseImageResponse(dynamic data) {
    try {
      final payload = _normalizeResponse(data);
      final parsed = _extractImage(payload);
      if (parsed?.bytes != null && parsed!.bytes!.isNotEmpty) {
        return GenerationResult.successBytes(parsed.bytes!);
      }
      if (parsed?.url != null && parsed!.url!.isNotEmpty) {
        return GenerationResult.successUrl(parsed.url!);
      }

      final serverMessage = _extractServerMessage(payload);
      final message = (serverMessage == null || serverMessage.isEmpty)
          ? 'API returned no image data. Raw response: ${_preview(payload)}'
          : 'API returned no image data: $serverMessage. Raw response: ${_preview(payload)}';
      return GenerationResult.error(message, errorCode: 'missing_image');
    } catch (e) {
      return GenerationResult.error(
        'Failed to parse response: $e. Raw data: ${_preview(data)}',
        errorCode: 'parse_error',
      );
    }
  }

  dynamic _normalizeResponse(dynamic data) {
    if (data is List<int>) {
      try {
        return _normalizeResponse(utf8.decode(data));
      } catch (_) {
        return data;
      }
    }
    if (data is String) {
      final text = data.trim();
      if (text.isEmpty) return data;
      try {
        return jsonDecode(text);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  _ParsedImage? _extractImage(dynamic payload) {
    final candidates = <dynamic>[];
    _collectCandidates(payload, candidates, depth: 0);

    for (final candidate in candidates) {
      final parsed = _parseCandidate(candidate);
      if (parsed != null && parsed.hasImage) return parsed;
    }
    return null;
  }

  void _collectCandidates(dynamic node, List<dynamic> out, {required int depth}) {
    if (node == null || depth > 5) return;
    out.add(node);
    if (node is List) {
      for (final item in node) {
        _collectCandidates(item, out, depth: depth + 1);
      }
      return;
    }
    if (node is! Map) return;

    const containers = <String>['data', 'images', 'output', 'result', 'response', 'choices'];
    for (final key in containers) {
      final value = node[key];
      if (value != null) {
        _collectCandidates(value, out, depth: depth + 1);
      }
    }
  }

  _ParsedImage? _parseCandidate(dynamic node) {
    if (node is Map) {
      const urlKeys = <String>[
        'url',
        'image_url',
        'output_url',
        'result_url',
        'imageUrl',
        'outputUrl',
        'resultUrl',
      ];
      for (final key in urlKeys) {
        final value = node[key];
        if (value is String) {
          final normalized = value.trim();
          if (normalized.startsWith('data:image/')) {
            final bytes = _decodeBase64(normalized);
            if (bytes != null && bytes.isNotEmpty) {
              return _ParsedImage(bytes: bytes);
            }
          } else if (_isLikelyHttpImageUrl(normalized)) {
            return _ParsedImage(url: normalized);
          }
        }
      }

      const bytesKeys = <String>[
        'b64_json',
        'base64',
        'b64',
        'image_base64',
        'output_base64',
      ];
      for (final key in bytesKeys) {
        final value = node[key];
        if (value is String) {
          final bytes = _decodeBase64(value);
          if (bytes != null && bytes.isNotEmpty) {
            return _ParsedImage(bytes: bytes);
          }
        }
      }
    }

    if (node is String) {
      final normalized = node.trim();
      if (normalized.startsWith('data:image/')) {
        final bytes = _decodeBase64(normalized);
        if (bytes != null && bytes.isNotEmpty) {
          return _ParsedImage(bytes: bytes);
        }
      } else if (_looksLikeDirectImageUrl(normalized)) {
        return _ParsedImage(url: normalized);
      }
    }

    return null;
  }

  bool _isLikelyHttpImageUrl(String value) {
    if (value.isEmpty) return false;
    return value.startsWith('https://') || value.startsWith('http://');
  }

  bool _looksLikeDirectImageUrl(String value) {
    if (!_isLikelyHttpImageUrl(value)) return false;
    final lower = value.toLowerCase();
    final hasImageExt = RegExp(r'\.(png|jpe?g|webp|gif|bmp|avif)(\?|$)').hasMatch(lower);
    if (hasImageExt) return true;
    return lower.contains('/image/') || lower.contains('/images/') || lower.contains('/output/');
  }

  Uint8List? _decodeBase64(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;

    final comma = text.indexOf(',');
    if (text.startsWith('data:image/') && comma > 0) {
      text = text.substring(comma + 1);
    }

    text = text.replaceAll(RegExp(r'\s+'), '');
    if (text.length < 64) return null;
    if (!RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(text)) return null;

    try {
      return base64Decode(text);
    } catch (_) {
      try {
        return base64Decode(base64.normalize(text));
      } catch (_) {
        return null;
      }
    }
  }

  String? _extractServerMessage(dynamic node) {
    if (node is! Map) return null;

    final error = node['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString().trim();
    }
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    final message = node['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return null;
  }

  String _preview(dynamic data) {
    String text;
    if (data == null) {
      text = 'null';
    } else if (data is String) {
      text = data;
    } else {
      try {
        text = jsonEncode(data);
      } catch (_) {
        text = data.toString();
      }
    }

    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 800) return singleLine;
    return '${singleLine.substring(0, 800)}...(truncated)';
  }
}

class _ParsedImage {
  final String? url;
  final Uint8List? bytes;

  const _ParsedImage({this.url, this.bytes});

  bool get hasImage =>
      (url != null && url!.isNotEmpty) || (bytes != null && bytes!.isNotEmpty);
}

ProviderAdapter resolveProviderAdapter(String providerId) {
  switch (providerId) {
    case ApiConfig.providerNanoBananaCompatible:
    default:
      return NanoBananaCompatibleAdapter();
  }
}
