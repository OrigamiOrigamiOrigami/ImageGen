enum ApiFormat { grsai, openai, gemini }

enum ThemeId {
  darkPurple('dark-purple'),
  darkCyan('dark-cyan'),
  darkRose('dark-rose'),
  light('light'),
  lightWarm('light-warm');

  const ThemeId(this.value);
  final String value;

  static ThemeId fromString(String? v) {
    return ThemeId.values.firstWhere(
      (e) => e.value == v,
      orElse: () => ThemeId.darkPurple,
    );
  }
}

class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.dark,
    required this.bg,
    required this.surface,
    required this.border,
    required this.muted,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentGlow,
    required this.shadow,
  });

  final ThemeId id;
  final String name;
  final bool dark;
  final int bg;
  final int surface;
  final int border;
  final int muted;
  final int text;
  final int textMuted;
  final int accent;
  final int accentGlow;
  final String shadow;
}

class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.apiFormat,
    required this.baseUrl,
    required this.apiKey,
    this.defaultModel,
  });

  final String id;
  String name;
  ApiFormat apiFormat;
  String baseUrl;
  String apiKey;
  String? defaultModel;

  factory Profile.fromJson(Map<String, dynamic> json) {
    var fmt = json['apiFormat'] as String? ?? 'grsai';
    if (fmt == 'custom' || fmt == 'nano-banana') fmt = 'grsai';
    ApiFormat apiFormat;
    switch (fmt) {
      case 'openai':
        apiFormat = ApiFormat.openai;
        break;
      case 'gemini':
        apiFormat = ApiFormat.gemini;
        break;
      default:
        apiFormat = ApiFormat.grsai;
    }
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      apiFormat: apiFormat,
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      defaultModel: json['defaultModel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apiFormat': apiFormat.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        if (defaultModel != null && defaultModel!.isNotEmpty)
          'defaultModel': defaultModel,
      };
}

class HistoryItem {
  HistoryItem({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.prompt,
    required this.imagePath,
    required this.createdAt,
    required this.width,
    required this.height,
    this.model,
    this.size,
    this.imageSize,
    this.refImageCount,
  });

  final String id;
  final String profileId;
  final String profileName;
  final String prompt;
  final String imagePath;
  final String createdAt;
  final int width;
  final int height;
  final String? model;
  final String? size;
  final String? imageSize;
  final int? refImageCount;

  /// 生成参数摘要（有记录才显示对应项）
  String get generationMetaLine {
    final parts = <String>[];
    if (profileName.isNotEmpty) parts.add(profileName);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    if (size != null && size!.isNotEmpty) parts.add('比例 $size');
    if (imageSize != null && imageSize!.isNotEmpty) parts.add(imageSize!);
    if (refImageCount != null && refImageCount! > 0) {
      parts.add('参考图×$refImageCount');
    }
    if (width > 0 && height > 0) parts.add('$width×$height');
    return parts.join(' · ');
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        profileName: json['profileName'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        imagePath: json['imagePath'] as String,
        createdAt: json['createdAt'] as String,
        width: (json['width'] as num?)?.toInt() ?? 1024,
        height: (json['height'] as num?)?.toInt() ?? 1024,
        model: json['model'] as String?,
        size: json['size'] as String?,
        imageSize: json['imageSize'] as String?,
        refImageCount: (json['refImageCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'profileName': profileName,
        'prompt': prompt,
        'imagePath': imagePath,
        'createdAt': createdAt,
        'width': width,
        'height': height,
        if (model != null && model!.isNotEmpty) 'model': model,
        if (size != null && size!.isNotEmpty) 'size': size,
        if (imageSize != null && imageSize!.isNotEmpty) 'imageSize': imageSize,
        if (refImageCount != null && refImageCount! > 0)
          'refImageCount': refImageCount,
      };
}

class AppConfig {
  AppConfig({
    required this.profiles,
    required this.activeProfileId,
    required this.history,
    this.themeId,
    this.lastModel,
    this.imagesDir,
    this.saveToGallery,
    this.maxConcurrent,
    this.maxHistoryItems,
    this.uiScale,
  });

  List<Profile> profiles;
  String? activeProfileId;
  List<HistoryItem> history;
  ThemeId? themeId;
  String? lastModel;
  String? imagesDir;
  /// 手机端：生成后是否同步写入系统相册（默认 true）
  bool? saveToGallery;
  int? maxConcurrent;
  /// 应用内历史列表最多展示条数（默认 200）
  int? maxHistoryItems;
  /// 界面缩放：auto / 100 / 115 / 125 / 150
  String? uiScale;

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        profiles: (json['profiles'] as List<dynamic>?)
                ?.map((e) => Profile.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        activeProfileId: json['activeProfileId'] as String?,
        history: (json['history'] as List<dynamic>?)
                ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        themeId: ThemeId.fromString(json['themeId'] as String?),
        lastModel: json['lastModel'] as String?,
        imagesDir: json['imagesDir'] as String?,
        saveToGallery: json['saveToGallery'] as bool?,
        maxConcurrent: (json['maxConcurrent'] as num?)?.toInt(),
        maxHistoryItems: (json['maxHistoryItems'] as num?)?.toInt(),
        uiScale: json['uiScale'] as String?,
      );

  Map<String, dynamic> toJson() => {
        ...toSettingsJson(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  /// 写入 config.json：不含历史（历史按周拆到 history/）。
  Map<String, dynamic> toSettingsJson() => {
        'profiles': profiles.map((e) => e.toJson()).toList(),
        'activeProfileId': activeProfileId,
        if (themeId != null) 'themeId': themeId!.value,
        if (lastModel != null) 'lastModel': lastModel,
        if (imagesDir != null) 'imagesDir': imagesDir,
        if (saveToGallery != null) 'saveToGallery': saveToGallery,
        if (maxConcurrent != null) 'maxConcurrent': maxConcurrent,
        if (maxHistoryItems != null) 'maxHistoryItems': maxHistoryItems,
        if (uiScale != null && uiScale!.isNotEmpty) 'uiScale': uiScale,
      };
}

class GenerateParams {
  GenerateParams({
    required this.prompt,
    required this.model,
    this.size,
    this.imageSize,
    this.n,
    this.urls,
  });

  final String prompt;
  final String model;
  final String? size;
  final String? imageSize;
  final int? n;
  final List<String>? urls;
}

class GenerateResult {
  GenerateResult({
    required this.base64,
    required this.width,
    required this.height,
  });

  final String base64;
  final int width;
  final int height;
}

class GenTask {
  GenTask({
    required this.id,
    required this.prompt,
    this.progress = -1,
    this.status = TaskStatus.queued,
    this.error,
  });

  final String id;
  final String prompt;
  int progress;
  TaskStatus status;
  String? error;
}

enum TaskStatus { queued, running, done, error }
