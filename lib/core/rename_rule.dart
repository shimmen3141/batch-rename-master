import 'token.dart';

/// [Token] の順序付きリスト(INV-001)。
///
/// 任意の種別のトークンを任意個・任意の順序で含められる。UI 層(003)の
/// 追加・削除・並び替えを、モデルとして制約せずに支える。
class RenameRule {
  /// トークン列。先頭から順に評価・連結される。
  final List<Token> tokens;

  const RenameRule(this.tokens);

  /// 空のルール(トークンなし)。
  static const RenameRule empty = RenameRule(<Token>[]);
}
