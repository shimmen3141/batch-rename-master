import 'file_entry.dart';

/// トークン評価に必要な文脈。
///
/// エンジンは時計を参照せず、現在日時は [now] として受け取る(INV-004)。
class RenameContext {
  /// 評価対象のファイル。
  final FileEntry file;

  /// 選択順位(1始まり)。連番トークンが使用する(REQ-003)。
  final int position;

  /// 現在日時。日時トークンの基準「現在日時」で使用する(REQ-004)。
  final DateTime now;

  const RenameContext({
    required this.file,
    required this.position,
    required this.now,
  });
}

/// 命名ルールの構成要素(REQ-001〜004)。
///
/// sealed とし、取りうるトークン種別を型として閉じる(ドメインモデル完全性)。
/// 元名・リテラル・連番・日時の4種を本ファイルに定義する。
sealed class Token {
  const Token();

  /// このトークンが生成する文字列を返す。
  String render(RenameContext ctx);
}

/// 元名トークン: 対象ファイルのベース名(拡張子を除く)を出力する(REQ-001)。
class OriginalNameToken extends Token {
  const OriginalNameToken();

  @override
  String render(RenameContext ctx) => ctx.file.baseName;
}

/// リテラルトークン: 設定文字列をそのまま出力する(REQ-002)。
///
/// 区切り記号(ハイフン・アンダーバー・スペース)も独立トークンにせず、
/// このリテラルトークンとして扱う(決定事項 2026-07-26)。
class LiteralToken extends Token {
  /// 出力する固定文字列。
  final String value;

  const LiteralToken(this.value);

  @override
  String render(RenameContext ctx) => value;
}

/// 連番トークン: 選択順位に応じた通し番号を出力する(REQ-003)。
///
/// 値 = [start] + (position - 1) × [increment] を、[digits] 桁まで左を `0` で
/// 埋めた10進文字列で出力する。値が [digits] 桁に収まらない場合は切り詰めず
/// そのまま出力する(桁不足の検出・拡張は検証/自動解決 = T5/T6 の担当)。
class SequenceToken extends Token {
  /// 開始番号(position=1 のときの値)。
  final int start;

  /// ゼロ埋めの桁数。
  final int digits;

  /// position が1増えるごとの増分。
  final int increment;

  const SequenceToken({this.start = 1, this.digits = 1, this.increment = 1});

  /// 指定した選択順位 [position](1始まり)における通し番号の値。
  int valueAt(int position) => start + (position - 1) * increment;

  @override
  String render(RenameContext ctx) =>
      valueAt(ctx.position).toString().padLeft(digits, '0');
}

/// 日時トークンの基準(REQ-004)。
enum DateTimeSource {
  /// ファイルの作成日時。
  created,

  /// ファイルの更新日時。
  modified,

  /// 現在日時([RenameContext.now])。
  current,
}

/// 日時トークン: 基準日時を書式で整形して出力する(REQ-004)。
///
/// 書式記号 `YYYY`(4桁年)・`YY`(2桁年)・`MM`(2桁月)・`DD`(2桁日)・
/// `HH`(2桁時, 24時制)・`mm`(2桁分)・`ss`(2桁秒)をゼロ埋め固定幅で展開する。
/// 走査は左から最長一致で行い、記号に一致しない文字はそのまま出力する。
/// 記号は大文字小文字を区別する(`MM`=月 / `mm`=分)。
class DateTimeToken extends Token {
  /// 整形する基準日時の種別。
  final DateTimeSource source;

  /// 書式文字列。
  final String format;

  const DateTimeToken({required this.source, required this.format});

  /// [file] と [now] に対する基準日時。**取得できない場合は `null`**(REQ-004)。
  ///
  /// 基準が作成日時で [FileEntry.createdAt] が不明なときだけ `null` になる。
  /// 更新日時・現在日時は常に値を持つ。取得不能を別の日時で代替しない(INV-006)。
  DateTime? baseDateOf(FileEntry file, DateTime now) => switch (source) {
    DateTimeSource.created => file.createdAt,
    DateTimeSource.modified => file.modifiedAt,
    DateTimeSource.current => now,
  };

  @override
  String render(RenameContext ctx) {
    final base = baseDateOf(ctx.file, ctx.now);
    // 基準日時が取得不能なら空文字列(REQ-004)。別の日時で代替しない(INV-006)。
    return base == null ? '' : _formatDateTime(base, format);
  }
}

/// 日時 [dt] を [format] で整形する(REQ-004)。左から最長一致で走査する。
String _formatDateTime(DateTime dt, String format) {
  String two(int v) => v.toString().padLeft(2, '0');
  final wide = <String, String>{'YYYY': dt.year.toString().padLeft(4, '0')};
  final narrow = <String, String>{
    'YY': two(dt.year % 100),
    'MM': two(dt.month),
    'DD': two(dt.day),
    'HH': two(dt.hour),
    'mm': two(dt.minute),
    'ss': two(dt.second),
  };
  final buffer = StringBuffer();
  var i = 0;
  while (i < format.length) {
    if (i + 4 <= format.length) {
      final replacement = wide[format.substring(i, i + 4)];
      if (replacement != null) {
        buffer.write(replacement);
        i += 4;
        continue;
      }
    }
    if (i + 2 <= format.length) {
      final replacement = narrow[format.substring(i, i + 2)];
      if (replacement != null) {
        buffer.write(replacement);
        i += 2;
        continue;
      }
    }
    buffer.write(format[i]);
    i += 1;
  }
  return buffer.toString();
}
