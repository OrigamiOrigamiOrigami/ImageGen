import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../platform/is_mobile.dart';
import '../themes/app_themes.dart';

class ProfileSwitcher extends StatefulWidget {
  const ProfileSwitcher({
    super.key,
    required this.theme,
    required this.profiles,
    required this.activeId,
    required this.onSwitch,
    required this.onManage,
  });

  final AppTheme theme;
  final List<Profile> profiles;
  final String? activeId;
  final ValueChanged<String> onSwitch;
  final VoidCallback onManage;

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  Profile? get _active =>
      widget.profiles.where((p) => p.id == widget.activeId).firstOrNull;

  void _toggle() {
    if (isMobile) {
      _openMobileSheet();
      return;
    }
    if (_overlay != null) {
      _close();
    } else {
      _open();
    }
  }

  void _openMobileSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c(widget.theme.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    '切换 API 配置',
                    style: TextStyle(
                      color: c(widget.theme.text),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: c(widget.theme.textMuted)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            if (widget.profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '暂无配置',
                  style: TextStyle(color: c(widget.theme.textMuted), fontSize: 13),
                ),
              ),
            ...widget.profiles.map((p) => ListTile(
                  title: Text(p.name, style: TextStyle(color: c(widget.theme.text))),
                  subtitle: Text(
                    p.apiFormat.name,
                    style: TextStyle(color: c(widget.theme.textMuted), fontSize: 12),
                  ),
                  trailing: p.id == widget.activeId
                      ? Icon(Icons.check, color: c(widget.theme.accentGlow), size: 18)
                      : null,
                  onTap: () {
                    widget.onSwitch(p.id);
                    Navigator.pop(ctx);
                  },
                )),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.settings, color: c(widget.theme.accentGlow), size: 20),
              title: Text(
                '管理 API 配置',
                style: TextStyle(color: c(widget.theme.accentGlow), fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onManage();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _open() {
    _overlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            offset: const Offset(0, 40),
            child: Material(
              color: c(widget.theme.surface),
              elevation: 8,
              shadowColor: c(widget.theme.accent).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: 224,
                decoration: BoxDecoration(
                  border: Border.all(color: c(widget.theme.border)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: c(widget.theme.accent).withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.profiles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '暂无配置',
                          style: TextStyle(
                            color: c(widget.theme.textMuted),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ...widget.profiles.map((p) => InkWell(
                          onTap: () {
                            widget.onSwitch(p.id);
                            _close();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          color: c(widget.theme.text),
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        p.apiFormat.name,
                                        style: TextStyle(
                                          color: c(widget.theme.textMuted),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (p.id == widget.activeId)
                                  Icon(
                                    Icons.check,
                                    size: 14,
                                    color: c(widget.theme.accentGlow),
                                  ),
                              ],
                            ),
                          ),
                        )),
                    Divider(height: 1, color: c(widget.theme.border)),
                    InkWell(
                      onTap: () {
                        widget.onManage();
                        _close();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add,
                              size: 14,
                              color: c(widget.theme.accentGlow),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '管理配置',
                              style: TextStyle(
                                color: c(widget.theme.accentGlow),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    setState(() {});
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _overlay != null;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: c(widget.theme.surface),
            border: Border.all(
              color: open ? c(widget.theme.accent) : c(widget.theme.border),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c(widget.theme.accentGlow),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c(widget.theme.accentGlow).withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  _active?.name ?? '选择配置',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c(widget.theme.text), fontSize: 13),
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: c(widget.theme.textMuted),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
