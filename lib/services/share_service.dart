import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 分享服务
class ShareService {
  /// 分享图片和文本
  static Future<bool> shareImage({
    required Uint8List imageBytes,
    String? text,
    String? subject,
    String? fileName,
    String? signature,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final actualFileName =
          fileName ?? 'nano_banana_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${tempDir.path}/$actualFileName';

      var finalBytes = imageBytes;

      if (signature != null && signature.isNotEmpty) {
        finalBytes = await _addSignatureToImage(imageBytes, signature);
      }

      final file = File(filePath);
      await file.writeAsBytes(finalBytes);

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        text: text,
        subject: subject,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 添加签名水印到图片
  static Future<Uint8List> _addSignatureToImage(
    Uint8List originalBytes,
    String signature,
  ) async {
    try {
      final original = img.decodeImage(originalBytes);
      if (original == null) return originalBytes;

      // 创建一个新的图片，底部留出签名空间
      final height = original.height + 60;
      final result = img.Image(width: original.width, height: height);

      // 复制原图
      img.compositeImage(result, original, dstX: 0, dstY: 0);

      // 添加半透明黑色底栏
      for (var y = original.height; y < height; y++) {
        for (var x = 0; x < original.width; x++) {
          result.setPixelRgba(x, y, 0, 0, 0, 180);
        }
      }

      // 添加签名文字（使用简单的像素绘制）
      const startX = 20;
      final startY = original.height + 30;

      // 简化的文字渲染 - 实际项目中可以使用更复杂的字体渲染
      // 这里使用简单的方式标记签名位置
      for (var i = 0; i < signature.length && i < 30; i++) {
        final x = startX + i * 8;
        if (x < original.width - 20) {
          // 绘制简单的点表示文字位置
          for (var dy = -5; dy < 5; dy++) {
            for (var dx = -2; dx < 2; dx++) {
              final px = x + dx;
              final py = startY + dy;
              if (px >= 0 && px < original.width && py >= original.height && py < height) {
                result.setPixelRgba(px, py, 255, 255, 255, 255);
              }
            }
          }
        }
      }

      return Uint8List.fromList(img.encodePng(result));
    } catch (e) {
      // 如果处理失败，返回原图
      return originalBytes;
    }
  }

  /// 分享纯文本
  static Future<void> shareText({
    required String text,
    String? subject,
  }) async {
    await Share.share(text, subject: subject);
  }

  /// 清理临时文件
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      final now = DateTime.now();

      for (final file in files) {
        if (file is File && file.path.contains('nano_banana_')) {
          final stat = file.statSync();
          final age = now.difference(stat.modified);
          // 删除超过24小时的临时文件
          if (age.inHours > 24) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // 清理失败不影响主功能
    }
  }
}

/// 分享选项数据类
class ShareOptions {
  final bool includePrompt;
  final bool includeModel;
  final bool includeTimestamp;
  final bool addWatermark;
  final String? customText;

  const ShareOptions({
    this.includePrompt = true,
    this.includeModel = true,
    this.includeTimestamp = false,
    this.addWatermark = false,
    this.customText,
  });

  String buildShareText({
    required String prompt,
    required String model,
    DateTime? timestamp,
    String? signature,
  }) {
    final parts = <String>[];

    if (customText != null && customText!.isNotEmpty) {
      parts.add(customText!);
    }

    if (includePrompt) {
      parts.add('🎨 提示词: $prompt');
    }

    if (includeModel) {
      parts.add('🤖 模型: $model');
    }

    if (includeTimestamp && timestamp != null) {
      parts.add('📅 ${timestamp.toLocal()}');
    }

    if (signature != null && signature.isNotEmpty) {
      parts.add('✨ $signature');
    }

    if (parts.isEmpty) {
      return '来自 Nano Banana';
    }

    return parts.join('\n');
  }
}
