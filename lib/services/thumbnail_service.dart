import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import 'config_service.dart';

/// 网格缩略图：磁盘缓存 + 降采样解码，避免每次打开读完整图。
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  static const int thumbMaxSide = 512;
  final Map<String, Future<String?>> _inflight = {};

  String _thumbDir() => p.join(ConfigService.instance.imagesDir, '.thumbs');

  String thumbPathFor(String imagePath) {
    final base = p.basenameWithoutExtension(imagePath);
    // 用原文件修改时间作简单失效依据
    var stamp = '0';
    try {
      stamp =
          File(imagePath).lastModifiedSync().millisecondsSinceEpoch.toString();
    } catch (_) {}
    return p.join(_thumbDir(), '${base}_$stamp.png');
  }

  Future<void> _ensureThumbDir() async {
    final dir = Directory(_thumbDir());
    if (!dir.existsSync()) await dir.create(recursive: true);
  }

  /// 返回缩略图路径；失败时返回 null（调用方可回退原图）。
  Future<String?> getThumbnailPath(String imagePath) {
    return _inflight.putIfAbsent(imagePath, () async {
      try {
        return await _resolve(imagePath);
      } finally {
        _inflight.remove(imagePath);
      }
    });
  }

  Future<String?> _resolve(String imagePath) async {
    final src = File(imagePath);
    if (!src.existsSync()) return null;

    await _ensureThumbDir();
    final outPath = thumbPathFor(imagePath);
    final out = File(outPath);
    if (out.existsSync()) return outPath;

    final bytes = await src.readAsBytes();
    final thumbBytes = await _downsample(bytes, thumbMaxSide);
    if (thumbBytes == null) return null;

    await out.writeAsBytes(thumbBytes, flush: true);
    _cleanupStaleThumbs(p.basenameWithoutExtension(imagePath), outPath);
    return outPath;
  }

  /// 生成完成后预热缩略图（不阻塞 UI）。
  void warmUp(String imagePath) {
    getThumbnailPath(imagePath);
  }

  Future<void> deleteFor(String imagePath) async {
    try {
      final dir = Directory(_thumbDir());
      if (!dir.existsSync()) return;
      final base = p.basenameWithoutExtension(imagePath);
      await for (final entity in dir.list()) {
        if (entity is File && p.basename(entity.path).startsWith('${base}_')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  void _cleanupStaleThumbs(String base, String keepPath) {
    try {
      final dir = Directory(_thumbDir());
      if (!dir.existsSync()) return;
      for (final entity in dir.listSync()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('${base}_') &&
            entity.path != keepPath) {
          entity.deleteSync();
        }
      }
    } catch (_) {}
  }

  static Future<Uint8List?> _downsample(Uint8List bytes, int maxSide) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      // 只设一边，保持宽高比
      codec = await ui.instantiateImageCodec(bytes, targetWidth: maxSide);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return data.buffer.asUint8List();
    } catch (e) {
      ConfigService.instance.log('WARN', 'Thumbnail encode failed: $e');
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
