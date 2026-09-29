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
    // **ヘッダーはフッターと同じ固定の色**(`008:T42`。2026-09-29 の開発者の決定)。
    // 既定では一覧のスクロールでヘッダーだけが明るく紫がかり(surface tint)、
    // フッターと色が食い違った。
    appBarTheme: AppBarTheme(
      backgroundColor: c.bar,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    extensions: const <ThemeExtension<dynamic>>[c],
  );
}
