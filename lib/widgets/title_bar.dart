import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_models.dart';
import '../platform/is_desktop.dart';
import '../theme/app_typography.dart';
import '../theme/ui_scale.dart';
import '../themes/app_themes.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.theme,
    required this.onSettings,
  });

  final AppTheme theme;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scale = context.appScale;
    final bar = Container(
      height: scale.dim(isDesktop ? 40 : 48),
      padding: EdgeInsets.symmetric(horizontal: scale.dim(16)),
      decoration: BoxDecoration(
        color: c(theme.surface),
        border: Border(bottom: BorderSide(color: c(theme.border))),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: scale.dim(16), color: c(theme.accentGlow)),
          SizedBox(width: scale.dim(8)),
          Text(
            'IMAGEGEN',
            style: AppTypography.brandTitle(
              color: c(theme.textMuted),
              size: scale.sp(13),
            ),
          ),
          if (isDesktop) ...[
            SizedBox(width: scale.dim(8)),
            Text(
              'by Origami',
              style: AppTypography.brandSubtitle(
                color: c(theme.textMuted).withValues(alpha: 0.45),
              ).copyWith(fontSize: scale.sp(11)),
            ),
          ],
          const Spacer(),
          _WinBtn(
            icon: Icons.settings_outlined,
            tooltip: '系统设置',
            onTap: onSettings,
            theme: theme,
          ),
          if (isDesktop) ...[
            _WinBtn(
              icon: Icons.remove,
              tooltip: '最小化',
              onTap: () => windowManager.minimize(),
              theme: theme,
            ),
            _WinBtn(
              icon: Icons.crop_square,
              tooltip: '最大化',
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              theme: theme,
              iconSize: 12,
            ),
            _WinBtn(
              icon: Icons.close,
              tooltip: '关闭',
              onTap: () => windowManager.close(),
              theme: theme,
              hoverColor: Colors.red.withValues(alpha: 0.2),
              hoverIconColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );

    if (!isDesktop) return SafeArea(bottom: false, child: bar);
    return DragToMoveArea(child: bar);
  }
}

class _WinBtn extends StatefulWidget {
  const _WinBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.theme,
    this.iconSize = 14,
    this.hoverColor,
    this.hoverIconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppTheme theme;
  final double iconSize;
  final Color? hoverColor;
  final Color? hoverIconColor;

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: _hover ? (widget.hoverColor ?? c(widget.theme.border).withValues(alpha: 0.5)) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hover
                  ? (widget.hoverIconColor ?? c(widget.theme.text))
                  : c(widget.theme.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
