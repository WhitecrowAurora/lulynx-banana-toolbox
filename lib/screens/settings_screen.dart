import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_i18n.dart';
import '../models/api_config.dart';
import '../models/usage_stats.dart';
import '../providers/providers.dart';
import '../services/diagnostic_service.dart';
import '../services/foreground_keep_alive_service.dart';
import '../services/nano_banana_service.dart';
import '../services/update_check_service.dart';
import '../widgets/settings_about_card.dart';
import '../widgets/settings_status_card.dart';
import '../widgets/settings_stats_card.dart';
import '../widgets/settings_data_logs_card.dart';
import '../widgets/settings_api_connection_section.dart';
import '../widgets/settings_footer_sections.dart';
import '../widgets/settings_general_section.dart';
import '../widgets/settings_provider_model_section.dart';
import '../widgets/settings_backup_actions.dart';
import '../widgets/settings_request_retry_section.dart';
import '../widgets/settings_reference_images_section.dart';
import '../widgets/settings_quality_preview_card.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/settings_stat_row.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const MethodChannel _logFileChannel =
      MethodChannel('com.nanobanana/log_file');
  static const MethodChannel _appUpdateChannel =
      MethodChannel('com.nanobanana/app_update');

  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _apiUserIdController;
  bool _obscureApiKey = true;
  bool _isTesting = false;
  String? _testResult;

  bool _isLoadingQuota = false;
  double? _quota;
  String? _quotaError;

  bool _isRefreshingStorage = false;
  int _imageCacheBytes = 0;
  int _logBytes = 0;
  Uint8List? _qualityPreviewOriginalBytes;
  Uint8List? _qualityPreviewCompressedBytes;
  String? _qualityPreviewImageName;
  String? _qualityPreviewError;
  bool _isQualityPreviewLoading = false;
  double _qualityPreviewSplit = 0.5;
  String _qualityPreviewConfigKey = '';
  bool _isCheckingBatteryOptimization = false;
  bool _ignoringBatteryOptimizations = false;
  bool _isBusyWithDiagnostics = false;
  List<Map<String, String>> _remoteModelItems = const [];
  bool _isLoadingModels = false;
  String? _modelLoadError;
  DateTime? _modelListUpdatedAt;
  String _modelListConfigKey = '';
  String _appVersionLabel = 'v1.6.5';
  bool _isCheckingUpdate = false;
  bool _isDownloadingUpdate = false;
  String? _updateStatus;
  bool _hasAutoCheckedUpdate = false;
  final DiagnosticService _diagnosticService = DiagnosticService();
  final UpdateCheckService _updateCheckService = UpdateCheckService();

  String _tr(String zh, {Map<String, Object?> args = const {}}) =>
      context.tr(zh, args: args);

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _apiUserIdController = TextEditingController();
    _refreshStorageStats();
    _refreshBatteryOptimizationStatus();
    unawaited(_loadPackageVersion());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _apiUserIdController.dispose();
    super.dispose();
  }

  void _initControllers(ApiConfig config) {
    if (_baseUrlController.text != config.baseUrl) {
      _baseUrlController.text = config.baseUrl;
    }
    if (_apiKeyController.text != config.apiKey) {
      _apiKeyController.text = config.apiKey;
    }
    if (_apiUserIdController.text != config.apiUserId) {
      _apiUserIdController.text = config.apiUserId;
    }
  }

  String _modelConfigKey(ApiConfig config) {
    return '${config.baseUrl.trim()}|${config.apiKey.trim()}|${config.providerId.trim()}';
  }

  String _formatDateTimeShort(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  Future<void> _loadPackageVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (!mounted) return;
      if (version.isNotEmpty) {
        setState(() {
          _appVersionLabel = 'v$version';
        });
      }
    } catch (_) {}
    final shouldAutoCheck = await _updateCheckService.shouldAutoCheckNow();
    if (!mounted || !shouldAutoCheck) return;
    await _checkForUpdates(userInitiated: false);
  }

  Future<void> _checkForUpdates({bool userInitiated = true}) async {
    if (_isCheckingUpdate) return;
    if (!userInitiated) {
      await _updateCheckService.markCheckAttemptNow();
    }
    setState(() {
      _isCheckingUpdate = true;
      if (userInitiated) {
        _updateStatus = _tr('检查中...');
      }
    });
    try {
      final result = await _updateCheckService.checkForUpdates(_appVersionLabel);
      if (!mounted) return;
      if (result.hasUpdate && result.release != null) {
        final isSkipped = await _updateCheckService.isSkippedReleaseTag(
          result.release!.tagName,
        );
        final latestDisplay = 'v${result.latestVersion}';
        if (isSkipped && !userInitiated) {
          setState(() {
            _updateStatus = _tr('已跳过版本 {version}', args: {'version': latestDisplay});
          });
          return;
        }
        setState(() {
          _updateStatus = _tr('发现新版本 {version}', args: {'version': latestDisplay});
        });
        if (userInitiated || !_hasAutoCheckedUpdate) {
          await _showUpdateDialog(result);
        }
      } else {
        setState(() {
          _updateStatus = _tr(
            '当前已是最新版本 {version}',
            args: {'version': 'v${result.currentVersion}'},
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateStatus = _tr('检查更新失败: {error}', args: {'error': '$e'});
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
          _hasAutoCheckedUpdate = true;
        });
      }
    }
  }

  Future<void> _showUpdateDialog(UpdateCheckResult result) async {
    final release = result.release;
    if (release == null || !mounted) return;
    final downloadUrl = release.apkDownloadUrl.isNotEmpty
        ? release.apkDownloadUrl
        : release.htmlUrl;
    final notes = release.body.trim();
    final preview = notes.isEmpty
        ? _tr('暂无发布说明')
        : (notes.length > 280 ? '${notes.substring(0, 280)}...' : notes);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: Text(_tr('发现新版本')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tr('当前版本：{version}', args: {'version': 'v${result.currentVersion}'}),
                ),
                const SizedBox(height: 4),
                Text(
                  _tr('最新版本：{version}', args: {'version': 'v${result.latestVersion}'}),
                ),
                const SizedBox(height: 12),
                Text(
                  _tr('发布说明'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SelectableText(preview),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _updateCheckService.skipReleaseTag(release.tagName);
                navigator.pop();
                if (!mounted) return;
                setState(() {
                  _updateStatus = _tr(
                    '已跳过版本 {version}',
                    args: {'version': release.tagName},
                  );
                });
              },
              child: Text(_tr('跳过该版本')),
            ),
            TextButton(
              onPressed: () => navigator.pop(),
              child: Text(_tr('暂不')),
            ),
            if (release.apkDownloadUrl.isNotEmpty)
              TextButton(
                onPressed: () {
                  navigator.pop();
                  unawaited(_downloadAndInstallUpdate(release));
                },
                child: Text(_tr('下载并安装')),
              ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: downloadUrl));
                navigator.pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_tr('下载地址已复制'))),
                );
              },
              child: Text(
                _tr(
                  release.apkDownloadUrl.isNotEmpty ? '复制下载地址' : '复制发布页地址',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndInstallUpdate(ReleaseInfo release) async {
    if (_isDownloadingUpdate) return;
    final downloadUrl = release.apkDownloadUrl.trim();
    if (downloadUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _updateStatus = _tr('未找到可下载的 APK 资源');
      });
      return;
    }

    final apkPath = await _cachedUpdateApkPath(release);
    final apkFile = File(apkPath);
    if (await apkFile.exists() && await apkFile.length() > 0) {
      if (!mounted) return;
      setState(() {
        _updateStatus = _tr('使用已下载的更新包 {version}', args: {'version': release.tagName});
      });
      await _installDownloadedApk(apkPath);
      return;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
      ),
    );

    setState(() {
      _isDownloadingUpdate = true;
      _updateStatus = _tr('开始下载更新 {version}', args: {'version': release.tagName});
    });

    try {
      await dio.download(
        downloadUrl,
        apkPath,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            final percent = ((received / total) * 100).clamp(0, 100).toStringAsFixed(0);
            setState(() {
              _updateStatus = _tr('正在下载更新 {percent}%', args: {'percent': percent});
            });
          } else {
            setState(() {
              _updateStatus = _tr('正在下载更新...');
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _updateStatus = _tr('更新包已下载，正在启动安装');
      });

      final installResult = await _appUpdateChannel.invokeMethod<String>(
        'installApk',
        {'apkPath': apkPath},
      );
      if (!mounted) return;
      switch (installResult) {
        case 'install_started':
          setState(() {
            _updateStatus = _tr('已打开安装器');
          });
          break;
        case 'permission_required':
          setState(() {
            _updateStatus = _tr('请允许安装未知来源应用后重试');
          });
          break;
        default:
          setState(() {
            _updateStatus = _tr('启动安装失败');
          });
          break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateStatus = _tr('下载更新失败: {error}', args: {'error': '$e'});
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingUpdate = false;
        });
      }
    }
  }

  Future<String> _cachedUpdateApkPath(ReleaseInfo release) async {
    final supportDir = await getApplicationSupportDirectory();
    final updateDir = Directory(path.join(supportDir.path, 'app_updates'));
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    final tag = release.tagName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return path.join(updateDir.path, 'lulynx_banana_toolbox_$tag.apk');
  }

  Future<void> _installDownloadedApk(String apkPath) async {
    try {
      final installResult = await _appUpdateChannel.invokeMethod<String>(
        'installApk',
        {'apkPath': apkPath},
      );
      if (!mounted) return;
      switch (installResult) {
        case 'install_started':
          setState(() {
            _updateStatus = _tr('已打开安装器');
          });
          break;
        case 'permission_required':
          setState(() {
            _updateStatus = _tr('请允许安装未知来源应用后重试');
          });
          break;
        default:
          setState(() {
            _updateStatus = _tr('启动安装失败');
          });
          break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateStatus = _tr('启动安装失败');
      });
    }
  }

  void _ensureModelListUpToDate(ApiConfig config) {
    final key = _modelConfigKey(config);
    if (key == _modelListConfigKey) return;
    _modelListConfigKey = key;

    if (!config.isValid) {
      if (_remoteModelItems.isNotEmpty ||
          _modelLoadError != null ||
          _modelListUpdatedAt != null) {
        setState(() {
          _remoteModelItems = const [];
          _modelLoadError = null;
          _modelListUpdatedAt = null;
          _isLoadingModels = false;
        });
      }
      return;
    }

    final hasCacheForCurrentConfig =
        config.cachedBananaModelsConfigKey == key &&
            config.cachedBananaModels.isNotEmpty;
    if (hasCacheForCurrentConfig) {
      setState(() {
        _remoteModelItems = List<Map<String, String>>.from(
          config.cachedBananaModels,
        );
        _modelListUpdatedAt = config.cachedBananaModelsFetchedAtMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                config.cachedBananaModelsFetchedAtMs,
              )
            : null;
        _modelLoadError = null;
        _isLoadingModels = false;
      });
      return;
    }

    if (_remoteModelItems.isNotEmpty || _modelListUpdatedAt != null) {
      setState(() {
        _remoteModelItems = const [];
        _modelListUpdatedAt = null;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshModelList(config));
    });
  }

  List<Map<String, String>> _effectiveModelItems(ApiConfig config) {
    final list = <Map<String, String>>[];
    if (_remoteModelItems.isNotEmpty) {
      list.addAll(_remoteModelItems);
    } else {
      list.addAll(ApiConfig.availableModels);
    }

    final currentModel = config.model.trim();
    if (currentModel.isNotEmpty && !list.any((e) => e['id'] == currentModel)) {
      list.insert(0, {'id': currentModel, 'name': '$currentModel (current)'});
    }
    return list;
  }

  Future<void> _refreshModelList(
    ApiConfig config, {
    bool manual = false,
  }) async {
    if (!config.isValid || _isLoadingModels) return;
    setState(() {
      _isLoadingModels = true;
      _modelLoadError = null;
    });

    final service = NanoBananaService(config: config);
    final result = await service.fetchModelList(bananaOnly: true);
    if (!mounted) return;

    if (result['success'] == true) {
      final models = (result['models'] as List?)
              ?.whereType<Map>()
              .map((e) {
                final id = e['id']?.toString().trim() ?? '';
                if (id.isEmpty) return null;
                final name = e['name']?.toString().trim();
                return <String, String>{
                  'id': id,
                  'name': (name == null || name.isEmpty) ? id : name,
                };
              })
              .whereType<Map<String, String>>()
              .toList() ??
          const <Map<String, String>>[];
      final fetchedAtMs = result['fetchedAt'] is int
          ? result['fetchedAt'] as int
          : DateTime.now().millisecondsSinceEpoch;
      final cacheKey = _modelConfigKey(config);
      setState(() {
        _remoteModelItems = models;
        _modelListUpdatedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
        _isLoadingModels = false;
        _modelLoadError = null;
      });
      final latestConfig = ref.read(apiConfigProvider);
      if (_modelConfigKey(latestConfig) == cacheKey) {
        ref.read(apiConfigProvider.notifier).setCachedBananaModels(
              cacheKey: cacheKey,
              models: models,
              fetchedAtMs: fetchedAtMs,
            );
      }
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr('Model list refreshed: {count}',
                  args: {'count': models.length}),
            ),
          ),
        );
      }
      return;
    }

    final errorText = (result['error']?.toString().trim().isNotEmpty ?? false)
        ? result['error'].toString()
        : _tr('Failed to load model list');
    setState(() {
      _isLoadingModels = false;
      _modelLoadError = errorText;
    });
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText)),
      );
    }
  }

  Future<void> _refreshStorageStats() async {
    setState(() => _isRefreshingStorage = true);
    final db = ref.read(chatDatabaseProvider);
    final log = ref.read(appLogServiceProvider);
    final imageSize = await db.getImageCacheSizeBytes();
    final logSize = await log.getLogSizeBytes();
    if (!mounted) return;
    setState(() {
      _imageCacheBytes = imageSize;
      _logBytes = logSize;
      _isRefreshingStorage = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _previewConfigKey(ApiConfig config) {
    return [
      config.referenceNormalizeFormat,
      config.referenceQuality.toString(),
      config.referenceMaxDimension.toString(),
      (_qualityPreviewOriginalBytes?.length ?? 0).toString(),
    ].join('|');
  }

  void _ensurePreviewUpToDate(ApiConfig config) {
    if (_qualityPreviewOriginalBytes == null || _isQualityPreviewLoading) {
      return;
    }
    final key = _previewConfigKey(config);
    if (key == _qualityPreviewConfigKey) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_rebuildQualityPreview(config));
    });
  }

  Future<void> _pickQualityPreviewImage(ApiConfig config) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('读取测试图片失败'))),
      );
      return;
    }

    setState(() {
      _qualityPreviewOriginalBytes = bytes;
      _qualityPreviewCompressedBytes = null;
      _qualityPreviewError = null;
      _qualityPreviewImageName = file.name;
      _qualityPreviewSplit = 0.5;
      _qualityPreviewConfigKey = '';
    });
    await _rebuildQualityPreview(config);
  }

  Future<void> _rebuildQualityPreview(ApiConfig config) async {
    final original = _qualityPreviewOriginalBytes;
    if (original == null || original.isEmpty) return;

    setState(() {
      _isQualityPreviewLoading = true;
      _qualityPreviewError = null;
    });

    try {
      final compressed = await compute<Map<String, Object>, Uint8List>(
        _compressPreviewBytesInIsolate,
        <String, Object>{
          'bytes': original,
          'maxDimension': config.referenceMaxDimension,
          'quality': config.referenceQuality,
          'format': config.referenceNormalizeFormat,
        },
      );
      if (!mounted) return;
      setState(() {
        _qualityPreviewCompressedBytes = compressed;
        _qualityPreviewConfigKey = _previewConfigKey(config);
        _isQualityPreviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qualityPreviewError = '$e';
        _isQualityPreviewLoading = false;
      });
    }
  }

  Future<void> _queryQuota() async {
    final config = ref.read(apiConfigProvider);
    if (!config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('请先填写 API 端点和 Key'))),
      );
      return;
    }

    setState(() {
      _isLoadingQuota = true;
      _quotaError = null;
    });

    final service = NanoBananaService(config: config);
    final result = await service.getTokenQuota();

    if (!mounted) return;
    setState(() {
      _isLoadingQuota = false;
      if (result['success'] == true) {
        _quota = (result['quota'] as num?)?.toDouble();
      } else {
        _quotaError = result['error'] as String?;
      }
    });
  }

  Future<void> _testConnection() async {
    final config = ref.read(apiConfigProvider);
    if (!config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('请先填写 API 端点和 Key'))),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final service = NanoBananaService(config: config);
    final result = await service.testConnection();

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  void _showTestResult() {
    if (_testResult == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('测试结果'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _testResult!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_tr('Copied'))),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _testResult!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLog() async {
    final logService = ref.read(appLogServiceProvider);
    final path = await logService.exportLog();
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('No logs to export'))),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('日志已导出: {path}', args: {'path': path}))),
    );
    _refreshStorageStats();
  }

  Future<void> _shareLog() async {
    final logService = ref.read(appLogServiceProvider);
    final text = await logService.readAll();
    if (!mounted) return;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('No logs to share'))),
      );
      return;
    }

    try {
      await _logFileChannel.invokeMethod<bool>('shareLogText', {
        'text': text,
        'subject': _tr('Nano Banana 日志'),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('已打开分享面板'))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('当前平台暂不支持分享日志'))),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('分享失败: {error}', args: {'error': e.message ?? e.code}),
          ),
        ),
      );
    }
  }

  Future<void> _saveLogAs() async {
    final logService = ref.read(appLogServiceProvider);
    final text = await logService.readAll();
    if (!mounted) return;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('No logs to save'))),
      );
      return;
    }

    final fileName =
        'nano_banana_log_${DateTime.now().millisecondsSinceEpoch}.log';
    try {
      final path = await _logFileChannel.invokeMethod<String>(
        'saveLogToDownloads',
        {
          'text': text,
          'fileName': fileName,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              '日志已保存: {path}',
              args: {'path': path ?? fileName},
            ),
          ),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Save not supported on this platform'))),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('淇濆瓨澶辫触: {error}', args: {'error': e.message ?? e.code}),
          ),
        ),
      );
    }
  }

  Future<void> _refreshBatteryOptimizationStatus() async {
    if (!Platform.isAndroid) return;
    setState(() => _isCheckingBatteryOptimization = true);
    final ignoring =
        await ForegroundKeepAliveService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _ignoringBatteryOptimizations = ignoring;
      _isCheckingBatteryOptimization = false;
    });
  }

  Future<void> _openBatteryOptimizationSettings() async {
    await ForegroundKeepAliveService.openBatteryOptimizationSettings();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _refreshBatteryOptimizationStatus();
  }

  String _tailLogText(
    String raw, {
    int maxLines = 220,
    int maxChars = 160000,
  }) {
    if (raw.isEmpty) return '';
    final normalized = raw.replaceAll('\r\n', '\n').trimRight();
    if (normalized.isEmpty) return '';
    final lines = normalized.split('\n');
    final tail = lines.length > maxLines
        ? lines.sublist(lines.length - maxLines)
        : lines;
    var text = tail.join('\n');
    if (text.length > maxChars) {
      text = text.substring(text.length - maxChars);
    }
    return text;
  }

  Future<String> _buildDiagnosticText() async {
    final config = ref.read(apiConfigProvider);
    final generation = ref.read(generationProvider);
    final db = ref.read(chatDatabaseProvider);
    final logService = ref.read(appLogServiceProvider);

    UsageStats? usageStats;
    try {
      usageStats = await ref.read(usageStatsProvider.future);
    } catch (_) {
      usageStats = null;
    }

    final imageCacheBytes = await db.getImageCacheSizeBytes();
    final logBytes = await logService.getLogSizeBytes();
    final allLogs = await logService.readAll();
    final recentLogs = _tailLogText(allLogs);

    return _diagnosticService.buildReport(
      config: config,
      usageStats: usageStats,
      queue: generation.queue,
      isGenerating: generation.isLoading,
      imageCacheBytes: imageCacheBytes,
      logBytes: logBytes,
      recentLogs: recentLogs,
    );
  }

  Future<void> _exportDiagnosticToAppFiles() async {
    if (_isBusyWithDiagnostics) return;
    setState(() => _isBusyWithDiagnostics = true);
    try {
      final text = await _buildDiagnosticText();
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(path.join(docs.path, 'diagnostic'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final fileName =
          'nano_banana_diagnostic_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path.join(dir.path, fileName));
      await file.writeAsString(text, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('璇婃柇鍖呭凡瀵煎嚭: {path}', args: {'path': file.path}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('瀵煎嚭璇婃柇鍖呭け璐? {error}', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusyWithDiagnostics = false);
      }
    }
  }

  Future<void> _shareDiagnostic() async {
    if (_isBusyWithDiagnostics) return;
    setState(() => _isBusyWithDiagnostics = true);
    try {
      final text = await _buildDiagnosticText();
      await _logFileChannel.invokeMethod<bool>('shareLogText', {
        'text': text,
        'subject': _tr('Nano Banana Diagnostics'),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Share panel opened'))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Share is not supported on this platform'))),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('鍒嗕韩璇婃柇鍖呭け璐? {error}', args: {'error': e.message ?? e.code}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('鍒嗕韩璇婃柇鍖呭け璐? {error}', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusyWithDiagnostics = false);
      }
    }
  }

  Future<void> _saveDiagnosticAs() async {
    if (_isBusyWithDiagnostics) return;
    setState(() => _isBusyWithDiagnostics = true);
    try {
      final text = await _buildDiagnosticText();
      final fileName =
          'nano_banana_diagnostic_${DateTime.now().millisecondsSinceEpoch}.json';
      final savedPath = await _logFileChannel.invokeMethod<String>(
        'saveLogToDownloads',
        {
          'text': text,
          'fileName': fileName,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              '诊断包已保存: {path}',
              args: {'path': savedPath ?? fileName},
            ),
          ),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('当前平台暂不支持另存为诊断包'))),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('淇濆瓨璇婃柇鍖呭け璐? {error}', args: {'error': e.message ?? e.code}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('淇濆瓨璇婃柇鍖呭け璐? {error}', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusyWithDiagnostics = false);
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('清空日志')),
        content: Text(_tr('Confirm clearing all log files?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('确认')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(appLogServiceProvider).clearLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('Logs cleared'))),
    );
    _refreshStorageStats();
  }

  Future<void> _clearImageCache() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('清理图片缓存')),
        content:
            Text(_tr('该操作会删除本地缓存图片，历史记录里的本地图像将无法显示。是否继续？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('继续')),
          ),
        ],
      ),
    );
    if (first != true) return;
    if (!mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('二次确认')),
        content: Text(_tr('Confirm deleting all cached images?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('确定删除')),
          ),
        ],
      ),
    );
    if (second != true) return;

    await ref.read(chatDatabaseProvider).clearImageCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('Image cache cleared'))),
    );
    _refreshStorageStats();
    ref.read(messagesProvider.notifier).refresh();
  }

  Future<void> _createBackup() async {
    final path = await ref.read(backupServiceProvider).createBackupFile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('备份已创建: {path}', args: {'path': path}))),
    );
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final filePath = result.files.first.path;
    if (filePath == null || filePath.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('恢复备份')),
        content: Text(_tr('恢复会覆盖当前会话与配置。是否继续？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('恢复')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(backupServiceProvider).restoreFromFile(filePath);
    final config = await ref.read(storageServiceProvider).loadConfig();
    await ref.read(apiConfigProvider.notifier).updateConfig(config);
    await ref.read(sessionsProvider.notifier).loadSessions();
    ref.read(currentSessionIdProvider.notifier).state = null;
    await ref.read(storageServiceProvider).saveLastSessionId(null);
    ref.invalidate(usageStatsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('备份恢复完成'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(apiConfigProvider);
    final notifier = ref.read(apiConfigProvider.notifier);
    final usageStatsAsync = ref.watch(usageStatsProvider);
    String tr(String zh, {Map<String, Object?> args = const {}}) =>
        context.tr(zh, args: args);

    _initControllers(config);
    _ensurePreviewUpToDate(config);
    _ensureModelListUpToDate(config);
    final modelItems = _effectiveModelItems(config);
    final selectedModelValue =
        modelItems.any((m) => m['id'] == config.model) ? config.model : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('设置')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGeneralSection(
            config: config,
            title: tr('账户余额'),
            quotaUnitLabel: tr('额度'),
            refreshTooltip: tr('刷新余额'),
            emptyHint: tr('点击刷新查询余额'),
            showBalanceTitle: tr('Show balance on home'),
            showBalanceSubtitle: tr('在主页输入框上方显示账户余额'),
            languageLabel: tr('语言'),
            languageHelper: tr('选择应用显示语言'),
            snackBarLabel: tr('Save toast position'),
            snackBarHelper: tr('Show save result toast at top or bottom'),
            quota: _quota,
            quotaError: _quotaError,
            isLoadingQuota: _isLoadingQuota,
            onRefreshQuota: _queryQuota,
            onShowBalanceChanged: notifier.setShowBalanceOnHome,
            onAppLanguageChanged: notifier.setAppLanguage,
            onSnackBarPositionChanged: notifier.setSnackBarPosition,
            translate: tr,
          ),
          SettingsApiConnectionSection(
            title: tr('API 配置'),
            baseUrlController: _baseUrlController,
            apiKeyController: _apiKeyController,
            apiUserIdController: _apiUserIdController,
            baseUrlLabel: tr('API 端点'),
            baseUrlHelper: tr('Enter API endpoint without /v1/... suffix'),
            apiKeyHint: tr('输入你的 API Key'),
            apiUserIdLabel: tr('New-API-User (可选)'),
            apiUserIdHint: tr('用于 /api/user/self 查询余额'),
            isTesting: _isTesting,
            isObscured: _obscureApiKey,
            testConnectionLabel: tr('Test connection'),
            testingLabel: tr('Testing...'),
            viewResultLabel: tr('查看结果'),
            showTestResultButton: _testResult != null,
            onBaseUrlChanged: (value) => notifier.setBaseUrl(value.trim()),
            onApiKeyChanged: (value) => notifier.setApiKey(value.trim()),
            onApiUserIdChanged: (value) => notifier.setApiUserId(value.trim()),
            onToggleObscured: () {
              setState(() => _obscureApiKey = !_obscureApiKey);
            },
            onTestConnection: _testConnection,
            onViewResult: _showTestResult,
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          _buildSectionHeader(tr('Provider & Model')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: config.providerId,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.hub_outlined),
            ),
            items: ApiConfig.availableProviders.map((provider) {
              return DropdownMenuItem(
                value: provider['id'],
                child: Text(provider['name']!),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) notifier.setProviderId(value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedModelValue,
            decoration: InputDecoration(
              labelText: tr('模型'),
              helperText: _remoteModelItems.isNotEmpty
                  ? tr('仅显示 banana 系列模型')
                  : tr('当前使用本地模型列表'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.auto_awesome),
            ),
            items: modelItems.map((model) {
              return DropdownMenuItem(
                value: model['id'],
                child: Text(model['name'] ?? model['id'] ?? ''),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) notifier.setModel(value);
            },
          ),
          SettingsProviderModelSection(
            title: tr('Provider & Model'),
            providerValue: config.providerId,
            providerItems: ApiConfig.availableProviders.map((provider) {
              return DropdownMenuItem<String>(
                value: provider['id'],
                child: Text(provider['name']!),
              );
            }).toList(),
            modelValue: selectedModelValue,
            modelLabel: tr('模型'),
            modelHelperText: _remoteModelItems.isNotEmpty
                ? tr('仅显示 banana 系列模型')
                : tr('当前使用本地模型列表'),
            modelItems: modelItems.map((model) {
              return DropdownMenuItem<String>(
                value: model['id'],
                child: Text(model['name'] ?? model['id'] ?? ''),
              );
            }).toList(),
            modelStatusText: _isLoadingModels
                ? tr('模型列表刷新中...')
                : (_modelListUpdatedAt != null
                    ? tr(
                        '模型列表最后更新时间: {time}',
                        args: {
                          'time': _formatDateTimeShort(_modelListUpdatedAt!),
                        },
                      )
                    : tr('模型列表未从 API 拉取')),
            modelLoadError: _modelLoadError,
            isLoadingModels: _isLoadingModels,
            refreshModelsLabel: tr('刷新模型'),
            onProviderChanged: notifier.setProviderId,
            onModelChanged: notifier.setModel,
            onRefreshModels: () => _refreshModelList(config, manual: true),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: config.aspectRatio,
            decoration: InputDecoration(
              labelText: tr('图片比例'),
              helperText: tr('Auto ratio lets the model decide aspect ratio'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.aspect_ratio),
            ),
            items: ApiConfig.availableAspectRatios.map((ratio) {
              final label = ratio == ApiConfig.autoAspectRatio
                  ? tr('自动比例（模型决定）')
                  : ratio;
              return DropdownMenuItem(value: ratio, child: Text(label));
            }).toList(),
            onChanged: (value) {
              if (value != null) notifier.setAspectRatio(value);
            },
          ),
          const SizedBox(height: 16),
          if (config.supportsImageSize) ...[
            DropdownButtonFormField<String>(
              value: config.imageSize,
              decoration: InputDecoration(
                labelText: tr('图片尺寸'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.high_quality),
              ),
              items: ApiConfig.availableImageSizes.map((size) {
                return DropdownMenuItem(value: size, child: Text(size));
              }).toList(),
              onChanged: (value) {
                if (value != null) notifier.setImageSize(value);
              },
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
          SettingsRequestRetrySection(
            title: tr('Request & Retry'),
            requestTimeoutValue: config.requestTimeoutSeconds,
            requestTimeoutLabel: tr('Request timeout (seconds)'),
            secondUnitLabel: tr('s'),
            onRequestTimeoutChanged: notifier.setRequestTimeoutSeconds,
            maxRetryCountValue: config.maxRetryCount,
            maxRetryCountLabel: tr('Max auto retry count'),
            timesUnitLabel: tr('times'),
            autoRetryEnabled: config.autoRetryEnabled,
            onMaxRetryCountChanged: notifier.setMaxRetryCount,
            retryBaseDelayValue: config.retryBaseDelayMs,
            retryBaseDelayLabel: tr('重试基础延迟（毫秒）'),
            onRetryBaseDelayChanged: (value) {
              notifier.setRetryBaseDelayMs(value);
              if (value > config.retryMaxDelayMs) {
                notifier.setRetryMaxDelayMs(value);
              }
            },
            retryMaxDelayValue: config.retryMaxDelayMs < config.retryBaseDelayMs
                ? config.retryBaseDelayMs
                : config.retryMaxDelayMs,
            retryMaxDelayLabel: tr('Retry max delay (ms)'),
            retryMaxDelayOptions: ApiConfig.availableRetryMaxDelayMs
                .where((v) => v >= config.retryBaseDelayMs)
                .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v ms')))
                .toList(),
            onRetryMaxDelayChanged: notifier.setRetryMaxDelayMs,
            retryJitterValue: config.retryJitterPercent,
            retryJitterLabel: tr('重试抖动比例'),
            onRetryJitterChanged: notifier.setRetryJitterPercent,
            enhancedReferenceTitle: tr('Enhanced reference compatibility'),
            enhancedReferenceSubtitle: tr('失败时会尝试其他参考图上传格式（可能增加请求次数）'),
            enhancedReferenceValue: config.referenceCompatEnhanced,
            onEnhancedReferenceChanged: notifier.setReferenceCompatEnhanced,
            backgroundKeepAliveTitle: tr('Background keep-alive (Android)'),
            backgroundKeepAliveSubtitle: tr('生成任务时显示常驻通知，减少切后台后任务被系统中断'),
            backgroundKeepAliveValue: config.backgroundKeepAliveEnabled,
            onBackgroundKeepAliveChanged: Platform.isAndroid
                ? notifier.setBackgroundKeepAliveEnabled
                : null,
            notificationResidentTitle: tr('Notification resident (Android)'),
            notificationResidentSubtitle: tr('开启后常驻通知栏，可降低切到后台后被系统回收的概率'),
            notificationResidentValue: config.notificationResidentEnabled,
            onNotificationResidentChanged: Platform.isAndroid
                ? notifier.setNotificationResidentEnabled
                : null,
            showBatteryOptimizationCard: Platform.isAndroid,
            ignoringBatteryOptimizations: _ignoringBatteryOptimizations,
            batteryOptimizedText: tr('电池优化已忽略（后台更稳定）'),
            disableBatteryOptimizationText: tr('Disable battery optimization for better background stability'),
            isCheckingBatteryOptimization: _isCheckingBatteryOptimization,
            openSettingsLabel: tr('Open settings'),
            checkingLabel: tr('检查中...'),
            onOpenBatteryOptimizationSettings: _openBatteryOptimizationSettings,
          ),
          SettingsReferenceImagesSection(
            title: tr('Reference images'),
            referenceUploadModeValue: config.referenceUploadMode,
            referenceUploadModeLabel: tr('参考图上传模式'),
            referenceUploadModeItems: ApiConfig.availableReferenceUploadModes
                .map((mode) => DropdownMenuItem<String>(
                      value: mode['id'],
                      child: Text(mode['name']!),
                    ))
                .toList(),
            onReferenceUploadModeChanged: notifier.setReferenceUploadMode,
            preprocessOnPickTitle: tr('添加时预压缩参考图'),
            preprocessOnPickSubtitle: tr('选择图片后先压缩再加入参考图列表'),
            preprocessOnPickValue: config.referencePreprocessOnPick,
            onPreprocessOnPickChanged: notifier.setReferencePreprocessOnPick,
            referencePreviewSizeValue: config.referencePreviewSize,
            referencePreviewSizeLabel: tr('参考图预览大小'),
            referencePreviewSizeItems: ApiConfig.availableReferencePreviewSizes
                .map((item) => DropdownMenuItem<String>(
                      value: item['id'],
                      child: Text(item['name']!),
                    ))
                .toList(),
            onReferencePreviewSizeChanged: notifier.setReferencePreviewSize,
            referenceMaxSingleImageMbValue: config.referenceMaxSingleImageMb,
            referenceMaxSingleImageMbLabel: tr('单张参考图上限'),
            referenceMaxSingleImageMbItems: ApiConfig.availableReferenceSingleLimitMb
                .map((value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value MB'),
                    ))
                .toList(),
            onReferenceMaxSingleImageMbChanged: notifier.setReferenceMaxSingleImageMb,
            preprocessReferenceTitle: tr('Preprocess reference image'),
            preprocessReferenceSubtitle: tr('上传前调整尺寸并压缩参考图'),
            preprocessReferenceValue: config.referencePreprocessEnabled,
            onPreprocessReferenceChanged: notifier.setReferencePreprocessEnabled,
            referenceFormatValue: config.referenceNormalizeFormat,
            referenceFormatLabel: tr('参考图格式'),
            referenceFormatItems: ApiConfig.availableReferenceFormats
                .map((mode) => DropdownMenuItem<String>(
                      value: mode['id'],
                      child: Text(mode['name']!),
                    ))
                .toList(),
            onReferenceFormatChanged: (value) {
              notifier.setReferenceNormalizeFormat(value);
              unawaited(_rebuildQualityPreview(
                config.copyWith(referenceNormalizeFormat: value),
              ));
            },
            referenceMaxDimensionValue: config.referenceMaxDimension,
            referenceMaxDimensionLabel: tr('Reference max dimension'),
            referenceMaxDimensionItems: ApiConfig.availableReferenceMaxDimensions
                .map((value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text(value == 0 ? tr('Unlimited') : '${value}px'),
                    ))
                .toList(),
            onReferenceMaxDimensionChanged: (value) {
              notifier.setReferenceMaxDimension(value);
              unawaited(_rebuildQualityPreview(
                config.copyWith(referenceMaxDimension: value),
              ));
            },
            referenceQualityValue: config.referenceQuality,
            referenceQualityLabel: tr('参考图质量'),
            referenceQualityItems: ApiConfig.availableReferenceQualities
                .map((value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    ))
                .toList(),
            onReferenceQualityChanged: (value) {
              notifier.setReferenceQuality(value);
              unawaited(_rebuildQualityPreview(
                config.copyWith(referenceQuality: value),
              ));
            },
            qualityPreviewCard: _buildQualityPreviewCard(config),
            autoDegradeTitle: tr('Auto degrade on retry'),
            autoDegradeSubtitle: tr('Reduce size and quality on each retry'),
            autoDegradeValue: config.referenceAutoDegradeOnRetry,
            onAutoDegradeChanged: notifier.setReferenceAutoDegradeOnRetry,
            idempotencyKeyTitle: tr('发送幂等键'),
            idempotencyKeySubtitle: tr('在请求头中使用任务 ID'),
            idempotencyKeyValue: config.sendIdempotencyKey,
            onIdempotencyKeyChanged: notifier.setSendIdempotencyKey,
            enforceHttpsTitle: tr('强制 HTTPS'),
            enforceHttpsSubtitle: tr('开启后仅允许 https:// 端点'),
            enforceHttpsValue: config.enforceHttps,
            onEnforceHttpsChanged: notifier.setEnforceHttps,
          ),
          const SizedBox(height: 24),
          SettingsFooterSections(
            dataLogsTitle: tr('Data & Logs'),
            dataLogsCard: SettingsDataLogsCard(
              imageCacheLabel: tr('图片缓存'),
              imageCacheValue: _formatBytes(_imageCacheBytes),
              logLabel: tr('日志文件'),
              logValue: _formatBytes(_logBytes),
              refreshLabel: tr('刷新'),
              exportLogLabel: tr('导出日志'),
              shareLogLabel: tr('分享日志'),
              saveAsLabel: tr('Save as'),
              exportDiagnosticsLabel: tr('Export diagnostics'),
              shareDiagnosticsLabel: tr('Share diagnostics'),
              saveDiagnosticsLabel: tr('诊断包另存为'),
              clearLogsLabel: tr('清空日志'),
              clearImageCacheLabel: tr('清理图片缓存'),
              isRefreshingStorage: _isRefreshingStorage,
              isBusyWithDiagnostics: _isBusyWithDiagnostics,
              onRefreshStorage: _refreshStorageStats,
              onExportLog: _exportLog,
              onShareLog: _shareLog,
              onSaveLogAs: _saveLogAs,
              onExportDiagnostics: _exportDiagnosticToAppFiles,
              onShareDiagnostics: _shareDiagnostic,
              onSaveDiagnosticsAs: _saveDiagnosticAs,
              onClearLogs: _clearLogs,
              onClearImageCache: _clearImageCache,
            ),
            backupTitle: tr('备份恢复'),
            backupActions: SettingsBackupActions(
              createBackupLabel: tr('创建备份'),
              restoreBackupLabel: tr('恢复备份'),
              onCreateBackup: _createBackup,
              onRestoreBackup: _restoreBackup,
            ),
            statsTitle: tr('统计'),
            statsCard: SettingsStatsCard(
              child: usageStatsAsync.when(
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(tr('Total generations'), '${stats.totalCount}'),
                    _buildStatRow(tr('成功次数'), '${stats.successCount}'),
                    _buildStatRow(tr('失败次数'), '${stats.failureCount}'),
                    _buildStatRow(
                      tr('Success rate'),
                      '${stats.successRate.toStringAsFixed(1)}%',
                    ),
                    _buildStatRow(tr('平均耗时'), '${stats.avgDurationMs} ms'),
                  ],
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) =>
                    Text(tr('统计加载失败: {error}', args: {'error': '$err'})),
              ),
            ),
            statusTitle: tr('Status'),
            statusCard: SettingsStatusCard(
              isValid: config.isValid,
              completeLabel: tr('Configuration complete'),
              incompleteLabel: tr('Configuration incomplete'),
            ),
            aboutCard: SettingsAboutCard(
              appName: "Lulynx's Nano Banana Toolbox",
              version: _appVersionLabel,
              copyrightTitle: tr('版权声明'),
              copyrightText: tr('Copyright (C) 2026 Lulu (Ruilynx). All rights reserved.'),
              thanksText: tr('Thanks Longyin and Lianz for bug testing to speed up development.'),
              licenseRows: [
                tr('Personal use only'),
                tr('禁止以任何形式出售、转卖或商业使用'),
                tr('Do not repackage for distribution'),
                tr('本软件永久免费，如有收费均为诈骗'),
              ],
              checkUpdateLabel: tr('检查更新'),
              onCheckUpdate: _checkForUpdates,
              isCheckingUpdate: _isCheckingUpdate,
              isDownloadingUpdate: _isDownloadingUpdate,
              updateStatus: _updateStatus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPreviewCard(ApiConfig config) {
    return SettingsQualityPreviewCard(
      originalBytes: _qualityPreviewOriginalBytes,
      compressedBytes: _qualityPreviewCompressedBytes,
      imageName: _qualityPreviewImageName,
      errorText: _qualityPreviewError,
      isLoading: _isQualityPreviewLoading,
      split: _qualityPreviewSplit,
      title: _tr('压缩质量对比预览'),
      pickButtonLabel: _tr('选择图片'),
      dragHintText: _tr('拖动中间分割线，左侧原图，右侧压缩图'),
      emptyHintText: _tr('选择测试图片后可预览压缩效果'),
      fileNameLabel: _tr('文件: {name}'),
      unnamedLabel: _tr('未命名'),
      originalOnlyLabel: _tr('原图: {original}'),
      comparisonLabel: _tr('原图: {original}    压缩后: {compressed}'),
      previewFailedText: _tr('预览生成失败'),
      originalTag: _tr('原图'),
      compressedTag: _tr('压缩后'),
      onPickImage: () => _pickQualityPreviewImage(config),
      onSplitChanged: (value) {
        setState(() {
          _qualityPreviewSplit = value;
        });
      },
      formatBytes: _formatBytes,
    );
  }

  Widget _buildSectionHeader(String title) {
    return SettingsSectionHeader(title: title);
  }

  Widget _buildStatRow(String key, String value) {
    return SettingsStatRow(label: key, value: value);
  }
}

Uint8List _compressPreviewBytesInIsolate(Map<String, Object> payload) {
  final rawBytes = payload['bytes'];
  if (rawBytes is! Uint8List || rawBytes.isEmpty) {
    throw Exception('Unsupported image format');
  }
  final original = rawBytes;
  final maxDimension = (payload['maxDimension'] as int?) ?? 0;
  final quality = ((payload['quality'] as int?) ?? 90).clamp(40, 100);
  final format =
      (payload['format'] as String?) ?? ApiConfig.referenceFormatKeep;

  final decoded = img.decodeImage(original);
  if (decoded == null) {
    throw Exception('Unsupported image format');
  }

  var working = decoded;
  if (maxDimension > 0 &&
      (working.width > maxDimension || working.height > maxDimension)) {
    if (working.width >= working.height) {
      working = img.copyResize(working, width: maxDimension);
    } else {
      working = img.copyResize(working, height: maxDimension);
    }
  }

  switch (format) {
    case ApiConfig.referenceFormatJpeg:
      return Uint8List.fromList(img.encodeJpg(working, quality: quality));
    case ApiConfig.referenceFormatPng:
      return Uint8List.fromList(img.encodePng(working));
    case ApiConfig.referenceFormatWebp:
      return Uint8List.fromList(img.encodeJpg(working, quality: quality));
    case ApiConfig.referenceFormatKeep:
    default:
      final mime = _sniffImageMimeTypeBytes(original);
      if (mime == 'image/png') {
        return Uint8List.fromList(img.encodePng(working));
      }
      return Uint8List.fromList(img.encodeJpg(working, quality: quality));
  }
}

String _sniffImageMimeTypeBytes(Uint8List bytes) {
  if (bytes.length >= 4) {
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
  }
  return 'image/jpeg';
}
