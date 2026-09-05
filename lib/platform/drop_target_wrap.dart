import 'package:flutter/material.dart';

import 'drop_target_stub.dart'
    if (dart.library.io) 'drop_target_io.dart' as impl;

typedef DropDoneCallback = Future<void> Function(List<String> paths);

Widget wrapDropTarget({
  required Widget child,
  required ValueChanged<bool> onDragging,
  required DropDoneCallback onDrop,
}) {
  return impl.wrapDropTarget(
    child: child,
    onDragging: onDragging,
    onDrop: onDrop,
  );
}
