import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../l10n/app_i18n.dart';
import '../services/app_log_service.dart';

class GalleryPickerScreen extends StatefulWidget {
  final String sourceTag;

  const GalleryPickerScreen({
    super.key,
    this.sourceTag = 'gallery',
  });

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  final AppLogService _logService = AppLogService();
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _images = [];
  AssetPathEntity? _selectedAlbum;
  Map<String, int> _albumCounts = {};
  bool _isLoading = true;
  bool _permissionDenied = false;
  String? _error;

  String _tr(String zh, {Map<String, Object?> args = const {}}) {
    Locale locale;
    try {
      locale = Localizations.localeOf(context);
    } catch (_) {
      locale = WidgetsBinding.instance.platformDispatcher.locale;
    }
    return AppI18n(locale).t(zh, args: args);
  }

  PermissionRequestOption get _permissionOption =>
      const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      );

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  String _bytesFingerprint(Uint8List bytes) {
    final take = bytes.length < 8 ? bytes.length : 8;
    final head =
        bytes.take(take).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${bytes.length}:$head';
  }

  Future<void> _logImageDebug({
    required String message,
    Map<String, dynamic>? extra,
    String level = 'info',
  }) async {
    try {
      await _logService.append(
        level: level,
        message: message,
        extra: {
          'sourceTag': widget.sourceTag,
          if (extra != null) ...extra,
        },
      );
    } catch (_) {}
  }

  Future<void> _loadImages() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: _permissionOption,
      );

      if (!permission.hasAccess) {
        await _logImageDebug(
          message: 'gallery permission denied',
          level: 'warn',
        );
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
          _error = _tr('需要相册访问权限');
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      await _logImageDebug(
        message: 'gallery albums loaded',
        extra: {'albumCount': albums.length},
      );
      if (albums.isEmpty) {
        if (!mounted) return;
        setState(() {
          _albums = [];
          _selectedAlbum = null;
          _albumCounts = {};
          _images = [];
          _isLoading = false;
          _permissionDenied = false;
          _error = _tr('未找到图片');
        });
        return;
      }

      final nonEmptyAlbums = <AssetPathEntity>[];
      final counts = <String, int>{};
      for (final album in albums) {
        final count = await album.assetCountAsync;
        counts[album.id] = count;
        if (count > 0) {
          nonEmptyAlbums.add(album);
        }
      }
      if (nonEmptyAlbums.isEmpty) {
        if (!mounted) return;
        setState(() {
          _albums = [];
          _selectedAlbum = null;
          _albumCounts = counts;
          _images = [];
          _isLoading = false;
          _permissionDenied = false;
          _error = _tr('未找到图片');
        });
        return;
      }

      AssetPathEntity targetAlbum = nonEmptyAlbums.first;
      if (_selectedAlbum != null) {
        for (final album in nonEmptyAlbums) {
          if (album.id == _selectedAlbum!.id) {
            targetAlbum = album;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _albums = nonEmptyAlbums;
        _selectedAlbum = targetAlbum;
        _albumCounts = counts;
        _isLoading = true;
        _permissionDenied = false;
        _error = null;
      });
      await _loadAlbumAssets(targetAlbum);
    } catch (e) {
      await _logImageDebug(
        message: 'gallery load failed',
        level: 'error',
        extra: {'error': '$e'},
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _permissionDenied = false;
        _error = _tr('加载失败: {error}', args: {'error': '$e'});
      });
    }
  }

  Future<void> _loadAlbumAssets(AssetPathEntity album) async {
    try {
      final images = await album.getAssetListPaged(page: 0, size: 180);
      await _logImageDebug(
        message: 'gallery assets paged',
        extra: {
          'albumId': album.id,
          'albumName': album.name,
          'count': images.length,
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedAlbum = album;
        _images = images;
        _isLoading = false;
        _permissionDenied = false;
        _error = null;
      });
    } catch (e) {
      await _logImageDebug(
        message: 'gallery load album failed',
        level: 'error',
        extra: {
          'albumId': album.id,
          'albumName': album.name,
          'error': '$e',
        },
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _tr('加载相册失败: {error}', args: {'error': '$e'});
      });
    }
  }

  Future<Uint8List?> _readOriginalImageBytes(AssetEntity asset) async {
    final bytes = await asset.originBytes;
    if (bytes != null && bytes.isNotEmpty) {
      await _logImageDebug(
        message: 'gallery read originBytes',
        extra: {
          'assetId': asset.id,
          'bytes': bytes.length,
          'fingerprint': _bytesFingerprint(bytes),
        },
      );
      return bytes;
    }

    // Avoid originFile fallback: on some devices/providers this may export a
    // new physical copy and make it appear in gallery.
    final file = await asset.file;
    if (file == null) {
      await _logImageDebug(
        message: 'gallery read failed',
        level: 'warn',
        extra: {'assetId': asset.id},
      );
      return null;
    }
    final fileBytes = await file.readAsBytes();
    await _logImageDebug(
      message: 'gallery read asset.file',
      extra: {
        'assetId': asset.id,
        'path': file.path,
        'bytes': fileBytes.length,
        'fingerprint': _bytesFingerprint(fileBytes),
      },
    );
    return fileBytes;
  }

  Future<void> _selectImage(AssetEntity asset) async {
    final bytes = await _readOriginalImageBytes(asset);
    if (!mounted) return;
    if (bytes == null) {
      await _logImageDebug(
        message: 'gallery select failed (null bytes)',
        level: 'warn',
        extra: {'assetId': asset.id},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('读取原图失败，请重试'))),
      );
      return;
    }
    await _logImageDebug(
      message: 'gallery image selected',
      extra: {
        'assetId': asset.id,
        'bytes': bytes.length,
        'fingerprint': _bytesFingerprint(bytes),
      },
    );
    if (!mounted) return;
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('选择图片')),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _loadImages();
                    },
                    child: Text(_tr('重试')),
                  ),
                  if (_permissionDenied)
                    FilledButton.tonal(
                      onPressed: () async {
                        await PhotoManager.openSetting();
                        if (!mounted) return;
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _loadImages();
                      },
                      child: Text(_tr('打开权限设置')),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return Center(child: Text(_tr('没有图片')));
    }

    return Column(
      children: [
        if (_albums.length > 1) _buildAlbumSelector(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final asset = _images[index];
              return GestureDetector(
                onTap: () => _selectImage(asset),
                child: FutureBuilder<Uint8List?>(
                  future: asset
                      .thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumSelector() {
    final selected = _selectedAlbum;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: selected?.id,
        decoration: InputDecoration(
          labelText: _tr('相册集'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: _albums.map((album) {
          final count = _albumCounts[album.id];
          final label = count == null ? album.name : '${album.name} ($count)';
          return DropdownMenuItem<String>(
            value: album.id,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(growable: false),
        onChanged: (albumId) async {
          if (albumId == null) return;
          AssetPathEntity? target;
          for (final album in _albums) {
            if (album.id == albumId) {
              target = album;
              break;
            }
          }
          if (target == null || target.id == _selectedAlbum?.id) return;
          setState(() {
            _isLoading = true;
          });
          await _loadAlbumAssets(target);
        },
      ),
    );
  }
}
