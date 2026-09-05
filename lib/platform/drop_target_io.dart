import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'drop_target_wrap.dart';
import 'is_desktop.dart';

const _imageExts = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot < 0) return false;
  return _imageExts.contains(lower.substring(dot));
}

Widget wrapDropTarget({
  required Widget child,
  required ValueChanged<bool> onDragging,
  required DropDoneCallback onDrop,
}) {
  if (!isDesktop) return child;
  return DropTarget(
    onDragEntered: (_) => onDragging(true),
    onDragExited: (_) => onDragging(false),
    onDragDone: (detail) async {
      onDragging(false);
      final paths = detail.files
          .map((f) => f.path)
          .where((p) => p.isNotEmpty && _isImagePath(p))
          .toList(growable: false);
      if (paths.isEmpty) return;
      await onDrop(paths);
    },
    child: child,
  );
}
