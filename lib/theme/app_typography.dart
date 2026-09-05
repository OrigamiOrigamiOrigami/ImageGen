import 'package:flutter/material.dart';

/// 本地内嵌字体（见 [assets/fonts/README.md]）。
///
/// 默认 [MiSans]：无衬线、偏圆滑，中英文覆盖好，可免费商用。
class AppTypography {
  AppTypography._();

  /// 与 pubspec.yaml 里 `fonts.family` 一致
  static const String family = 'MiSans';

  /// 仅补缺字，避免优先落到雅黑（否则看起来像「字体没生效」）
  static const List<String> _cjkFallback = [
    'MiSans',
    'Segoe UI',
  ];

  static const List<String> _monoFallback = [
    'Consolas',
    'Cascadia Mono',
    'Courier New',
    'monospace',
  ];

  static TextStyle app({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: _cjkFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// 兼容旧调用
  static TextStyle wenHei({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      app(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextTheme bodyTextTheme(Brightness brightness) {
    final bodyColor = brightness == Brightness.dark
        ? const Color(0xFFE2E2F0)
        : const Color(0xFF1A1A2E);

    final base = ThemeData(brightness: brightness).textTheme;
    return base.apply(
      fontFamily: family,
      fontFamilyFallback: _cjkFallback,
      bodyColor: bodyColor,
      displayColor: bodyColor,
    );
  }

  static TextStyle brandTitle({required Color color, double size = 13}) {
    return app(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.2,
      color: color,
    );
  }

  static TextStyle brandSubtitle({required Color color}) {
    return app(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  static TextStyle mono({required Color color, double size = 12}) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  static ThemeData mergeInto(ThemeData theme) {
    final textTheme = bodyTextTheme(theme.brightness);
    return theme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }

  /// 包一层默认字体，保证只写了 color/fontSize 的 Text 也用 MiSans
  static Widget wrapDefaultTextStyle({
    required Widget child,
    required Brightness brightness,
  }) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFE2E2F0)
        : const Color(0xFF1A1A2E);
    return DefaultTextStyle(
      style: app(fontSize: 14, color: color),
      child: child,
    );
  }
}
