import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../services/history_store.dart';
import '../services/image_service.dart';
import '../services/task_queue.dart';
import '../theme/app_typography.dart';
import '../theme/ui_scale.dart';
import '../themes/app_themes.dart';
import '../widgets/image_grid.dart';
import '../widgets/image_lightbox.dart';
import '../widgets/profile_switcher.dart';
import '../widgets/prompt_bar.dart';
import '../widgets/settings_modal.dart';
import '../widgets/system_settings.dart';
import '../platform/is_desktop.dart';
import '../platform/is_mobile.dart';
import '../platform/window_init.dart';
import '../widgets/title_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _uuid = Uuid();

  AppConfig? _config;
  AppTheme _theme = getTheme(ThemeId.darkPurple);
  bool _showSettings = false;
  bool _showSystem = false;
  int? _lightboxIndex;
  String? _error;
  late TaskQueue _taskQueue;
  List<GenTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _taskQueue = TaskQueue(
      maxConcurrent: 3,
      onUpdate: (tasks) => setState(() => _tasks = tasks),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final cfg = await ConfigService.instance.load();
    final theme = getTheme(cfg.themeId ?? ThemeId.darkPurple);
    if (isDesktop) {
      await syncWindowBackground(Color(theme.bg));
    }
    setState(() {
      _config = cfg;
      _theme = theme;
      _taskQueue.maxConcurrent = cfg.maxConcurrent ?? 3;
    });
  }

  Future<void> _persist(AppConfig next, {bool history = false}) async {
    setState(() => _config = next);
    if (history) {
      await ConfigService.instance.save(next);
    } else {
      await ConfigService.instance.saveSettings(next);
    }
  }

  void _onThemeChange(ThemeId id) {
    final theme = getTheme(id);
    setState(() => _theme = theme);
    if (isDesktop) {
      syncWindowBackground(Color(theme.bg));
    }
    if (_config != null) {
      _persist(_config!..themeId = id);
    }
  }

  Future<void> _handleGenerate(
    String prompt,
    String model,
    String size,
    String imageSize,
    List<String> refImages,
  ) async {
    final config = _config;
    if (config == null) return;

    final profileIndex =
        config.profiles.indexWhere((p) => p.id == config.activeProfileId);
    final profile =
        profileIndex >= 0 ? config.profiles[profileIndex] : null;
    if (profile == null) {
      setState(() => _error = '请先选择一个 API 配置');
      return;
    }

    setState(() => _error = null);
    if (config.lastModel != model) {
      await _persist(config..lastModel = model);
    }

    final taskId = _uuid.v4();
    _taskQueue.addTask(taskId, prompt, (onProgress) async {
      final results = await ApiService.instance.generateImages(
        profile,
        GenerateParams(
          prompt: prompt,
          model: model,
          size: size,
          imageSize: imageSize,
          n: 1,
          urls: refImages.isNotEmpty ? refImages : null,
        ),
        onProgress: onProgress,
      );

      final newItems = <HistoryItem>[];
      var savedToGallery = false;
      for (final result in results) {
        final saved = await ImageService.instance.saveImage(
          base64: result.base64,
        );
        savedToGallery = savedToGallery || saved.savedToGallery;
        final imagePath = saved.path;
        newItems.add(HistoryItem(
          id: _uuid.v4(),
          profileId: profile.id,
          profileName: profile.name,
          prompt: prompt,
          imagePath: imagePath,
          createdAt: DateTime.now().toIso8601String(),
          width: result.width,
          height: result.height,
          model: model,
          size: size,
          imageSize: imageSize,
          refImageCount: refImages.isNotEmpty ? refImages.length : null,
        ));
      }

      final latest = await ConfigService.instance.load();
      var list = [...newItems, ...latest.history];
      final max =
          latest.maxHistoryItems ?? HistoryStore.defaultMaxItems;
      if (list.length > max) {
        HistoryStore.instance.dropFromMemory(
          list.sublist(max).map((e) => e.id),
        );
        list = list.sublist(0, max);
      }
      await _persist(latest..history = list, history: true);

      if (!mounted || !isMobile) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      if (savedToGallery) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已保存到相册（ImageGen）'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (ConfigService.instance.saveToGalleryEnabled) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('图片已生成，但写入相册失败，请检查相册权限'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _openSystemSettings(BuildContext context) {
    final config = _config;
    if (config == null) return;
    final uiPreset = isMobile
        ? UiScalePreset.auto
        : UiScalePreset.fromStorage(config.uiScale);

    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => AppScaleScope(
            preset: uiPreset,
            child: SystemSettings(
              fullPage: true,
              theme: _theme,
              currentTheme: config.themeId ?? ThemeId.darkPurple,
              onThemeChange: _onThemeChange,
              onClose: () => Navigator.pop(ctx),
              onImagesDirChange: (dir) async {
                await ConfigService.instance.setImagesDir(dir);
                final c = _config;
                if (c != null) await _persist(c..imagesDir = dir);
              },
              maxConcurrent: config.maxConcurrent ?? 3,
              onMaxConcurrentChange: (n) {
                _taskQueue.maxConcurrent = n;
                final c = _config;
                if (c != null) _persist(c..maxConcurrent = n);
              },
              maxHistoryItems:
                  config.maxHistoryItems ?? HistoryStore.defaultMaxItems,
              onMaxHistoryItemsChange: (n) async {
                final c = _config;
                if (c == null) return;
                await _persist(c..maxHistoryItems = n);
                final reloaded = await ConfigService.instance.load();
                if (!mounted) return;
                setState(() => _config = reloaded);
              },
              uiScale: uiPreset,
              onUiScaleChange: (preset) {
                final c = _config;
                if (c != null) _persist(c..uiScale = preset.storage);
              },
              saveToGallery: config.saveToGallery ?? true,
              onSaveToGalleryChange: (v) {
                ConfigService.instance.setSaveToGallery(v);
                final c = _config;
                if (c != null) _persist(c..saveToGallery = v);
              },
              onResetDir: () async {
                await ConfigService.instance.resetImagesDirToDefault();
                final c = _config;
                if (c != null) {
                  await _persist(
                    c..imagesDir = ConfigService.instance.imagesDir,
                  );
                }
              },
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _showSystem = true);
  }

  void _openApiSettings(BuildContext context) {
    final config = _config;
    if (config == null) return;

    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => SettingsModal(
            fullPage: true,
            theme: _theme,
            profiles: config.profiles,
            onSave: (profiles) {
              final activeStillExists =
                  profiles.any((p) => p.id == config.activeProfileId);
              _persist(config
                ..profiles = profiles
                ..activeProfileId = activeStillExists
                    ? config.activeProfileId
                    : (profiles.isNotEmpty ? profiles.first.id : null));
            },
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      );
      return;
    }
    setState(() => _showSettings = true);
  }

  Future<void> _handleDeleteHistory(String id, String imagePath) async {
    await ImageService.instance.deleteImage(imagePath);
    final latest = await ConfigService.instance.load();
    await _persist(
      latest..history = latest.history.where((h) => h.id != id).toList(),
      history: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return Material(
        color: c(_theme.bg),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final config = _config!;

    final uiPreset = isMobile
        ? UiScalePreset.auto
        : UiScalePreset.fromStorage(config.uiScale);

    return AppScaleScope(
      preset: uiPreset,
      child: Theme(
        data: AppTypography.mergeInto(
          ThemeData(
            brightness: _theme.dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: c(_theme.bg),
            useMaterial3: true,
          ),
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: c(_theme.bg),
          body: Stack(
          children: [
            Column(
              children: [
                TitleBar(
                  theme: _theme,
                  onSettings: () => _openSystemSettings(context),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isMobile ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: c(_theme.surface),
                    border: Border(bottom: BorderSide(color: c(_theme.border))),
                  ),
                  child: Row(
                    children: [
                      ProfileSwitcher(
                        theme: _theme,
                        profiles: config.profiles,
                        activeId: config.activeProfileId,
                        onSwitch: (id) =>
                            _persist(config..activeProfileId = id),
                        onManage: () => _openApiSettings(context),
                      ),
                      if (_error != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.6),
                                  onPressed: () => setState(() => _error = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ImageGrid(
                    key: const ValueKey('image-grid'),
                    theme: _theme,
                    history: config.history,
                    tasks: _tasks,
                    onDelete: _handleDeleteHistory,
                    onPreview: (i) => setState(() => _lightboxIndex = i),
                  ),
                ),
                PromptBar(
                  theme: _theme,
                  onGenerate: _handleGenerate,
                  hasRunning: _taskQueue.hasRunning,
                  profiles: config.profiles,
                  activeProfileId: config.activeProfileId,
                  onSwitchProfile: (id) =>
                      _persist(config..activeProfileId = id),
                  initialModel: config.lastModel,
                ),
              ],
            ),
            if (!isMobile && _showSettings)
              Positioned.fill(
                child: SettingsModal(
                  theme: _theme,
                  profiles: config.profiles,
                  onSave: (profiles) {
                    final activeStillExists =
                        profiles.any((p) => p.id == config.activeProfileId);
                    _persist(config
                      ..profiles = profiles
                      ..activeProfileId = activeStillExists
                          ? config.activeProfileId
                          : (profiles.isNotEmpty ? profiles.first.id : null));
                  },
                  onClose: () => setState(() => _showSettings = false),
                ),
              ),
            if (!isMobile && _showSystem)
              Positioned.fill(
                child: SystemSettings(
                  theme: _theme,
                  currentTheme: config.themeId ?? ThemeId.darkPurple,
                  onThemeChange: _onThemeChange,
                  onClose: () => setState(() => _showSystem = false),
                  onImagesDirChange: (dir) async {
                    await ConfigService.instance.setImagesDir(dir);
                    await _persist(config..imagesDir = dir);
                  },
                  maxConcurrent: config.maxConcurrent ?? 3,
                  onMaxConcurrentChange: (n) {
                    _taskQueue.maxConcurrent = n;
                    _persist(config..maxConcurrent = n);
                  },
                  maxHistoryItems:
                      config.maxHistoryItems ?? HistoryStore.defaultMaxItems,
                  onMaxHistoryItemsChange: (n) async {
                    await _persist(config..maxHistoryItems = n);
                    final reloaded = await ConfigService.instance.load();
                    if (!mounted) return;
                    setState(() => _config = reloaded);
                  },
                  uiScale: uiPreset,
                  onUiScaleChange: (preset) =>
                      _persist(config..uiScale = preset.storage),
                  saveToGallery: config.saveToGallery ?? true,
                  onSaveToGalleryChange: (v) {
                    ConfigService.instance.setSaveToGallery(v);
                    _persist(config..saveToGallery = v);
                  },
                  onResetDir: () async {
                    await ConfigService.instance.resetImagesDirToDefault();
                    await _persist(
                      config..imagesDir = ConfigService.instance.imagesDir,
                    );
                    setState(() {});
                  },
                ),
              ),
            if (_lightboxIndex != null)
              Positioned.fill(
                child: ImageLightbox(
                  theme: _theme,
                  history: config.history,
                  index: _lightboxIndex!,
                  onChange: (i) => setState(() => _lightboxIndex = i),
                  onClose: () => setState(() => _lightboxIndex = null),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}
