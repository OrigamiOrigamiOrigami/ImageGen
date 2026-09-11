import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../platform/is_mobile.dart';
import 'history_store.dart';

class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  static const _uuid = Uuid();
  String? _configPath;
  String? _imagesDir;
  String? _defaultImagesDir;
  String? _logPath;
  String? _supportDir;
  bool _saveToGallery = true;

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _supportDir = support.path;
    _configPath = p.join(support.path, 'config.json');
    _logPath = p.join(support.path, 'app.log');
    _defaultImagesDir = p.join(support.path, 'images');
    _imagesDir = _defaultImagesDir;
    HistoryStore.instance.init(support.path);

    await _ensureImagesDir(_imagesDir!);
  }

  Future<void> _ensureImagesDir(String dir) async {
    final d = Directory(dir);
    if (!d.existsSync()) await d.create(recursive: true);
  }

  Future<AppConfig> load() async {
    final file = File(_configPath!);
    if (!file.existsSync()) {
      final defaultConfig = _defaultConfig();
      await save(defaultConfig);
      return defaultConfig;
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final config = AppConfig.fromJson(json);

      if (config.imagesDir != null && config.imagesDir!.isNotEmpty) {
        _imagesDir = config.imagesDir;
        await _ensureImagesDir(_imagesDir!);
      }

      _saveToGallery = config.saveToGallery ?? true;

      // 旧版：history 嵌在 config.json → 拆到按周文件后清掉主配置里的 history
      final embedded = config.history;
      if (embedded.isNotEmpty) {
        await HistoryStore.instance.migrateFromEmbedded(embedded);
        config.history = [];
        await _saveSettings(config);
      }

      config.history = await HistoryStore.instance.load(
        maxItems: config.maxHistoryItems ?? HistoryStore.defaultMaxItems,
      );
      return config;
    } catch (_) {
      return _defaultConfig();
    }
  }

  /// 只写设置，不碰历史周文件。
  Future<void> saveSettings(AppConfig config) async {
    if (config.imagesDir != null && config.imagesDir!.isNotEmpty) {
      _imagesDir = config.imagesDir;
      await _ensureImagesDir(_imagesDir!);
    }
    await _saveSettings(config);
  }

  Future<void> save(AppConfig config) async {
    await saveSettings(config);
    await HistoryStore.instance.save(config.history);
  }

  /// 仅写设置（不含历史），保持 config.json 轻量。
  Future<void> _saveSettings(AppConfig config) async {
    await File(_configPath!).writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toSettingsJson()),
    );
  }

  AppConfig _defaultConfig() {
    final id = _uuid.v4();
    return AppConfig(
      profiles: [
        Profile(
          id: id,
          name: 'grsai',
          apiFormat: ApiFormat.grsai,
          baseUrl: 'https://grsai.dakka.com.cn',
          apiKey: '',
        ),
      ],
      activeProfileId: id,
      history: [],
      themeId: ThemeId.darkPurple,
      maxConcurrent: 3,
      maxHistoryItems: HistoryStore.defaultMaxItems,
      saveToGallery: true,
    );
  }

  String get imagesDir => _imagesDir!;
  String get defaultImagesDir => _defaultImagesDir!;
  bool get isUsingDefaultImagesDir => _imagesDir == _defaultImagesDir;
  bool get saveToGalleryEnabled => isMobile && _saveToGallery;
  String get configPath => _configPath!;
  String get logPath => _logPath!;
  String get historyDir => HistoryStore.instance.directory;
  String get supportDir => _supportDir!;

  void setSaveToGallery(bool enabled) => _saveToGallery = enabled;

  Future<void> resetImagesDirToDefault() async {
    _imagesDir = _defaultImagesDir!;
    await _ensureImagesDir(_imagesDir!);
  }

  void log(String level, String message) {
    final line =
        '[${DateTime.now().toIso8601String()}] [$level] $message\n';
    // ignore: avoid_print
    print(line.trim());
    try {
      File(_logPath!).writeAsStringSync(line, mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> setImagesDir(String dir) async {
    _imagesDir = dir;
    await _ensureImagesDir(dir);
  }

  Future<String> readLogTail({int maxLines = 200}) async {
    final file = File(_logPath!);
    if (!file.existsSync()) return '（暂无日志）';
    try {
      final lines = await file.readAsLines();
      if (lines.isEmpty) return '（暂无日志）';
      final start = lines.length > maxLines ? lines.length - maxLines : 0;
      return lines.sublist(start).join('\n');
    } catch (e) {
      return '读取日志失败: $e';
    }
  }

  Future<int> countSavedImages() async {
    final dir = Directory(_imagesDir!);
    if (!dir.existsSync()) return 0;
    var n = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp') {
        n++;
      }
    }
    return n;
  }
}
