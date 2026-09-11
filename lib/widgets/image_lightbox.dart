import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../platform/is_mobile.dart';
import '../services/image_service.dart';
import '../theme/app_typography.dart';
import '../themes/app_themes.dart';

/// 全屏图片预览（盖住主界面含底部输入栏）
class ImageLightbox extends StatefulWidget {
  const ImageLightbox({
    super.key,
    required this.theme,
    required this.history,
    required this.index,
    required this.onChange,
    required this.onClose,
  });

  final AppTheme theme;
  final List<HistoryItem> history;
  final int index;
  final ValueChanged<int> onChange;
  final VoidCallback onClose;

  @override
  State<ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<ImageLightbox> {
  Uint8List? _bytes;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ImageLightbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _load();
  }

  Future<void> _load() async {
    setState(() => _bytes = null);
    final item = widget.history[widget.index];
    final bytes = await ImageService.instance.readImageBytes(item.imagePath);
    if (mounted) setState(() => _bytes = bytes);
  }

  Future<void> _handleCopy(String imagePath) async {
    final ok = await ImageService.instance.copyToClipboard(imagePath);
    if (ok && mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        widget.index > 0) {
      widget.onChange(widget.index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        widget.index < widget.history.length - 1) {
      widget.onChange(widget.index + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _metaLine(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.wenHei(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 2),
          mono
              ? SelectableText(
                  value,
                  style: AppTypography.mono(
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 11,
                  ),
                )
              : Text(
                  value,
                  style: AppTypography.wenHei(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _infoPanel(HistoryItem item, double maxW) {
    final meta = item.generationMetaLine;
    final fileSize =
        ImageService.instance.formatFileSizeLabel(item.imagePath);

    return Container(
      width: maxW,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            item.prompt,
            style: AppTypography.wenHei(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat('yyyy-MM-dd HH:mm')
                .format(DateTime.parse(item.createdAt)),
            style: AppTypography.wenHei(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta,
              style: AppTypography.wenHei(
                fontSize: 12,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (isMobile) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 6),
            _metaLine('像素尺寸', '${item.width} × ${item.height}'),
            _metaLine('文件大小', fileSize),
            _metaLine('保存路径', item.imagePath, mono: true),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _LightboxToolbarBtn(
                  icon: _copied ? Icons.check : Icons.copy,
                  label: _copied ? '已复制' : '复制图片',
                  primary: true,
                  onPressed: () => _handleCopy(item.imagePath),
                ),
                _LightboxToolbarBtn(
                  icon: Icons.folder_open_outlined,
                  label: '打开位置',
                  onPressed: () =>
                      ImageService.instance.revealInFolder(item.imagePath),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagePreview(double maxW, double maxH) {
    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _bytes!,
          fit: BoxFit.contain,
          width: maxW,
          height: maxH,
        ),
      );
    }
    return SizedBox(
      width: maxW < 384 ? maxW : 384,
      height: maxH.clamp(200, 320),
      child: _LightboxShimmer(theme: widget.theme),
    );
  }

  Widget _buildMobileLayout(BuildContext context, HistoryItem item) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width * 0.92;
    final maxImageH = size.height * 0.48;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: _LightboxIconBtn(
                icon: Icons.close,
                tooltip: '关闭',
                onPressed: widget.onClose,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () {},
                onDoubleTap: widget.onClose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _imagePreview(maxW, maxImageH),
                    ),
                    const SizedBox(height: 10),
                    _infoPanel(item, maxW),
                  ],
                ),
              ),
            ),
          ),
          if (widget.history.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.index > 0)
                    _LightboxIconBtn(
                      icon: Icons.chevron_left,
                      tooltip: '上一张',
                      onPressed: () => widget.onChange(widget.index - 1),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${widget.index + 1} / ${widget.history.length}',
                      style: AppTypography.wenHei(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  if (widget.index < widget.history.length - 1)
                    _LightboxIconBtn(
                      icon: Icons.chevron_right,
                      tooltip: '下一张',
                      onPressed: () => widget.onChange(widget.index + 1),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, HistoryItem item) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final maxW = size.width * 0.88;

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(52, 4, 52, 12),
            child: GestureDetector(
              onTap: () {},
              onDoubleTap: widget.onClose,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _imagePreview(maxW, size.height * 0.62),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxW,
                      maxHeight: size.height * 0.34,
                    ),
                    child: SingleChildScrollView(
                      child: _infoPanel(item, maxW),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: padding.top + 12,
          right: 12,
          child: _LightboxIconBtn(
            icon: Icons.close,
            tooltip: '关闭 (Esc / 双击)',
            onPressed: widget.onClose,
          ),
        ),
        if (widget.index > 0)
          Positioned(
            left: 12,
            top: padding.top,
            bottom: padding.bottom,
            child: Center(
              child: _LightboxIconBtn(
                icon: Icons.chevron_left,
                tooltip: '上一张',
                onPressed: () => widget.onChange(widget.index - 1),
              ),
            ),
          ),
        if (widget.index < widget.history.length - 1)
          Positioned(
            right: 12,
            top: padding.top,
            bottom: padding.bottom,
            child: Center(
              child: _LightboxIconBtn(
                icon: Icons.chevron_right,
                tooltip: '下一张',
                onPressed: () => widget.onChange(widget.index + 1),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.history[widget.index];

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: Stack(
          children: [
            GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
            if (isMobile)
              _buildMobileLayout(context, item)
            else
              _buildDesktopLayout(context, item),
          ],
        ),
      ),
    );
  }
}

class _LightboxToolbarBtn extends StatelessWidget {
  const _LightboxToolbarBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.wenHei(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightboxIconBtn extends StatelessWidget {
  const _LightboxIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _LightboxShimmer extends StatefulWidget {
  const _LightboxShimmer({required this.theme});
  final AppTheme theme;

  @override
  State<_LightboxShimmer> createState() => _LightboxShimmerState();
}

class _LightboxShimmerState extends State<_LightboxShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: [
                c(widget.theme.border),
                c(widget.theme.muted),
                c(widget.theme.border),
              ],
            ),
          ),
          child: child,
        );
      },
      child: const SizedBox.expand(),
    );
  }
}
