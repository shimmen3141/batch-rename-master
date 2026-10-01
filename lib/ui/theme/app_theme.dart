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
    //
    // **見出しは低く小さくする**(`008:T10`。2026-09-02 の要望13「上部の『一括リネーム』
    // という見出しが幅を取っているので、小さくして…スペースを確保してもよさそう」)。
    // 既定の高さ 56・文字 22 から詰めたぶん、一覧が広くなる。見出しは消さない —
    // デスクトップでは歯車(`008:T43`)がここに載る。
    appBarTheme: AppBarTheme(
      backgroundColor: c.bar,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: appBarHeight,
      titleTextStyle: TextStyle(
        color: c.textPrimary,
        fontSize: appBarTitleFontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    extensions: const <ThemeExtension<dynamic>>[c],
  );
}

/// 上部の見出しの帯の高さと文字の大きさ(`008:T10` の要望13)。
const double appBarHeight = 44;
const double appBarTitleFontSize = 16;
