import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../platform/is_mobile.dart';
import '../services/config_service.dart';
import '../services/history_store.dart';
import '../services/image_service.dart';
import '../theme/app_typography.dart';
import '../theme/ui_scale.dart';
import '../themes/app_themes.dart';

class SystemSettings extends StatefulWidget {
  const SystemSettings({
    super.key,
    required this.theme,
    required this.currentTheme,
    required this.onThemeChange,
    required this.onClose,
    required this.onImagesDirChange,
    required this.maxConcurrent,
    required this.onMaxConcurrentChange,
    required this.maxHistoryItems,
    required this.onMaxHistoryItemsChange,
    required this.uiScale,
    required this.onUiScaleChange,
    required this.saveToGallery,
    required this.onSaveToGalleryChange,
    required this.onResetDir,
    this.fullPage = false,
  });

  final bool fullPage;
  final bool saveToGallery;
  final ValueChanged<bool> onSaveToGalleryChange;
  final VoidCallback onResetDir;
  final AppTheme theme;
  final ThemeId currentTheme;
  final ValueChanged<ThemeId> onThemeChange;
  final VoidCallback onClose;
  final ValueChanged<String> onImagesDirChange;
  final int maxConcurrent;
  final ValueChanged<int> onMaxConcurrentChange;
  final int maxHistoryItems;
  final ValueChanged<int> onMaxHistoryItemsChange;
  final UiScalePreset uiScale;
  final ValueChanged<UiScalePreset> onUiScaleChange;

  @override
  State<SystemSettings> createState() => _SystemSettingsState();
}

class _SystemSettingsState extends State<SystemSettings> {
  late ThemeId _themeId;
  late int _maxConcurrent;
  late int _maxHistoryItems;

  @override
  void initState() {
    super.initState();
    _themeId = widget.currentTheme;
    _maxConcurrent = widget.maxConcurrent;
    _maxHistoryItems = widget.maxHistoryItems;
  }

  @override
  void didUpdateWidget(SystemSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTheme != oldWidget.currentTheme) {
      _themeId = widget.currentTheme;
    }
    if (widget.maxConcurrent != oldWidget.maxConcurrent) {
      _maxConcurrent = widget.maxConcurrent;
    }
    if (widget.maxHistoryItems != oldWidget.maxHistoryItems) {
      _maxHistoryItems = widget.maxHistoryItems;
    }
  }

  AppTheme get _displayTheme => getTheme(_themeId);

  void _selectTheme(ThemeId id) {
    if (_themeId == id) return;
    setState(() => _themeId = id);
    widget.onThemeChange(id);
  }

  void _selectMaxConcurrent(int n) {
    if (_maxConcurrent == n) return;
    setState(() => _maxConcurrent = n);
    widget.onMaxConcurrentChange(n);
  }

  void _selectMaxHistoryItems(int n) {
    if (_maxHistoryItems == n) return;
    setState(() => _maxHistoryItems = n);
    widget.onMaxHistoryItemsChange(n);
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final activeTheme = _displayTheme;
    final scale = context.appScale;
    final pad = widget.fullPage ? 16.0 : scale.dim(24);
    final paths = (
      config: ConfigService.instance.configPath,
      history: ConfigService.instance.historyDir,
      images: ConfigService.instance.imagesDir,
      log: ConfigService.instance.logPath,
    );

    final content = _buildScrollContent(
      context,
      activeTheme: activeTheme,
      scale: scale,
      pad: pad,
      paths: paths,
    );

    if (widget.fullPage) {
      return Scaffold(
        backgroundColor: c(_displayTheme.bg),
        appBar: AppBar(
          backgroundColor: c(_displayTheme.surface),
          foregroundColor: c(_displayTheme.text),
          elevation: 0,
          title: Text(
            '系统设置',
            style: AppTypography.app(
              color: c(_displayTheme.text),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c(_displayTheme.textMuted)),
            onPressed: widget.onClose,
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: GestureDetector(
        onTap: widget.onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.all(scale.dim(20)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: scale.dim(520),
                  maxHeight: maxH,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: c(_displayTheme.surface),
                    border: Border.all(color: c(_displayTheme.border)),
                    borderRadius: BorderRadius.circular(scale.dim(16)),
                    boxShadow: [
                      BoxShadow(
                        color: c(activeTheme.accent).withValues(alpha: 0.15),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: pad,
                          vertical: scale.dim(16),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '系统设置',
                              style: AppTypography.app(
                                color: c(_displayTheme.text),
                                fontWeight: FontWeight.w600,
                                fontSize: scale.sp(16),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.close, color: c(_displayTheme.textMuted)),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: c(_displayTheme.border)),
                      Flexible(child: content),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollContent(
    BuildContext context, {
    required AppTheme activeTheme,
    required AppScale scale,
    required double pad,
    required ({String config, String history, String images, String log}) paths,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                        _sectionTitle('主题'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: appThemes.map((t) {
                            final selected = _themeId == t.id;
                            return GestureDetector(
                              onTap: () => _selectTheme(t.id),
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: selected
                                            ? c(t.accentGlow)
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: c(t.accent)
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Stack(
                                        children: [
                                          Container(color: c(t.bg)),
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            height: 12,
                                            child: ColoredBox(color: c(t.surface)),
                                          ),
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: c(t.accentGlow),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Center(
                                              child: Icon(
                                                Icons.check,
                                                size: 14,
                                                color: c(t.accentGlow),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                    Text(
                                      t.name,
                                      style: AppTypography.app(
                                        fontSize: 11,
                                        color: c(_displayTheme.textMuted),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(height: 24),
                          _sectionTitle('界面缩放'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: UiScalePreset.values.map((preset) {
                              final selected = widget.uiScale == preset;
                              return InkWell(
                                onTap: () => widget.onUiScaleChange(preset),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? c(activeTheme.accent)
                                          : c(activeTheme.border),
                                    ),
                                    color: selected
                                        ? c(activeTheme.accent)
                                            .withValues(alpha: 0.15)
                                        : null,
                                  ),
                                  child: Text(
                                    preset.label,
                                    style: AppTypography.app(
                                      fontSize: 12,
                                      color: selected
                                          ? c(activeTheme.accentGlow)
                                          : c(activeTheme.textMuted),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          Text(
                            widget.uiScale == UiScalePreset.auto
                                ? '全屏或大窗口时自动放大界面（推荐）'
                                : '固定为设计尺寸的 ${widget.uiScale.label}',
                            style: AppTypography.app(
                              fontSize: 11,
                              color: c(_displayTheme.textMuted),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _sectionTitle('最大并发生成数'),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(5, (i) {
                            final n = i + 1;
                            final selected = _maxConcurrent == n;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => _selectMaxConcurrent(n),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? c(activeTheme.accent)
                                          : c(activeTheme.border),
                                    ),
                                    color: selected
                                        ? c(activeTheme.accent)
                                            .withValues(alpha: 0.15)
                                        : null,
                                  ),
                                  child: Text(
                                    '$n',
                                    style: AppTypography.app(
                                      color: selected
                                          ? c(activeTheme.accentGlow)
                                          : c(activeTheme.textMuted),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        Text(
                          '同时最多运行 $_maxConcurrent 个生成任务',
                          style: AppTypography.app(
                            fontSize: 11,
                            color: c(_displayTheme.textMuted),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle('历史列表上限'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: HistoryStore.maxItemsChoices.map((n) {
                            final selected = _maxHistoryItems == n;
                            return InkWell(
                              onTap: () => _selectMaxHistoryItems(n),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? c(activeTheme.accent)
                                        : c(activeTheme.border),
                                  ),
                                  color: selected
                                      ? c(activeTheme.accent)
                                          .withValues(alpha: 0.15)
                                      : null,
                                ),
                                child: Text(
                                  '$n',
                                  style: AppTypography.app(
                                    fontSize: 12,
                                    color: selected
                                        ? c(activeTheme.accentGlow)
                                        : c(activeTheme.textMuted),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        Text(
                          '应用内最多展示 $_maxHistoryItems 条；超出仍按周保存在 history/，不删图片',
                          style: AppTypography.app(
                            fontSize: 11,
                            color: c(_displayTheme.textMuted),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle(widget.fullPage ? '存储与日志' : '文件路径'),
                        if (widget.fullPage) ...[
                          const SizedBox(height: 6),
                          Text(
                            '生成图片默认写入下方目录；可开启同步保存到系统相册',
                            style: AppTypography.app(
                              fontSize: 11,
                              color: c(_displayTheme.textMuted),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (!widget.fullPage) ...[
                          _PathRow(
                            theme: _displayTheme,
                            kind: PathRowKind.config,
                            path: paths.config,
                            onOpen: () =>
                                ImageService.instance.openPath(paths.config),
                          ),
                          const SizedBox(height: 8),
                          _PathRow(
                            theme: _displayTheme,
                            kind: PathRowKind.history,
                            path: paths.history,
                            onOpen: () =>
                                ImageService.instance.openPath(paths.history),
                          ),
                          const SizedBox(height: 8),
                          _PathRow(
                            theme: _displayTheme,
                            kind: PathRowKind.images,
                            path: paths.images,
                            onOpen: () =>
                                ImageService.instance.openPath(paths.images),
                            onSelect: () async {
                              final dir =
                                  await FilePicker.platform.getDirectoryPath(
                                dialogTitle: '选择图片保存目录',
                                initialDirectory: paths.images,
                              );
                              if (dir != null) {
                                widget.onImagesDirChange(dir);
                                _refresh();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.fullPage) ...[
                          _MobileImageStorageCard(
                            theme: _displayTheme,
                            imagesPath: paths.images,
                            maxHistoryItems: _maxHistoryItems,
                            saveToGallery: widget.saveToGallery,
                            onSaveToGalleryChange: widget.onSaveToGalleryChange,
                            onPickDir: () async {
                              final dir =
                                  await FilePicker.platform.getDirectoryPath(
                                dialogTitle: '选择图片保存目录',
                              );
                              if (dir != null) {
                                widget.onImagesDirChange(dir);
                                _refresh();
                              }
                            },
                            onResetDir: () {
                              widget.onResetDir();
                              _refresh();
                            },
                          ),
                          const SizedBox(height: 8),
                          _PathRow(
                            theme: _displayTheme,
                            mobile: true,
                            kind: PathRowKind.config,
                            path: paths.config,
                            onOpen: () =>
                                ImageService.instance.openPath(paths.config),
                          ),
                          const SizedBox(height: 8),
                          _PathRow(
                            theme: _displayTheme,
                            mobile: true,
                            kind: PathRowKind.history,
                            path: paths.history,
                            onOpen: () =>
                                ImageService.instance.openPath(paths.history),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _PathRow(
                          theme: _displayTheme,
                          mobile: widget.fullPage,
                          kind: PathRowKind.log,
                          path: paths.log,
                          onOpen: () => ImageService.instance.openPath(paths.log),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'ImageGen © 2026 Origami · All rights reserved',
                            style: AppTypography.app(
                              fontSize: 11,
                              color: c(_displayTheme.textMuted).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                            ],
                          ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.app(
        fontSize: 11,
        letterSpacing: 1,
        color: c(_displayTheme.textMuted),
      ),
    );
  }
}

class _MobileImageStorageCard extends StatelessWidget {
  const _MobileImageStorageCard({
    required this.theme,
    required this.imagesPath,
    required this.maxHistoryItems,
    required this.saveToGallery,
    required this.onSaveToGalleryChange,
    required this.onPickDir,
    required this.onResetDir,
  });

  final AppTheme theme;
  final String imagesPath;
  final int maxHistoryItems;
  final bool saveToGallery;
  final ValueChanged<bool> onSaveToGalleryChange;
  final VoidCallback onPickDir;
  final VoidCallback onResetDir;

  void _copyPath(BuildContext context) {
    Clipboard.setData(ClipboardData(text: imagesPath));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制路径'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = ConfigService.instance.isUsingDefaultImagesDir;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c(theme.bg),
        border: Border.all(color: c(theme.border)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: c(theme.accentGlow)),
              const SizedBox(width: 8),
              Text(
                '图片保存',
                style: AppTypography.app(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c(theme.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              '同时保存到系统相册',
              style: AppTypography.app(fontSize: 13, color: c(theme.text)),
            ),
            subtitle: Text(
              '开启后，每次生成成功会写入相册「ImageGen」相册',
              style: AppTypography.app(fontSize: 11, color: c(theme.textMuted)),
            ),
            value: saveToGallery,
            activeThumbColor: c(theme.accentGlow),
            onChanged: onSaveToGalleryChange,
          ),
          const SizedBox(height: 8),
          Text(
            isDefault ? '应用目录（默认）' : '自定义目录',
            style: AppTypography.app(fontSize: 11, color: c(theme.textMuted)),
          ),
          const SizedBox(height: 6),
          FutureBuilder<int>(
            future: ConfigService.instance.countSavedImages(),
            builder: (context, snap) {
              if (snap.data == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '当前目录内 ${snap.data} 张 · 列表上限 $maxHistoryItems 条（按周存于 history/）',
                  style: AppTypography.app(
                    fontSize: 11,
                    color: c(theme.accentGlow),
                  ),
                ),
              );
            },
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c(theme.surface),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c(theme.border).withValues(alpha: 0.6)),
            ),
            child: SelectableText(
              imagesPath,
              style: AppTypography.mono(color: c(theme.textMuted), size: 10),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                icon: Icons.folder_open,
                label: '选择目录',
                onTap: onPickDir,
              ),
              if (!isDefault)
                _actionChip(
                  icon: Icons.restore,
                  label: '恢复默认',
                  onTap: onResetDir,
                ),
              _actionChip(
                icon: Icons.copy,
                label: '复制路径',
                onTap: () => _copyPath(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: c(theme.surface),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: c(theme.border)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c(theme.textMuted)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.app(fontSize: 12, color: c(theme.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum PathRowKind { config, history, images, log }

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.theme,
    required this.kind,
    required this.path,
    required this.onOpen,
    this.mobile = false,
    this.onSelect,
  });

  final AppTheme theme;
  final PathRowKind kind;
  final String path;
  final bool mobile;
  final VoidCallback onOpen;
  final VoidCallback? onSelect;

  String get _label => switch (kind) {
        PathRowKind.config => '配置文件',
        PathRowKind.history => '历史目录',
        PathRowKind.images => '图片目录',
        PathRowKind.log => '运行日志',
      };

  String get _mobileHint => switch (kind) {
        PathRowKind.config => 'API 配置与主题等设置（config.json）',
        PathRowKind.history => '生成历史按周拆分（如 2026-W36.json）',
        PathRowKind.images => '已生成图片的保存位置',
        PathRowKind.log => '应用运行与请求记录（app.log）',
      };

  IconData get _icon => switch (kind) {
        PathRowKind.config => Icons.settings_outlined,
        PathRowKind.history => Icons.history,
        PathRowKind.images => Icons.image_outlined,
        PathRowKind.log => Icons.article_outlined,
      };

  void _copyPath(BuildContext context) {
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制路径', style: TextStyle(color: c(theme.text))),
        backgroundColor: c(theme.surface),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _viewLog(BuildContext context) async {
    final text = await ConfigService.instance.readLogTail();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c(theme.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    '运行日志',
                    style: AppTypography.app(
                      color: c(theme.text),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: c(theme.textMuted)),
                    tooltip: '复制全部',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text('已复制日志'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: c(theme.textMuted)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SelectableText(
                  text,
                  style: AppTypography.mono(
                    color: c(theme.textMuted),
                    size: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (mobile) return _buildMobile(context);
    return _buildDesktop(context);
  }

  Widget _buildMobile(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c(theme.bg),
        border: Border.all(color: c(theme.border)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: c(theme.accentGlow)),
              const SizedBox(width: 8),
              Text(
                _label,
                style: AppTypography.app(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c(theme.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _mobileHint,
            style: AppTypography.app(fontSize: 11, color: c(theme.textMuted)),
          ),
          if (kind == PathRowKind.images) ...[
            const SizedBox(height: 6),
            FutureBuilder<int>(
              future: ConfigService.instance.countSavedImages(),
              builder: (context, snap) {
                final n = snap.data;
                if (n == null) return const SizedBox.shrink();
                return Text(
                  '当前已保存 $n 张图片',
                  style: AppTypography.app(
                    fontSize: 11,
                    color: c(theme.accentGlow),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c(theme.surface),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c(theme.border).withValues(alpha: 0.6)),
            ),
            child: SelectableText(
              path,
              style: AppTypography.mono(color: c(theme.textMuted), size: 10),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _mobileAction(
                icon: Icons.copy,
                label: '复制路径',
                onTap: () => _copyPath(context),
              ),
              if (kind == PathRowKind.log)
                _mobileAction(
                  icon: Icons.visibility_outlined,
                  label: '查看日志',
                  onTap: () => _viewLog(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: c(theme.surface),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: c(theme.border)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c(theme.textMuted)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.app(
                  fontSize: 12,
                  color: c(theme.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c(theme.bg),
        border: Border.all(color: c(theme.border)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: AppTypography.app(
                    fontSize: 11,
                    color: c(theme.textMuted),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  path,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono(color: c(theme.text), size: 11),
                ),
              ],
            ),
          ),
          if (onSelect != null)
            IconButton(
              icon: Icon(Icons.more_horiz, size: 16, color: c(theme.textMuted)),
              onPressed: onSelect,
              tooltip: '更改目录',
            ),
          IconButton(
            icon: Icon(Icons.folder_open_outlined, size: 16, color: c(theme.textMuted)),
            onPressed: onOpen,
            tooltip: '在文件管理器中打开',
          ),
        ],
      ),
    );
  }
}
