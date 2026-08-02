import 'package:flutter/material.dart';

/// アプリのセマンティックカラー(意味で命名し再利用する)。
///
/// ウィジェットは生の色値を直接書かず、`context.colors.<役割>` から取得する。
/// 参考デザイン `docs/design/Bulk Renamer.html`(ダークテーマ・シアン基調)由来。
/// 色や細部は今後の調整で [dark] の値を差し替えれば全体へ反映される。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// アプリ背景(最下層)。
  final Color background;

  /// パネル・ツールバーなどの面。
  final Color surface;

  /// リスト行・カードなど一段持ち上がった面。
  final Color surfaceElevated;

  /// 面を仕切る細い境界線。
  final Color border;

  /// 主要アクセント(アクティブ・強調)。
  final Color primary;

  /// 主要アクセントのホバー/明色。
  final Color primaryHover;

  /// [primary] の上に載せる前景(文字・アイコン)。
  final Color onPrimary;

  /// 本文の第一文字色。
  final Color textPrimary;

  /// 補助的な第二文字色。
  final Color textSecondary;

  /// さらに控えめなラベル色。
  final Color textMuted;

  /// 無効・プレースホルダ相当の文字色。
  final Color textDisabled;

  /// 警告・エラー・重複などの危険色。
  final Color danger;

  /// 完了・良好・準備OK などの肯定色。
  final Color success;

  /// 情報・補助アクセント。
  final Color info;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.danger,
    required this.success,
    required this.info,
  });

  /// 参考デザイン準拠のダークテーマ配色。
  static const AppColors dark = AppColors(
    background: Color(0xFF0A0B0D),
    surface: Color(0xFF15181D),
    surfaceElevated: Color(0xFF191D23),
    border: Color(0x14FFFFFF),
    primary: Color(0xFF22D3EE),
    primaryHover: Color(0xFF67E8F9),
    onPrimary: Color(0xFF05252B),
    textPrimary: Color(0xFFEEF1F4),
    textSecondary: Color(0xFF8B939C),
    textMuted: Color(0xFF5B636C),
    textDisabled: Color(0xFF4D555E),
    danger: Color(0xFFF87171),
    success: Color(0xFF4ADE80),
    info: Color(0xFF3B82F6),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? primary,
    Color? primaryHover,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? danger,
    Color? success,
    Color? info,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// `context.colors.<役割>` で [AppColors] を取得するショートハンド。
extension AppColorsContext on BuildContext {
  /// 現在のテーマの [AppColors](未登録なら [AppColors.dark])。
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
