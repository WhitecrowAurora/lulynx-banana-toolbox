import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/api_config.dart';
import '../models/generation_result.dart';
import 'provider_adapter.dart';

class NanoBananaService {
  final Dio _dio;
  ApiConfig _config;

  NanoBananaService({ApiConfig? config})
      : _config = config ?? ApiConfig.empty(),
        _dio = Dio() {
    _applyTimeoutOptions();
    _dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    );
  }

  void updateConfig(ApiConfig config) {
    _config = config;
    _applyTimeoutOptions();
  }

  ApiConfig get config => _config;

  Duration _requestTimeoutDuration() {
    final seconds = _config.requestTimeoutSeconds.clamp(30, 900).toInt();
    return Duration(seconds: seconds);
  }

  void _applyTimeoutOptions() {
    final timeout = _requestTimeoutDuration();
    _dio.options.connectTimeout = const Duration(seconds: 120);
    _dio.options.sendTimeout = timeout;
    _dio.options.receiveTimeout = timeout;
  }

  bool get _isHttpsRequiredButInvalid =>
      _config.enforceHttps &&
      !_config.baseUrl.trim().toLowerCase().startsWith('https://');

  Future<Map<String, dynamic>> fetchModelList({
    bool bananaOnly = true,
  }) async {
    if (!_config.isValid) {
      return {'success': false, 'error': '请先配置 API'};
    }
    if (_isHttpsRequiredButInvalid) {
      return {
        'success': false,
        'error': '已启用 HTTPS 强制，请使用 https:// 开头的 API 端点',
      };
    }

    final url = _buildModelsUrl();
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer ${_config.apiKey}'},
          receiveTimeout: const Duration(seconds: 45),
          validateStatus: (status) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return {
          'success': false,
          'error':
              'API 错误 ($status): ${_extractBadResponseMessage(response.data)}',
          'errorCode': 'http_$status',
        };
      }

      final models = _parseModelListPayload(
        response.data,
        bananaOnly: bananaOnly,
      );
      if (models.isEmpty) {
        return {
          'success': false,
          'error': bananaOnly ? '未找到 banana 系列模型' : '未找到可用模型',
          'errorCode': 'empty_model_list',
        };
      }
      return {
        'success': true,
        'models': models,
        'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      };
    } on DioException catch (e) {
      final mapped = _mapDioException(e, _buildErrorInfo(e));
      return {
        'success': false,
        'error': mapped.message,
        'errorCode': mapped.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '获取模型列表失败: $e',
        'errorCode': 'model_list_failed',
      };
    }
  }

  Future<Map<String, dynamic>> getTokenQuota() async {
    if (!_config.isValid) {
      return {'success': false, 'error': '请先配置 API'};
    }
    if (_isHttpsRequiredButInvalid) {
      return {
        'success': false,
        'error': '已启用 HTTPS 强制，请使用 https:// 开头的 API 端点',
      };
    }

    try {
      final userId = _config.apiUserId.trim();
      if (userId.isNotEmpty) {
        final userSelf = await _queryUserSelfQuota(userId);
        if (userSelf['success'] == true) {
          return userSelf;
        }
      }

      final legacy = await _queryLegacyQuota();
      if (legacy['success'] == true) {
        return legacy;
      }
      if (userId.isEmpty) {
        return {
          'success': false,
          'error':
              "${legacy['error'] ?? '查询失败'}\n提示：如果你的平台需要 New-API-User，请在设置填写。",
          'errorCode': legacy['errorCode'],
        };
      }
      return legacy;
    } on DioException catch (e) {
      final error = _mapDioException(e, _buildErrorInfo(e));
      return {
        'success': false,
        'error': error.message,
        'errorCode': error.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '查询失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _queryUserSelfQuota(String userId) async {
    for (final url in _buildUserSelfUrls()) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${_config.apiKey}',
              'New-API-User': userId,
            },
            receiveTimeout: _requestTimeoutDuration(),
            validateStatus: (status) => true,
          ),
        );

        final status = response.statusCode ?? 0;
        if (status == 404) {
          continue;
        }
        if (status < 200 || status >= 300) {
          return {
            'success': false,
            'error':
                'API 错误 ($status): ${_extractBadResponseMessage(response.data)}',
            'errorCode': 'http_$status',
          };
        }

        final parsed = _parseUserSelfQuotaPayload(response.data);
        if (parsed != null) return parsed;
        return {
          'success': false,
          'error': 'user/self 返回格式不支持',
          'errorCode': 'invalid_user_self_response',
        };
      } on DioException catch (e) {
        final mapped = _mapDioException(e, _buildErrorInfo(e));
        return {
          'success': false,
          'error': mapped.message,
          'errorCode': mapped.code,
        };
      }
    }
    return {
      'success': false,
      'error': '未找到 /api/user/self 可用端点',
      'errorCode': 'user_self_not_found',
    };
  }

  Future<Map<String, dynamic>> _queryLegacyQuota() async {
    final url = _buildQuotaUrl();
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer ${_config.apiKey}'},
          receiveTimeout: _requestTimeoutDuration(),
        ),
      );
      final data = response.data;
      return {
        'success': true,
        'id': data['id'],
        'name': data['name'],
        'quota': _toDouble(data['quota']),
        'usedQuota': _toDouble(data['used_quota']),
      };
    } on DioException catch (e) {
      final error = _mapDioException(e, _buildErrorInfo(e));
      return {
        'success': false,
        'error': error.message,
        'errorCode': error.code,
      };
    }
  }

  Map<String, dynamic>? _parseUserSelfQuotaPayload(dynamic data) {
    if (data is! Map) return null;
    final inner = data['data'];
    if (inner is! Map) return null;

    final rawQuota = _toDouble(inner['quota']);
    final rawUsed = _toDouble(inner['used_quota']);
    return {
      'success': true,
      'id': inner['id'],
      'name': inner['display_name'] ?? inner['username'],
      'quota': _convertUserSelfQuota(rawQuota),
      'usedQuota': _convertUserSelfQuota(rawUsed),
    };
  }

  List<String> _buildUserSelfUrls() {
    final base = _normalizedBaseUrl();
    final root =
        base.endsWith('/v1') ? base.substring(0, base.length - 3) : base;
    final urls = <String>{
      '$root/api/user/self',
      '$base/api/user/self',
    };
    if (base.endsWith('/v1')) {
      urls.add('$base/user/self');
    }
    return urls.toList(growable: false);
  }

  double _convertUserSelfQuota(double? raw) {
    if (raw == null) return 0;
    return raw / 500000.0;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<String> testConnection() async {
    final log = StringBuffer();
    log.writeln('========== 测试连接 ==========');
    log.writeln('时间: ${DateTime.now()}');
    log.writeln('API 端点: ${_config.baseUrl}');
    log.writeln(
      'API Key: ${_config.apiKey.isNotEmpty ? '已配置 (${_config.apiKey.length}字符)' : '未配置'}',
    );
    log.writeln('Provider: ${_config.providerId}');
    log.writeln('HTTPS 强制: ${_config.enforceHttps ? '开启' : '关闭'}');
    log.writeln();

    if (!_config.isValid) {
      log.writeln('错误: API 配置无效');
      return log.toString();
    }
    if (_isHttpsRequiredButInvalid) {
      log.writeln('错误: 已启用 HTTPS 强制，请使用 https:// 开头的 API 端点');
      return log.toString();
    }

    log.writeln('--- 步骤1: 检查基础连接 ---');
    try {
      final response = await _dio.get(
        _config.baseUrl,
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      log.writeln('状态码: ${response.statusCode}');
      log.writeln('基础连接正常');
    } catch (e) {
      log.writeln('基础连接失败: $e');
    }
    log.writeln();

    log.writeln('--- 步骤2: 测试生图端点 ---');
    try {
      final adapter = resolveProviderAdapter(_config.providerId);
      final apiUrl = adapter.imageGenerationPath(_config);
      final timeout = _requestTimeoutDuration();

      log.writeln('步骤 URL: $apiUrl');
      log.writeln('请求超时: ${timeout.inSeconds} 秒');

      final response = await _dio.post(
        apiUrl,
        data: adapter.buildImageRequest(config: _config, prompt: 'test'),
        options: Options(
          validateStatus: (status) => true,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_config.apiKey}',
          },
        ),
      );

      log.writeln('状态码: ${response.statusCode}');
      log.writeln('响应头: ${response.headers}');
      log.writeln('响应体: ${response.data}');
      final parsed = adapter.parseImageResponse(response.data);
      log.writeln('解析结果: ${parsed.success ? '鎴愬姛' : '澶辫触'}');
      if (parsed.success) {
        if (parsed.imageUrl != null) {
          log.writeln('解析图片URL: ${parsed.imageUrl}');
        } else if (parsed.imageBytes != null) {
          log.writeln('解析图片Bytes: ${parsed.imageBytes!.length}');
        }
      } else {
        log.writeln('解析错误码: ${parsed.errorCode}');
      }
    } catch (e) {
      log.writeln('请求失败: $e');
      if (e is DioException) {
        log.writeln('错误类型: ${e.type}');
        log.writeln('错误消息: ${e.message}');
        if (e.error != null) {
          log.writeln('底层错误: ${e.error}');
        }
      }
    }

    log.writeln();
    log.writeln('================================');
    return log.toString();
  }

  Future<GenerationResult> generateFromText(
    String prompt, {
    Duration? timeout,
    CancelToken? cancelToken,
    String? idempotencyKey,
  }) async {
    return _generate(
      prompt: prompt,
      timeout: timeout,
      cancelToken: cancelToken,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Uint8List?> downloadImageBytes(
    String imageUrl, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final url = imageUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: const <String, dynamic>{},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  Future<GenerationResult> generateFromImages({
    required String prompt,
    required List<Uint8List> referenceImages,
    Duration? timeout,
    CancelToken? cancelToken,
    String? idempotencyKey,
    int degradeLevel = 0,
  }) async {
    final adapter = resolveProviderAdapter(_config.providerId);

    // 如果 Provider 支持 multipart image edits，使用专门的 edits 端点
    if (adapter.supportsMultipartImageEdits) {
      return _generateMultipartImageEdits(
        prompt: prompt,
        referenceImages: referenceImages,
        timeout: timeout,
        cancelToken: cancelToken,
        idempotencyKey: idempotencyKey,
        degradeLevel: degradeLevel,
      );
    }

    // 原有的 NanoBanana 兼容方式（JSON + base64）
    final preparedImages = _prepareReferenceImages(
      referenceImages,
      degradeLevel: degradeLevel,
    );
    final base64List = preparedImages.map(base64Encode).toList(growable: false);
    final mode = _config.referenceUploadMode;
    final startSingle = mode == ApiConfig.referenceUploadModeSingle &&
        preparedImages.length == 1;
    final preferSingle = mode == ApiConfig.referenceUploadModeSingle &&
        preparedImages.length == 1;
    final firstPayload = preferSingle ? base64List.first : base64List;

    final firstAttempt = await _generate(
      prompt: prompt,
      imagePayload: firstPayload,
      timeout: timeout,
      cancelToken: cancelToken,
      idempotencyKey: _stageIdempotencyKey(idempotencyKey, 1),
    );
    if (firstAttempt.success || cancelToken?.isCancelled == true) {
      return firstAttempt;
    }
    if (!_config.referenceCompatEnhanced) {
      return firstAttempt;
    }
    if (!_shouldRetryReferencePayload(firstAttempt)) {
      return firstAttempt;
    }

    final dataUriList = _toDataUriImages(preparedImages, base64List);
    final secondPayload = preferSingle ? dataUriList.first : dataUriList;
    final secondAttempt = await _generate(
      prompt: prompt,
      imagePayload: secondPayload,
      timeout: timeout,
      cancelToken: cancelToken,
      idempotencyKey: _stageIdempotencyKey(idempotencyKey, 2),
    );
    if (secondAttempt.success ||
        cancelToken?.isCancelled == true ||
        !_shouldRetryReferencePayload(secondAttempt)) {
      return secondAttempt;
    }
    if (preparedImages.length != 1 ||
        mode != ApiConfig.referenceUploadModeAuto) {
      return secondAttempt;
    }

    final thirdPayload = startSingle ? dataUriList : dataUriList.first;

    return _generate(
      prompt: prompt,
      imagePayload: thirdPayload,
      timeout: timeout,
      cancelToken: cancelToken,
      idempotencyKey: _stageIdempotencyKey(idempotencyKey, 3),
    );
  }

  String? _stageIdempotencyKey(String? base, int stage) {
    final key = (base ?? '').trim();
    if (key.isEmpty) return null;
    return '$key-s$stage';
  }

  Future<GenerationResult> _generateMultipartImageEdits({
    required String prompt,
    required List<Uint8List> referenceImages,
    Duration? timeout,
    CancelToken? cancelToken,
    String? idempotencyKey,
    int degradeLevel = 0,
  }) async {
    if (!_config.isValid) {
      return GenerationResult.error(
        '请先配置 API 端点和 Key',
        errorCode: 'invalid_config',
      );
    }
    if (_isHttpsRequiredButInvalid) {
      return GenerationResult.error(
        '已启用 HTTPS 强制，请使用 https:// 开头的 API 端点',
        errorCode: 'https_required',
      );
    }

    final adapter = resolveProviderAdapter(_config.providerId);
    if (!adapter.supportsMultipartImageEdits) {
      return GenerationResult.error(
        '当前 Provider 不支持 multipart image edits',
        errorCode: 'not_supported',
      );
    }

    final editsUrl = adapter.imageEditsPath(_config);
    if (editsUrl == null || editsUrl.isEmpty) {
      return GenerationResult.error(
        '当前 Provider 未配置 edits 端点',
        errorCode: 'no_edits_endpoint',
      );
    }

    // 预处理参考图片
    final preparedImages = _prepareReferenceImages(
      referenceImages,
      degradeLevel: degradeLevel,
    );

    // 生成文件名
    int fileIndex = 0;
    String generateFileName(Uint8List bytes) {
      final ext = _sniffMimeType(bytes).split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'image_${timestamp}_${fileIndex++}.$ext';
    }

    final formData = adapter.buildImageEditsRequest(
      config: _config,
      prompt: prompt,
      referenceImages: preparedImages,
      generateFileName: generateFileName,
    );

    if (formData == null) {
      return GenerationResult.error(
        '构建 multipart 请求失败',
        errorCode: 'build_formdata_failed',
      );
    }

    final debugInfo = StringBuffer();
    debugInfo.writeln('========== Multipart Image Edits 请求调试 ==========');
    debugInfo.writeln('URL: $editsUrl');
    debugInfo.writeln('Provider: ${_config.providerId}');
    debugInfo.writeln('Model: ${_config.model}');
    debugInfo.writeln('Prompt: $prompt');
    debugInfo.writeln('图片数量: ${preparedImages.length}');
    debugInfo.writeln('====================================================');
    debugPrint(debugInfo.toString());

    try {
      final options = Options(
        headers: {
          'Authorization': 'Bearer ${_config.apiKey}',
          if ((idempotencyKey ?? '').trim().isNotEmpty)
            'Idempotency-Key': idempotencyKey!.trim(),
        },
        sendTimeout: timeout,
        receiveTimeout: timeout,
      );

      final response = await _dio.post(
        editsUrl,
        data: formData,
        options: options,
        cancelToken: cancelToken,
      );

      debugPrint('========== Multipart Image Edits 响应调试 ==========');
      debugPrint('状态码: ${response.statusCode}');
      debugPrint('响应数据: ${response.data}');
      debugPrint('====================================================');

      return adapter.parseImageResponse(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse && e.response != null) {
        final recovered = adapter.parseImageResponse(e.response?.data);
        if (recovered.success) {
          debugPrint(
            '[compat] Non-2xx response carried image payload; treated as success. status=${e.response?.statusCode}',
          );
          return recovered;
        }
      }
      final errorInfo = _buildErrorInfo(e);
      debugPrint(errorInfo);
      final mapped = _mapDioException(e, errorInfo);
      return GenerationResult.error(
        mapped.message,
        errorCode: mapped.code,
        retryable: mapped.retryable,
      );
    } catch (e, stackTrace) {
      final errorMsg = '未知错误: $e\n堆栈: $stackTrace';
      debugPrint(errorMsg);
      return GenerationResult.error(errorMsg, errorCode: 'unknown');
    }
  }

  Future<GenerationResult> _generate({
    required String prompt,
    Object? imagePayload,
    Duration? timeout,
    CancelToken? cancelToken,
    String? idempotencyKey,
  }) async {
    if (!_config.isValid) {
      return GenerationResult.error(
        '请先配置 API 端点和 Key',
        errorCode: 'invalid_config',
      );
    }
    if (_isHttpsRequiredButInvalid) {
      return GenerationResult.error(
        '已启用 HTTPS 强制，请使用 https:// 开头的 API 端点',
        errorCode: 'https_required',
      );
    }

    final adapter = resolveProviderAdapter(_config.providerId);
    final url = adapter.imageGenerationPath(_config);
    final body = adapter.buildImageRequest(
      config: _config,
      prompt: prompt,
      imagePayload: imagePayload,
    );

    final debugInfo = StringBuffer();
    debugInfo.writeln('========== 请求调试信息 ==========');
    debugInfo.writeln('URL: $url');
    debugInfo.writeln('请求方法: POST');
    debugInfo.writeln('Provider: ${_config.providerId}');
    debugInfo.writeln('请求头:');
    debugInfo.writeln('  Content-Type: application/json');
    debugInfo.writeln('  Authorization: Bearer ${_maskApiKey(_config.apiKey)}');
    debugInfo.writeln('请求体:');
    debugInfo.writeln('  model: ${body['model']}');
    debugInfo.writeln('  prompt: ${body['prompt']}');
    if (body.containsKey('aspect_ratio')) {
      debugInfo.writeln('  aspect_ratio: ${body['aspect_ratio']}');
    } else {
      debugInfo.writeln('  aspect_ratio: <auto> (not sent)');
    }
    debugInfo.writeln('  response_format: ${body['response_format']}');
    if (body.containsKey('image_size')) {
      debugInfo.writeln('  image_size: ${body['image_size']}');
    }
    if (body.containsKey('image')) {
      final imageField = body['image'];
      if (imageField is List) {
        debugInfo.writeln('  image: [${imageField.length} 张图片]');
      } else {
        debugInfo.writeln('  image: [1 张图片]');
      }
    }
    debugInfo.writeln('===================================');
    debugPrint(debugInfo.toString());

    try {
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
          if ((idempotencyKey ?? '').trim().isNotEmpty)
            'Idempotency-Key': idempotencyKey!.trim(),
        },
        sendTimeout: timeout,
        receiveTimeout: timeout,
      );

      final response = await _dio.post(
        url,
        data: body,
        options: options,
        cancelToken: cancelToken,
      );

      debugPrint('========== 响应调试信息 ==========');
      debugPrint('状态码: ${response.statusCode}');
      debugPrint('响应数据: ${response.data}');
      debugPrint('===================================');

      return adapter.parseImageResponse(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse && e.response != null) {
        final recovered = adapter.parseImageResponse(e.response?.data);
        if (recovered.success) {
          debugPrint(
            '[compat] Non-2xx response carried image payload; treated as success. status=${e.response?.statusCode}',
          );
          return recovered;
        }
      }
      final errorInfo = _buildErrorInfo(e);
      debugPrint(errorInfo);
      final mapped = _mapDioException(e, errorInfo);
      return GenerationResult.error(
        mapped.message,
        errorCode: mapped.code,
        retryable: mapped.retryable,
      );
    } catch (e, stackTrace) {
      final errorMsg = '未知错误: $e\n堆栈: $stackTrace';
      debugPrint(errorMsg);
      return GenerationResult.error(errorMsg, errorCode: 'unknown');
    }
  }

  bool _shouldRetryReferencePayload(GenerationResult result) {
    final code = (result.errorCode ?? '').toLowerCase();
    if (code == 'cancelled') return false;
    if (code == 'http_400' || code == 'http_415' || code == 'http_422') {
      return true;
    }

    final message = (result.errorMessage ?? '').toLowerCase();
    return message.contains('image') ||
        message.contains('base64') ||
        message.contains('mime') ||
        message.contains('format') ||
        message.contains('unsupported') ||
        message.contains('invalid');
  }

  List<Uint8List> _prepareReferenceImages(
    List<Uint8List> images, {
    required int degradeLevel,
  }) {
    final shouldProcess =
        _config.referencePreprocessEnabled || degradeLevel > 0;
    if (!shouldProcess) {
      return List<Uint8List>.from(images, growable: false);
    }
    final out = <Uint8List>[];
    for (final bytes in images) {
      out.add(
          _preprocessSingleReferenceImage(bytes, degradeLevel: degradeLevel));
    }
    return out;
  }

  Uint8List _preprocessSingleReferenceImage(
    Uint8List input, {
    required int degradeLevel,
  }) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;

    var maxDimension = _config.referenceMaxDimension;
    if (degradeLevel > 0) {
      final fallbackByLevel = _autoDegradeDimension(degradeLevel);
      if (maxDimension <= 0 || fallbackByLevel < maxDimension) {
        maxDimension = fallbackByLevel;
      }
    }

    final quality = _effectiveQuality(degradeLevel);
    final format = _effectiveReferenceFormat(degradeLevel);

    var working = decoded;
    final longestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (maxDimension > 0 && longestSide > maxDimension) {
      final scale = maxDimension / longestSide;
      final width = (decoded.width * scale).round().clamp(1, decoded.width);
      final height = (decoded.height * scale).round().clamp(1, decoded.height);
      working = img.copyResize(
        decoded,
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      );
    }

    final keepOriginal = format == ApiConfig.referenceFormatKeep &&
        working == decoded &&
        quality >= 100;
    if (keepOriginal) return input;

    switch (format) {
      case ApiConfig.referenceFormatJpeg:
        return Uint8List.fromList(img.encodeJpg(working, quality: quality));
      case ApiConfig.referenceFormatPng:
        return Uint8List.fromList(img.encodePng(working));
      case ApiConfig.referenceFormatWebp:
        return Uint8List.fromList(img.encodeJpg(working, quality: quality));
      case ApiConfig.referenceFormatKeep:
      default:
        final mime = _sniffMimeType(input);
        if (mime == 'image/png') {
          return Uint8List.fromList(img.encodePng(working));
        }
        if (mime == 'image/webp') {
          return Uint8List.fromList(img.encodeJpg(working, quality: quality));
        }
        return Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }
  }

  int _effectiveQuality(int degradeLevel) {
    var quality = _config.referenceQuality.clamp(40, 100);
    if (degradeLevel > 0) {
      quality = (quality - (degradeLevel * 8)).clamp(45, 95);
    }
    return quality;
  }

  String _effectiveReferenceFormat(int degradeLevel) {
    if (degradeLevel <= 0) return _config.referenceNormalizeFormat;
    if (_config.referenceNormalizeFormat == ApiConfig.referenceFormatKeep) {
      return ApiConfig.referenceFormatJpeg;
    }
    return _config.referenceNormalizeFormat;
  }

  int _autoDegradeDimension(int degradeLevel) {
    if (degradeLevel <= 1) return 2048;
    if (degradeLevel == 2) return 1536;
    return 1024;
  }

  List<String> _toDataUriImages(
    List<Uint8List> referenceImages,
    List<String> base64Images,
  ) {
    final out = <String>[];
    for (var i = 0; i < referenceImages.length; i++) {
      out.add(
          'data:${_sniffMimeType(referenceImages[i])};base64,${base64Images[i]}');
    }
    return out;
  }

  String _sniffMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }

  String _maskApiKey(String key) {
    if (key.isEmpty) return '<empty>';
    if (key.length <= 6) return '***';
    return '${key.substring(0, 3)}***${key.substring(key.length - 3)}';
  }

  String _buildErrorInfo(DioException e) {
    final info = StringBuffer();
    final msg = (e.message ?? '').trim();
    final response = e.response;
    info.writeln('========== 错误调试信息 ==========');
    info.writeln('错误类型: ${e.type}');
    info.writeln(
      '错误消息: ${msg.isEmpty || msg.toLowerCase() == 'null' ? '<empty>' : msg}',
    );
    info.writeln('请求 URL: ${e.requestOptions.uri}');
    info.writeln('请求方法: ${e.requestOptions.method}');
    info.writeln('请求头: ${_redactHeaders(e.requestOptions.headers)}');

    if (response != null) {
      final gatewayRequestId = _extractGatewayRequestId(response);
      info.writeln('响应状态码: ${response.statusCode}');
      if (gatewayRequestId != null && gatewayRequestId.isNotEmpty) {
        info.writeln('网关请求 ID: $gatewayRequestId');
      }
      info.writeln('响应头: ${response.headers}');
      info.writeln('响应数据: ${response.data}');
    }

    if (e.error != null) {
      info.writeln('底层错误: ${e.error}');
      info.writeln('底层错误类型: ${e.error.runtimeType}');
    }

    info.writeln('===================================');
    return info.toString();
  }

  String? _extractGatewayRequestId(Response<dynamic> response) {
    const candidateKeys = [
      'x-oneapi-request-id',
      'x-request-id',
      'x-trace-id',
    ];
    for (final key in candidateKeys) {
      final value = response.headers.value(key)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final result = <String, dynamic>{};
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'authorization' || lower == 'x-api-key') {
        result[key] = '***REDACTED***';
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  String _buildQuotaUrl() {
    final base = _normalizedBaseUrl();
    if (base.endsWith('/v1')) {
      return '$base/token/quota';
    }
    return '$base/v1/token/quota';
  }

  String _buildModelsUrl() {
    final base = _normalizedBaseUrl();
    if (base.endsWith('/v1')) {
      return '$base/models';
    }
    return '$base/v1/models';
  }

  List<Map<String, dynamic>> _parseModelListPayload(
    dynamic data, {
    required bool bananaOnly,
  }) {
    List<dynamic> rawList = const [];
    if (data is Map) {
      final inner = data['data'];
      if (inner is List) {
        rawList = inner;
      }
    } else if (data is List) {
      rawList = data;
    }

    final models = <Map<String, dynamic>>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;

      final lowerId = id.toLowerCase();
      if (bananaOnly && !lowerId.contains('banana')) continue;

      final endpoints = (map['supported_endpoint_types'] as List?)
              ?.map((e) => e.toString().toLowerCase().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      if (endpoints.isNotEmpty && !endpoints.contains('openai')) {
        continue;
      }

      models.add({
        'id': id,
        'name': id,
        'created': _toInt(map['created']) ?? 0,
        'owned_by': map['owned_by']?.toString() ?? '',
      });
    }

    models.sort((a, b) {
      final createdA = (a['created'] as int?) ?? 0;
      final createdB = (b['created'] as int?) ?? 0;
      final byCreated = createdB.compareTo(createdA);
      if (byCreated != 0) return byCreated;
      final idA = a['id']?.toString() ?? '';
      final idB = b['id']?.toString() ?? '';
      return idA.compareTo(idB);
    });

    return models;
  }

  String _normalizedBaseUrl() {
    var base = _config.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  _ServiceError _mapDioException(DioException e, String debugInfo) {
    String baseError;
    String code;
    var retryable = false;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        baseError = '连接超时';
        code = 'connection_timeout';
        retryable = true;
        break;
      case DioExceptionType.sendTimeout:
        baseError = '发送超时';
        code = 'send_timeout';
        retryable = true;
        break;
      case DioExceptionType.receiveTimeout:
        baseError = '接收超时';
        code = 'receive_timeout';
        retryable = true;
        break;
      case DioExceptionType.badCertificate:
        baseError = 'SSL 证书错误';
        code = 'bad_certificate';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final message = _extractBadResponseMessage(e.response?.data);
        baseError = 'API 错误 ($statusCode): $message';
        code = 'http_$statusCode';
        retryable =
            statusCode == 429 || (statusCode >= 500 && statusCode < 600);
        break;
      case DioExceptionType.cancel:
        baseError = '请求已取消';
        code = 'cancelled';
        break;
      case DioExceptionType.connectionError:
        baseError = '网络连接错误';
        code = 'connection_error';
        retryable = true;
        if (e.error != null) {
          baseError += '\n底层错误: ${e.error}';
        }
        break;
      case DioExceptionType.unknown:
      default:
        final err = e.error;
        final detail = '${e.message ?? ''} ${err ?? ''}'.toLowerCase().trim();
        if (err is HandshakeException ||
            detail.contains('certificate') ||
            detail.contains('ssl')) {
          baseError = 'SSL 网络错误';
          code = 'ssl_error';
        } else if (detail.contains('connection abort') ||
            detail.contains('software caused connection abort') ||
            detail.contains('connection reset')) {
          baseError = '网络连接中断，可能是切后台或系统回收连接';
          code = 'connection_aborted';
        } else if (detail.contains('timed out')) {
          baseError = '网络连接超时';
          code = 'unknown_timeout';
        } else {
          baseError = '未知网络错误';
          code = 'unknown_network_error';
        }
        retryable = true;
        if ((e.message ?? '').trim().isNotEmpty &&
            e.message!.trim().toLowerCase() != 'null') {
          baseError += '\n错误消息: ${e.message}';
        }
        if (e.error != null) {
          baseError += '\n底层错误: ${e.error}';
        }
        break;
    }

    return _ServiceError(
      code: code,
      retryable: retryable,
      message: '$baseError\n\n$debugInfo',
    );
  }

  String _extractBadResponseMessage(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] != null) {
        return _normalizeServerText(error['message'].toString());
      }
      if (data['message'] != null) {
        return _normalizeServerText(data['message'].toString());
      }
      return jsonEncode(data);
    }
    if (data is List<int>) {
      try {
        return _normalizeServerText(utf8.decode(data));
      } catch (_) {
        return data.toString();
      }
    }
    if (data != null) return _normalizeServerText(data.toString());
    return '未知错误';
  }

  String _normalizeServerText(String input) {
    final text = input.trim();
    if (text.isEmpty) return input;
    final looksMojibake = text.contains('\u00C3') ||
        text.contains('\u00C2') ||
        text.contains('\u00E2') ||
        text.contains('\u00E6') ||
        text.contains('\u00E5') ||
        text.contains('\u00E7') ||
        text.contains('\u00EF');
    if (!looksMojibake) return input;
    try {
      final decoded = utf8.decode(latin1.encode(text));
      return decoded;
    } catch (_) {
      return input;
    }
  }
}

class _ServiceError {
  final String code;
  final bool retryable;
  final String message;

  _ServiceError({
    required this.code,
    required this.retryable,
    required this.message,
  });
}
