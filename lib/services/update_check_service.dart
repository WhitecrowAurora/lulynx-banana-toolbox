import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.name,
    required this.body,
    required this.apkDownloadUrl,
  });

  final String tagName;
  final String htmlUrl;
  final String name;
  final String body;
  final String apkDownloadUrl;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.release,
  });

  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final ReleaseInfo? release;
}

class UpdateCheckService {
  static const String _latestReleaseApi =
      'https://api.github.com/repos/WhitecrowAurora/lulynx-banana-toolbox/releases/latest';
  static const String _lastCheckAtKey = 'update_check_last_checked_at_ms';
  static const String _skippedReleaseTagKey = 'update_check_skipped_release_tag';
  static const int _defaultAutoCheckIntervalMs = 24 * 60 * 60 * 1000;

  UpdateCheckService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'User-Agent': 'lulynx-banana-toolbox',
              },
            ),
          );

  final Dio _dio;

  Future<bool> shouldAutoCheckNow({
    Duration interval = const Duration(milliseconds: _defaultAutoCheckIntervalMs),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckedAtMs = prefs.getInt(_lastCheckAtKey) ?? 0;
    if (lastCheckedAtMs <= 0) return true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs - lastCheckedAtMs >= interval.inMilliseconds;
  }

  Future<void> markCheckAttemptNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> skipReleaseTag(String tagName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedReleaseTagKey, tagName.trim());
  }

  Future<String> loadSkippedReleaseTag() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_skippedReleaseTagKey) ?? '').trim();
  }

  Future<bool> isSkippedReleaseTag(String tagName) async {
    final skippedTag = await loadSkippedReleaseTag();
    return skippedTag.isNotEmpty &&
        skippedTag.toLowerCase() == tagName.trim().toLowerCase();
  }

  Future<UpdateCheckResult> checkForUpdates(String currentVersion) async {
    try {
      final response = await _dio.get<dynamic>(_latestReleaseApi);
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('invalid release payload');
      }

      final tagName = (data['tag_name'] ?? '').toString().trim();
      final htmlUrl = (data['html_url'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();
      final body = (data['body'] ?? '').toString();
      final apkDownloadUrl = _extractApkDownloadUrl(data['assets']);
      if (tagName.isEmpty || htmlUrl.isEmpty) {
        throw const FormatException('missing release fields');
      }

      final normalizedCurrent = _normalizeVersion(currentVersion);
      final normalizedLatest = _normalizeVersion(tagName);
      final release = ReleaseInfo(
        tagName: tagName,
        htmlUrl: htmlUrl,
        name: name,
        body: body,
        apkDownloadUrl: apkDownloadUrl,
      );
      return UpdateCheckResult(
        currentVersion: normalizedCurrent,
        latestVersion: normalizedLatest,
        hasUpdate:
            _compareVersions(normalizedLatest, normalizedCurrent) > 0,
        release: release,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403) {
        throw Exception('GitHub API rate limit');
      }
      if (status == 404) {
        throw Exception('release not found');
      }
      throw Exception(e.message ?? 'network error');
    }
  }

  String _extractApkDownloadUrl(dynamic rawAssets) {
    if (rawAssets is! List) return '';
    for (final asset in rawAssets) {
      if (asset is! Map) continue;
      final name = (asset['name'] ?? '').toString().toLowerCase();
      final url = (asset['browser_download_url'] ?? '').toString().trim();
      if (name.endsWith('.apk') && url.isNotEmpty) {
        return url;
      }
    }
    return '';
  }

  String _normalizeVersion(String input) {
    final cleaned = input.trim().toLowerCase().replaceFirst(RegExp(r'^v+'), '');
    final buildSplit = cleaned.split('+').first;
    final match = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(buildSplit);
    return match?.group(1) ?? buildSplit;
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < maxLen; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
