import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'config_service.dart';
import 'thumbnail_service.dart';
import '../platform/is_mobile.dart';

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  static final _numericName = RegExp(r'^(\d+)\.(png|jpg|jpeg|webp)$',
      caseSensitive: false);

  Future<void> _saveLock = Future.value();

  /// 下一张图的序号文件名：`1.png`、`2.png`…（取目录内已有数字名最大值 + 1）。
  Future<String> nextSequentialFilename({String ext = 'png'}) async {
    final dir = Directory(ConfigService.instance.imagesDir);
    var next = 1;
    if (dir.existsSync()) {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final m = _numericName.firstMatch(p.basename(entity.path));
        if (m == null) continue;
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n >= next) next = n + 1;
      }
    }
    var name = '$next.$ext';
    // 防撞：若同名已存在则继续递增
    while (File(p.join(dir.path, name)).existsSync()) {
      next++;
      name = '$next.$ext';
    }
    return name;
  }

  /// 保存到应用目录；手机端在设置开启时同步写入系统相册。
  Future<({String path, bool savedToGallery})> saveImage({
    required String base64,
    String? filename,
  }) {
    // 串行化，避免并发生成时抢到同一序号
    final previous = _saveLock;
    late Future<({String path, bool savedToGallery})> result;
    result = previous.then((_) => _saveImageUnlocked(base64, filename));
    _saveLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<({String path, bool savedToGallery})> _saveImageUnlocked(
    String base64,
    String? filename,
  ) async {
    final name = filename ?? await nextSequentialFilename();
    final filePath = p.join(ConfigService.instance.imagesDir, name);
    final bytes = base64Decode(base64);
    await File(filePath).writeAsBytes(bytes);
    ConfigService.instance.log('INFO', 'Image saved: $filePath');
    // 后台预热网格缩略图
    ThumbnailService.instance.warmUp(filePath);

    var savedToGallery = false;
    if (isMobile && ConfigService.instance.saveToGalleryEnabled) {
      savedToGallery = await _saveToGallery(bytes, name);
    }

    return (path: filePath, savedToGallery: savedToGallery);
  }

  /// 将已有图片写入相册（详情页手动保存等）。
  Future<bool> saveFileToGallery(String filePath) async {
    if (!isMobile) return false;
    try {
      final bytes = await File(filePath).readAsBytes();
      final name = p.basename(filePath);
      return _saveToGallery(bytes, name);
    } catch (e) {
      ConfigService.instance.log('WARN', 'Gallery save file failed: $e');
      return false;
    }
  }

  Future<bool> _saveToGallery(Uint8List bytes, String filename) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          ConfigService.instance.log('WARN', 'Gallery access denied');
          return false;
        }
      }
      final name = p.basename(filename);
      await Gal.putImageBytes(bytes, name: name, album: 'ImageGen');
      ConfigService.instance.log('INFO', 'Image saved to gallery: $name');
      return true;
    } catch (e) {
      ConfigService.instance.log('WARN', 'Gallery save failed: $e');
      return false;
    }
  }

  String formatFileSizeLabel(String filePath) {
    try {
      final len = File(filePath).lengthSync();
      if (len < 1024) return '$len B';
      if (len < 1024 * 1024) {
        return '${(len / 1024).toStringAsFixed(1)} KB';
      }
      return '${(len / (1024 * 1024)).toStringAsFixed(2)} MB';
    } catch (_) {
      return '—';
    }
  }

  Future<Uint8List?> readImageBytes(String filePath) async {
    try {
      return await File(filePath).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) await file.delete();
      await ThumbnailService.instance.deleteFor(filePath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> copyToClipboard(String filePath) async {
    try {
      if (Platform.isWindows) {
        final escaped = filePath.replaceAll("'", "''");
        final result = await Process.run(
          'powershell',
          ['-NoProfile', '-Command', "Set-Clipboard -Path '$escaped'"],
        );
        return result.exitCode == 0;
      }
      final bytes = await File(filePath).readAsBytes();
      // 其他平台：复制文件路径作为回退
      await Clipboard.setData(ClipboardData(text: filePath));
      final _ = bytes;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> revealInFolder(String filePath) async {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', filePath.replaceAll('/', '\\')]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [p.dirname(filePath)]);
    }
  }

  Future<void> openPath(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      await revealInFolder(path);
    }
  }
}
