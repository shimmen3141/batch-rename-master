/// 文字の大きさの段(`008:T10`)。画面側は `fontSize:` に数字を直書きせず、ここの名前を使う。
///
/// **値は変えずに名前だけ付けた**(2026-10-01 の開発者の決定)。参考design
/// (`docs/design/Bulk Renamer.html`)も 0.5px 刻みで使い分けており、近い値をまとめると
/// app 全体の見た目が少しずつ動くため。段を減らすときは、ここの値を寄せれば画面側は
/// 書き換えずに済む。
abstract final class AppFontSize {
  /// チップの種類名など、いちばん小さい補助の文字。
  static const double micro = 9;

  /// 小見出しの label(「命名ルール」など)。
  static const double tiny = 10;

  /// 行の補足情報・注記。
  static const double caption = 10.5;

  /// 小さい label・警告文。
  static const double small = 11;

  /// button の小さい文字・toast の補足。
  static const double label = 11.5;

  /// 補助の本文。
  static const double bodySmall = 12;

  /// 本文(やや小)。
  static const double body = 12.5;

  /// 本文。
  static const double bodyLarge = 13;

  /// 強調した本文・button の文字。
  static const double title = 14;

  /// ファイル名・チップの値など、主役の文字。
  static const double titleLarge = 15;

  /// 上部の見出し(要望13)。
  static const double heading = 16;
}
