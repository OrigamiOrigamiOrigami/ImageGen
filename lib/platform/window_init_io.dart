import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'is_desktop.dart';

Future<void> initWindowIfDesktop({Color? backgroundColor}) async {
  if (!isDesktop) return;

  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: const Size(1280, 800),
    minimumSize: const Size(900, 600),
    center: true,
    // 与当前主题 bg 一致，避免无边框窗口边缘露出底色
    backgroundColor: backgroundColor ?? const Color(0xFF0A0A0F),
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> syncWindowBackground(Color color) async {
  if (!isDesktop) return;
  await windowManager.setBackgroundColor(color);
}
