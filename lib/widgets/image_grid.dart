import 'dart:io';

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../platform/is_mobile.dart';
import '../services/image_service.dart';
import '../services/thumbnail_service.dart';
import '../theme/ui_scale.dart';
import '../themes/app_themes.dart';

class ImageGrid extends StatefulWidget {
  const ImageGrid({
    super.key,
    required this.theme,
    required this.history,
    required this.tasks,
    required this.onDelete,
    required this.onPreview,
  });

  final AppTheme theme;
  final List<HistoryItem> history;
  final List<GenTask> tasks;
  final Future<void> Function(String id, String imagePath) onDelete;
  final ValueChanged<int> onPreview;

  @override
  State<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final history = widget.history;
    final tasks = widget.tasks;
    final scale = context.appScale;
    final compact = scale.isCompact;
    final pad = compact ? scale.dim(12) : scale.dim(24);
    final gap = compact ? scale.dim(8) : scale.dim(16);
    final gridDelegate = compact
        ? SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: scale.gridCrossAxisCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 0.72,
          )
        : SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: scale.gridCellExtent,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 0.85,
          );
    return ColoredBox(
      color: c(theme.bg),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(pad),
            sliver: history.isEmpty && tasks.isEmpty
                ? SliverFillRemaining(child: _emptyState(theme, scale))
                : SliverGrid(
                    gridDelegate: gridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < tasks.length) {
                          return _TaskCard(
                            theme: theme,
                            task: tasks[index],
                          );
                        }
                        final hi = index - tasks.length;
                        final item = history[hi];
                        return _ImageCard(
                          key: ValueKey(item.id),
                          theme: theme,
                          item: item,
                          onExpand: () => widget.onPreview(hi),
                          onDelete: () =>
                              widget.onDelete(item.id, item.imagePath),
                        );
                      },
                      childCount: tasks.length + history.length,
                      addAutomaticKeepAlives: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _emptyState(AppTheme theme, AppScale scale) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: scale.dim(96),
          height: scale.dim(96),
          decoration: BoxDecoration(
            border: Border.all(
              color: c(theme.border),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(scale.dim(16)),
          ),
          child: Center(
            child: Text(
              '✦',
              style: TextStyle(
                fontSize: scale.sp(36),
                color: c(theme.textMuted).withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        SizedBox(height: scale.dim(16)),
        Text(
          '输入 Prompt 开始生成',
          style: TextStyle(
            color: c(theme.textMuted),
            fontSize: scale.sp(13),
          ),
        ),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.theme, required this.task});
  final AppTheme theme;
  final GenTask task;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        task.status == TaskStatus.error ? Colors.red : c(theme.accent);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: c(theme.accent).withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Shimmer(theme: theme)),
          Container(
            color: c(theme.surface),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.status == TaskStatus.queued)
                  Text(
                    '排队中...',
                    style: TextStyle(fontSize: 11, color: c(theme.textMuted)),
                  ),
                if (task.status == TaskStatus.running) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '生成中',
                        style: TextStyle(
                          fontSize: 11,
                          color: c(theme.accentGlow),
                        ),
                      ),
                      Text(
                        '${task.progress}%',
                        style:
                            TextStyle(fontSize: 11, color: c(theme.textMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress / 100,
                      minHeight: 4,
                      backgroundColor: c(theme.border),
                      color: c(theme.accentGlow),
                    ),
                  ),
                ],
                if (task.status == TaskStatus.error)
                  Text(
                    task.error ?? '生成失败',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.redAccent),
                  ),
                const SizedBox(height: 4),
                Text(
                  task.prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c(theme.textMuted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatefulWidget {
  const _ImageCard({
    super.key,
    required this.theme,
    required this.item,
    required this.onExpand,
    required this.onDelete,
  });

  final AppTheme theme;
  final HistoryItem item;
  final VoidCallback onExpand;
  final VoidCallback onDelete;

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  String? _displayPath;
  bool _confirmDelete = false;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _resolveThumb();
  }

  @override
  void didUpdateWidget(covariant _ImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imagePath != widget.item.imagePath) {
      _displayPath = null;
      _resolveThumb();
    }
  }

  Future<void> _resolveThumb() async {
    final gen = ++_loadGen;
    final path = widget.item.imagePath;
    final thumb = await ThumbnailService.instance.getThumbnailPath(path);
    if (!mounted || gen != _loadGen) return;
    setState(() => _displayPath = thumb ?? path);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // 网格格宽约 200~280，按 DPR 限制解码像素即可
    final cacheW = (280 * dpr).round().clamp(180, 560);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onExpand,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_displayPath != null)
                Image.file(
                  File(_displayPath!),
                  fit: BoxFit.cover,
                  cacheWidth: cacheW,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => _Shimmer(theme: widget.theme),
                )
              else
                _Shimmer(theme: widget.theme),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onExpand,
                    hoverColor: Colors.black26,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_confirmDelete)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '再次确认',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (_confirmDelete) const SizedBox(width: 4),
                            if (!isMobile) ...[
                              _ActionBtn(
                                icon: Icons.folder_open_outlined,
                                onTap: () => ImageService.instance
                                    .revealInFolder(widget.item.imagePath),
                              ),
                              const SizedBox(width: 4),
                            ],
                            _ActionBtn(
                              icon: Icons.delete_outline,
                              danger: _confirmDelete,
                              onTap: () {
                                if (!_confirmDelete) {
                                  setState(() => _confirmDelete = true);
                                  Future.delayed(
                                    const Duration(milliseconds: 2500),
                                    () {
                                      if (mounted) {
                                        setState(() => _confirmDelete = false);
                                      }
                                    },
                                  );
                                } else {
                                  widget.onDelete();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? Colors.red.withValues(alpha: 0.8) : Colors.white10,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.theme});
  final AppTheme theme;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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
