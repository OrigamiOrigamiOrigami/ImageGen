import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../platform/drop_target_wrap.dart';
import '../platform/is_desktop.dart';
import '../services/api_service.dart';
import '../theme/ui_scale.dart';
import '../themes/app_themes.dart';

const _modelGroups = [
  (
    label: 'GPT Images',
    color: Color(0xFFF59E0B),
    models: [
      'gpt-image-2.5',
      'gpt-image-2.5-sunburst',
      'gpt-image-2.5-flare',
      'gpt-image-2',
      'gpt-image-2-vip',
    ],
  ),
  (
    label: 'Nano Banana',
    color: Color(0xFF10B981),
    models: [
      'nano-banana-fast',
      'nano-banana-2-lite',
      'nano-banana-2',
      'nano-banana-2-cl',
      'nano-banana-2-2k-cl',
      'nano-banana-2-4k-cl',
      'nano-banana-pro',
      'nano-banana-pro-cl',
      'nano-banana-pro-vip',
      'nano-banana-pro-4k-vip',
    ],
  ),
];

class _ParamsConfig {
  const _ParamsConfig({
    required this.sizes,
    this.imageSizes,
    this.qualities,
    this.supportsTransparentBg = false,
  });
  final List<String> sizes;
  final List<String>? imageSizes;
  final List<String>? qualities;
  final bool supportsTransparentBg;
}

const _nanoBanana2ExtraRatios = ['1:4', '4:1', '1:8', '8:1'];

/// gpt-image-2 / 2.5：可传比例字符串
const _gptBasicRatios = [
  'auto',
  '1:1',
  '16:9',
  '9:16',
  '4:3',
  '3:4',
  '3:2',
  '2:3',
  '5:4',
  '4:5',
  '21:9',
  '9:21',
  '1:2',
  '2:1',
];

/// vip / flare / sunburst：官方像素表覆盖的比例
const _gptPixelRatios = [
  'auto',
  '1:1',
  '16:9',
  '9:16',
  '4:3',
  '3:4',
  '3:2',
  '2:3',
  '5:4',
  '4:5',
  '21:9',
  '9:21',
  '1:2',
  '2:1',
  '1:3',
  '3:1',
];

_ParamsConfig _paramsForModel(String model) {
  final type = detectModelType(model);
  switch (type) {
    case ModelType.gptImage:
      final qualities = gptQualityOptions(model);
      return _ParamsConfig(
        sizes: gptUsesPixelSize(model) ? _gptPixelRatios : _gptBasicRatios,
        imageSizes: gptUsesPixelSize(model) ? const ['1K', '2K', '4K'] : null,
        qualities: qualities.isEmpty ? null : qualities,
        supportsTransparentBg: gptSupportsTransparentBackground(model),
      );
    case ModelType.nanoBanana:
      final base = [
        'auto',
        '1:1',
        '16:9',
        '9:16',
        '4:3',
        '3:4',
        '3:2',
        '2:3',
        '5:4',
        '4:5',
        '21:9',
      ];
      return _ParamsConfig(
        sizes: isNanoBanana2Family(model)
            ? [...base, ..._nanoBanana2ExtraRatios]
            : base,
        imageSizes: const ['1K', '2K', '4K'],
      );
    case ModelType.gemini:
      return const _ParamsConfig(
        sizes: ['1:1', '3:4', '4:3', '16:9', '9:16'],
      );
    case ModelType.openai:
      return const _ParamsConfig(
        sizes: ['1:1', '3:2', '2:3'],
      );
  }
}

/// 切换模型时尽量保留用户已选比例，避免总是回到 auto。
String _sizeForModel(String model, String preferred) {
  final sizes = _paramsForModel(model).sizes;
  if (sizes.contains(preferred)) return preferred;
  if (sizes.contains('1:1')) return '1:1';
  return sizes.first;
}

String _imageSizeForModel(String model, String preferred) {
  final imageSizes = _paramsForModel(model).imageSizes;
  if (imageSizes == null) return preferred;
  if (imageSizes.contains(preferred)) return preferred;
  return imageSizes.first;
}

String _qualityForModel(String model, String preferred) {
  final qualities = _paramsForModel(model).qualities;
  if (qualities == null || qualities.isEmpty) return gptDefaultQuality(model);
  if (qualities.contains(preferred)) return preferred;
  return gptDefaultQuality(model);
}

const _formatColors = {
  ApiFormat.grsai: Color(0xFF10B981),
  ApiFormat.openai: Color(0xFF3B82F6),
  ApiFormat.gemini: Color(0xFF8B5CF6),
};

const _formatLabels = {
  ApiFormat.grsai: 'grsai',
  ApiFormat.openai: 'OpenAI 兼容',
  ApiFormat.gemini: 'Gemini 兼容',
};

typedef GenerateCallback = void Function(
  String prompt,
  String model,
  String size,
  String imageSize,
  List<String> refImages,
  String? quality,
  String? background,
);

class PromptBar extends StatefulWidget {
  const PromptBar({
    super.key,
    required this.theme,
    required this.onGenerate,
    required this.hasRunning,
    required this.profiles,
    required this.activeProfileId,
    required this.onSwitchProfile,
    this.initialModel,
  });

  final AppTheme theme;
  final GenerateCallback onGenerate;
  final bool hasRunning;
  final List<Profile> profiles;
  final String? activeProfileId;
  final ValueChanged<String> onSwitchProfile;
  final String? initialModel;

  @override
  State<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends State<PromptBar> {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  late String _model;
  late String _size;
  var _imageSize = '1K';
  var _quality = 'auto';
  var _transparentBg = false;
  var _showOptions = false;
  var _showProfilePicker = false;
  final _refImages = <String>[];
  final _refPreviews = <String>[];
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    final allModels =
        _modelGroups.expand((g) => g.models).toList(growable: false);
    _model = widget.initialModel ?? 'nano-banana-2';
    if (!allModels.contains(_model)) _model = 'nano-banana-2';
    _size = _paramsForModel(_model).sizes.first;
    _quality = gptDefaultQuality(_model);
    _promptFocusNode.onKeyEvent = _onPromptKey;
  }

  KeyEventResult _onPromptKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(PromptBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialModel == null &&
        widget.initialModel != null &&
        widget.initialModel!.isNotEmpty) {
      _model = widget.initialModel!;
    }
    if (oldWidget.activeProfileId != widget.activeProfileId) {
      _syncModelToActiveProfile();
    }
  }

  void _syncModelToActiveProfile() {
    final models = _visibleModelGroups.expand((g) => g.models);
    if (!models.contains(_model)) {
      final first = models.isNotEmpty ? models.first : _model;
      setState(() {
        _model = first;
        _size = _sizeForModel(first, _size);
        _imageSize = _imageSizeForModel(first, _imageSize);
        _quality = _qualityForModel(first, _quality);
        if (!gptSupportsTransparentBackground(first)) {
          _transparentBg = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _promptFocusNode.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Profile? get _activeProfile {
    for (final p in widget.profiles) {
      if (p.id == widget.activeProfileId) return p;
    }
    return null;
  }

  /// grsai 专用模型为代码内置，不会从服务端拉取；OpenAI/Gemini 用配置里的默认模型名。
  List<({String label, Color color, List<String> models})> get _visibleModelGroups {
    final profile = _activeProfile;
    if (profile == null) return _modelGroups;
    switch (profile.apiFormat) {
      case ApiFormat.grsai:
        return _modelGroups;
      case ApiFormat.openai:
        final m = (profile.defaultModel != null && profile.defaultModel!.isNotEmpty)
            ? profile.defaultModel!
            : 'dall-e-3';
        return [
          (label: 'OpenAI 兼容', color: const Color(0xFF3B82F6), models: [m]),
        ];
      case ApiFormat.gemini:
        final m = (profile.defaultModel != null && profile.defaultModel!.isNotEmpty)
            ? profile.defaultModel!
            : 'imagen-3.0-generate-002';
        return [
          (label: 'Gemini 兼容', color: const Color(0xFF8B5CF6), models: [m]),
        ];
    }
  }

  String get _optionsSummary {
    final cfg = _paramsForModel(_model);
    final res = cfg.imageSizes != null ? ' · $_imageSize' : '';
    final q = cfg.qualities != null && cfg.qualities!.length > 1
        ? ' · $_quality'
        : '';
    final bg = cfg.supportsTransparentBg && _transparentBg ? ' · 透明底' : '';
    return '$_model · $_size$res$q$bg';
  }

  void _applyModel(String m, {VoidCallback? onChanged}) {
    setState(() {
      _model = m;
      _size = _sizeForModel(m, _size);
      _imageSize = _imageSizeForModel(m, _imageSize);
      _quality = _qualityForModel(m, _quality);
      if (!gptSupportsTransparentBackground(m)) {
        _transparentBg = false;
      }
    });
    onChanged?.call();
  }

  void _closeMobileOptionsSheet(BuildContext sheetContext) {
    FocusManager.instance.primaryFocus?.unfocus();
    _promptFocusNode.unfocus();
    Navigator.pop(sheetContext);
  }

  void _submit() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    final cfg = _paramsForModel(_model);
    final quality = cfg.qualities != null ? _quality : null;
    final background =
        cfg.supportsTransparentBg && _transparentBg ? 'transparent' : null;
    widget.onGenerate(
      prompt,
      _model,
      _size,
      _imageSize,
      List.of(_refImages),
      quality,
      background,
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) await _addFile(File(f.path!));
    }
  }

  Future<void> _addFile(File file) async {
    final bytes = await file.readAsBytes();
    final mime = _mimeFromPath(file.path);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() {
      _refImages.add(dataUrl);
      _refPreviews.add(dataUrl);
    });
  }

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
  }

  void _removeRef(int i) {
    setState(() {
      _refImages.removeAt(i);
      _refPreviews.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final paramsCfg = _paramsForModel(_model);
    final scale = context.appScale;

    final compact = scale.isCompact;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPad = scale.promptBarPadding +
        (viewInsets.bottom > 0
            ? 8
            : MediaQuery.paddingOf(context).bottom);

    return Container(
      padding: EdgeInsets.fromLTRB(
        scale.promptBarPadding,
        scale.promptBarPadding,
        scale.promptBarPadding,
        bottomPad,
      ),
      decoration: BoxDecoration(
        color: c(widget.theme.surface),
        border: Border(top: BorderSide(color: c(widget.theme.border))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scale.promptMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact && _showOptions) _optionsPanel(paramsCfg),
              if (_refPreviews.isNotEmpty) _refPreviewRow(),
              compact ? _mobileInputRow(paramsCfg) : _inputRow(paramsCfg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionsPanel(
    _ParamsConfig paramsCfg, {
    VoidCallback? onChanged,
    bool showGrsaiHint = false,
  }) {
    final groups = _visibleModelGroups;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGrsaiHint && _activeProfile?.apiFormat == ApiFormat.grsai)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
            ),
          ...groups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        group.label,
                        style: TextStyle(fontSize: 11, color: group.color),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: group.models.map((m) {
                          final selected = _model == m;
                          return InkWell(
                            onTap: () => _applyModel(m, onChanged: onChanged),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected
                                      ? group.color
                                      : c(widget.theme.border),
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color: selected
                                    ? group.color.withValues(alpha: 0.13)
                                    : null,
                              ),
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? group.color
                                      : c(widget.theme.textMuted),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              )),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('比例', style: TextStyle(fontSize: 11, color: c(widget.theme.textMuted))),
              ...paramsCfg.sizes.map((s) => _chip(
                    label: s,
                    selected: _size == s,
                    onTap: () {
                      setState(() => _size = s);
                      onChanged?.call();
                    },
                  )),
            ],
          ),
          if (paramsCfg.imageSizes != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('分辨率',
                    style: TextStyle(fontSize: 11, color: c(widget.theme.textMuted))),
                ...paramsCfg.imageSizes!.map((s) => _chip(
                      label: s,
                      selected: _imageSize == s,
                      onTap: () {
                        setState(() => _imageSize = s);
                        onChanged?.call();
                      },
                    )),
              ],
            ),
          ],
          if (paramsCfg.qualities != null &&
              paramsCfg.qualities!.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('质量',
                    style: TextStyle(
                        fontSize: 11, color: c(widget.theme.textMuted))),
                ...paramsCfg.qualities!.map((s) => _chip(
                      label: s,
                      selected: _quality == s,
                      onTap: () {
                        setState(() => _quality = s);
                        onChanged?.call();
                      },
                    )),
              ],
            ),
          ],
          if (paramsCfg.supportsTransparentBg) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('背景',
                    style: TextStyle(
                        fontSize: 11, color: c(widget.theme.textMuted))),
                _chip(
                  label: '透明',
                  selected: _transparentBg,
                  onTap: () {
                    setState(() => _transparentBg = !_transparentBg);
                    onChanged?.call();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? c(widget.theme.accent) : c(widget.theme.border),
          ),
          borderRadius: BorderRadius.circular(4),
          color: selected ? c(widget.theme.accent).withValues(alpha: 0.2) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? c(widget.theme.accentGlow) : c(widget.theme.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _refPreviewRow() {
    const thumbSize = 56.0;
    const radius = 10.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_refPreviews.length, (i) {
          return SizedBox(
            width: thumbSize,
            height: thumbSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _showRefLightbox(_refPreviews[i]),
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: c(widget.theme.border),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius - 1),
                      child: Image.memory(
                        _decodeDataUrl(_refPreviews[i]),
                        width: thumbSize,
                        height: thumbSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeRef(i),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Uint8List _decodeDataUrl(String url) {
    final base64Str = url.contains(',') ? url.split(',').last : url;
    return base64Decode(base64Str);
  }

  void _showRefLightbox(String src) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.memory(_decodeDataUrl(src), fit: BoxFit.contain),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMobileOptions(_ParamsConfig paramsCfg) {
    FocusManager.instance.primaryFocus?.unfocus();
    _promptFocusNode.unfocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c(widget.theme.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          void refresh() {
            setState(() {});
            setModalState(() {});
          }

          final liveCfg = _paramsForModel(_model);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (_, scrollController) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c(widget.theme.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '生成选项',
                              style: TextStyle(
                                color: c(widget.theme.text),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _optionsSummary,
                              style: TextStyle(
                                fontSize: 12,
                                color: c(widget.theme.accentGlow),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: c(widget.theme.textMuted)),
                        onPressed: () => _closeMobileOptionsSheet(sheetContext),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _optionsPanel(
                      liveCfg,
                      onChanged: refresh,
                      showGrsaiHint: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      _promptFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Widget _mobileInputRow(_ParamsConfig paramsCfg) {
    final scale = context.appScale;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    const btn = 36.0;
    final fs = scale.sp(14);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _openMobileOptions(
                  _paramsForModel(_model),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c(widget.theme.bg),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c(widget.theme.border)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 14, color: c(widget.theme.textMuted)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _optionsSummary,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: c(widget.theme.textMuted),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 14, color: c(widget.theme.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _pickFiles,
              tooltip: '参考图',
              style: IconButton.styleFrom(
                fixedSize: const Size(btn, btn),
                minimumSize: const Size(btn, btn),
                padding: EdgeInsets.zero,
                backgroundColor: _refImages.isNotEmpty
                    ? c(widget.theme.accent).withValues(alpha: 0.13)
                    : c(widget.theme.bg),
                side: BorderSide(
                  color: _refImages.isNotEmpty
                      ? c(widget.theme.accent)
                      : c(widget.theme.border),
                ),
              ),
              icon: Icon(
                Icons.add_photo_alternate_outlined,
                size: 18,
                color: _refImages.isNotEmpty
                    ? c(widget.theme.accentGlow)
                    : c(widget.theme.textMuted),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c(widget.theme.bg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c(widget.theme.border)),
                ),
                child: TextField(
                  controller: _promptController,
                  focusNode: _promptFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  scrollPadding: EdgeInsets.only(
                    bottom: keyboardBottom + 160,
                  ),
                  style: TextStyle(color: c(widget.theme.text), fontSize: fs),
                  decoration: InputDecoration(
                    hintText: '描述你想生成的图片...',
                    hintStyle:
                        TextStyle(color: c(widget.theme.textMuted), fontSize: fs),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _submit,
              tooltip: '生成',
              style: IconButton.styleFrom(
                fixedSize: const Size(btn, btn),
                minimumSize: const Size(btn, btn),
                padding: EdgeInsets.zero,
                backgroundColor: c(widget.theme.accent),
              ),
              icon: widget.hasRunning
                  ? const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inputRow(_ParamsConfig paramsCfg) {
    final scale = context.appScale;
    final maxLines = scale.promptMaxLines;
    final minLines = scale.promptMinLines;
    final btn = scale.dim(40);
    final fs = scale.sp(13);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _profilePicker(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _pickFiles,
          tooltip: '上传参考图',
          style: IconButton.styleFrom(
            fixedSize: Size(btn, btn),
            backgroundColor: _refImages.isNotEmpty
                ? c(widget.theme.accent).withValues(alpha: 0.13)
                : c(widget.theme.surface),
            side: BorderSide(
              color: _refImages.isNotEmpty
                  ? c(widget.theme.accent)
                  : c(widget.theme.border),
            ),
          ),
          icon: Icon(
            Icons.add_photo_alternate_outlined,
            size: scale.dim(18),
            color: _refImages.isNotEmpty
                ? c(widget.theme.accentGlow)
                : c(widget.theme.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: wrapDropTarget(
            onDragging: (v) => setState(() => _dragging = v),
            onDrop: (paths) async {
              for (final path in paths) {
                await _addFile(File(path));
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: c(widget.theme.bg),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dragging ? c(widget.theme.accent) : c(widget.theme.border),
                  width: _dragging ? 2 : 1,
                ),
                boxShadow: _dragging
                    ? [
                        BoxShadow(
                          color: c(widget.theme.accent).withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: _promptController,
                focusNode: _promptFocusNode,
                minLines: minLines,
                maxLines: maxLines,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: c(widget.theme.text), fontSize: fs),
                decoration: InputDecoration(
                  hintText: _dragging
                      ? '松开以添加图片...'
                      : isDesktop
                          ? '描述你想生成的图片... (Enter 发送，Shift+Enter 换行，可粘贴/拖入图片)'
                          : '描述你想生成的图片...',
                  hintStyle:
                      TextStyle(color: c(widget.theme.textMuted), fontSize: fs),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: scale.dim(14),
                    vertical: scale.dim(14),
                  ),
                ),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            IconButton(
              onPressed: () => setState(() => _showOptions = !_showOptions),
              tooltip: '更多选项',
              style: IconButton.styleFrom(
                fixedSize: Size(btn, btn),
                backgroundColor: _showOptions
                    ? c(widget.theme.accent).withValues(alpha: 0.2)
                    : c(widget.theme.surface),
                side: BorderSide(
                  color: _showOptions
                      ? c(widget.theme.accent)
                      : c(widget.theme.border),
                ),
              ),
              icon: Icon(
                _showOptions ? Icons.expand_more : Icons.expand_less,
                color: _showOptions
                    ? c(widget.theme.accentGlow)
                    : c(widget.theme.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              onPressed: _submit,
              tooltip: '生成',
              style: IconButton.styleFrom(
                fixedSize: Size(btn, btn),
                backgroundColor: c(widget.theme.accent),
              ),
              icon: widget.hasRunning
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                  : Icon(Icons.auto_awesome,
                      color: Colors.white, size: scale.dim(18)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _profilePicker() {
    final scale = context.appScale;
    final btn = scale.dim(40);
    final fsSm = scale.sp(11);
    return PopupMenuButton<String>(
      tooltip: '切换 API Key',
      onOpened: () => setState(() => _showProfilePicker = true),
      onCanceled: () => setState(() => _showProfilePicker = false),
      onSelected: (id) {
        widget.onSwitchProfile(id);
        setState(() => _showProfilePicker = false);
      },
      itemBuilder: (context) => widget.profiles
          .map((p) => PopupMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 12)),
                          Text(
                            '${_formatLabels[p.apiFormat]} · ${p.baseUrl.replaceFirst('https://', '').split('/').first}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _formatColors[p.apiFormat],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.id == widget.activeProfileId)
                      Icon(Icons.check, size: 12, color: c(widget.theme.accentGlow)),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        height: btn,
        padding: EdgeInsets.symmetric(horizontal: scale.dim(12)),
        decoration: BoxDecoration(
          color: c(widget.theme.surface),
          border: Border.all(color: c(widget.theme.border)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c(widget.theme.accentGlow),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: scale.dim(80)),
              child: Text(
                _activeProfile?.name ?? '未选择',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fsSm, color: c(widget.theme.textMuted)),
              ),
            ),
            Icon(
              _showProfilePicker ? Icons.expand_less : Icons.expand_more,
              size: scale.dim(12),
              color: c(widget.theme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
