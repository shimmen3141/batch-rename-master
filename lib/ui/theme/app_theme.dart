import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 参考デザイン準拠のダークテーマ。[AppColors.dark] をセマンティックカラーとして
/// [ThemeData.extensions] に載せ、`context.colors` から参照できるようにする。
ThemeData appDarkTheme() {
  const c = AppColors.dark;
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    colorScheme: base.colorScheme.copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: c.danger,
    ),
    extensions: const <ThemeExtension<dynamic>>[c],
  );
}
