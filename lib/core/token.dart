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
/// 連番トークン・日時トークンは T3 で本ファイルに追加する。
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
