import 'package:flutter/material.dart';

/// 界面缩放：自动随窗口变大，或固定 100%～150%
enum UiScalePreset {
  auto('auto', '自动'),
  p100('100', '100%'),
  p115('115', '115%'),
  p125('125', '125%'),
  p150('150', '150%');

  const UiScalePreset(this.storage, this.label);
  final String storage;
  final String label;

  static UiScalePreset fromStorage(String? v) {
    if (v == null || v.isEmpty) return UiScalePreset.auto;
    return UiScalePreset.values.firstWhere(
      (e) => e.storage == v,
      orElse: () => UiScalePreset.auto,
    );
  }
}

/// 以默认窗口 1280×800 为基准，全屏时放大字号与控件
class AppScale {
  AppScale._(this.value, this.windowSize);

  final double value;
  final Size windowSize;

  static const _designW = 1280.0;
  static const _designH = 800.0;

  static AppScale of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_AppScaleInherited>();
    if (inherited != null) return inherited.scale;
    return compute(MediaQuery.sizeOf(context), UiScalePreset.auto);
  }

  static AppScale compute(Size size, UiScalePreset preset) {
    final wRatio = size.width / _designW;
    final hRatio = size.height / _designH;
    var auto = wRatio < hRatio ? wRatio : hRatio;
    auto = auto.clamp(1.0, 1.85);

    final v = switch (preset) {
      UiScalePreset.auto => auto,
      UiScalePreset.p100 => 1.0,
      UiScalePreset.p115 => 1.15,
      UiScalePreset.p125 => 1.25,
      UiScalePreset.p150 => 1.5,
    };
    return AppScale._(v, size);
  }

  double sp(double logical) => logical * value;
  double dim(double logical) => logical * value;

  /// 底部输入区最大宽度：宽屏时随窗口变宽
  bool get isCompact => windowSize.width < 600;

  double get promptMaxWidth {
    if (isCompact) return double.infinity;
    final w = windowSize.width;
    if (w <= _designW) return dim(900);
    final grown = 900 + (w - _designW) * 0.45;
    return grown.clamp(900, 1400) * value.clamp(1.0, 1.5);
  }

  int get promptMinLines =>
      isCompact ? 1 : (3 * value).round().clamp(3, 6);

  int get promptMaxLines {
    if (isCompact) return 4;
    final lineH = sp(22);
    return (windowSize.height * 0.28 / lineH).round().clamp(5, 18);
  }

  double get promptBarPadding => isCompact ? 10 : dim(16);

  double get gridCellExtent => dim(320).clamp(280, 520);

  /// 手机端网格列数（窄屏 2 列，稍宽 3 列）
  int get gridCrossAxisCount {
    if (!isCompact) return 0;
    return windowSize.width < 400 ? 2 : 3;
  }
}

class AppScaleScope extends StatelessWidget {
  const AppScaleScope({
    super.key,
    required this.preset,
    required this.child,
  });

  final UiScalePreset preset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final scale = AppScale.compute(size, preset);
    return _AppScaleInherited(
      scale: scale,
      preset: preset,
      child: MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(scale.value)),
        child: child,
      ),
    );
  }
}

class _AppScaleInherited extends InheritedWidget {
  const _AppScaleInherited({
    required this.scale,
    required this.preset,
    required super.child,
  });

  final AppScale scale;
  final UiScalePreset preset;

  @override
  bool updateShouldNotify(_AppScaleInherited old) =>
      scale.value != old.scale.value || preset != old.preset;
}

extension AppScaleContext on BuildContext {
  AppScale get appScale => AppScale.of(this);
}
