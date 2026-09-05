import 'package:flutter/material.dart';

import '../models/app_models.dart';

const List<AppTheme> appThemes = [
  AppTheme(
    id: ThemeId.darkPurple,
    name: '暗夜紫',
    dark: true,
    bg: 0xFF0A0A0F,
    surface: 0xFF111118,
    border: 0xFF1E1E2E,
    muted: 0xFF3F3F5A,
    text: 0xFFE2E2F0,
    textMuted: 0xFF6B6B8A,
    accent: 0xFF7C3AED,
    accentGlow: 0xFFA855F7,
    shadow: 'rgba(124, 58, 237, 0.4)',
  ),
  AppTheme(
    id: ThemeId.darkCyan,
    name: '暗夜青',
    dark: true,
    bg: 0xFF050F12,
    surface: 0xFF0A1A20,
    border: 0xFF0E2A35,
    muted: 0xFF1A4A5A,
    text: 0xFFE0F4F8,
    textMuted: 0xFF5A8A98,
    accent: 0xFF0891B2,
    accentGlow: 0xFF22D3EE,
    shadow: 'rgba(8, 145, 178, 0.4)',
  ),
  AppTheme(
    id: ThemeId.darkRose,
    name: '暗夜玫瑰',
    dark: true,
    bg: 0xFF0F080A,
    surface: 0xFF1A0E12,
    border: 0xFF2E1520,
    muted: 0xFF5A2535,
    text: 0xFFF0E0E4,
    textMuted: 0xFF8A5A65,
    accent: 0xFFE11D48,
    accentGlow: 0xFFFB7185,
    shadow: 'rgba(225, 29, 72, 0.4)',
  ),
  AppTheme(
    id: ThemeId.light,
    name: '白天',
    dark: false,
    bg: 0xFFF5F5F7,
    surface: 0xFFFFFFFF,
    border: 0xFFE0E0E8,
    muted: 0xFFC0C0D0,
    text: 0xFF1A1A2E,
    textMuted: 0xFF6B6B8A,
    accent: 0xFF7C3AED,
    accentGlow: 0xFFA855F7,
    shadow: 'rgba(124, 58, 237, 0.3)',
  ),
  AppTheme(
    id: ThemeId.lightWarm,
    name: '暖白',
    dark: false,
    bg: 0xFFFAF8F5,
    surface: 0xFFFFFFFF,
    border: 0xFFE8E0D8,
    muted: 0xFFD0C8C0,
    text: 0xFF2A1F1A,
    textMuted: 0xFF8A7A70,
    accent: 0xFFD97706,
    accentGlow: 0xFFFBBF24,
    shadow: 'rgba(217, 119, 6, 0.3)',
  ),
];

AppTheme getTheme(ThemeId id) {
  return appThemes.firstWhere(
    (t) => t.id == id,
    orElse: () => appThemes.first,
  );
}

Color c(int value) => Color(value);
