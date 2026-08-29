import '../../core/rename_engine.dart';

/// リスト1行分の表示データ(002 spec: 行データ)。
///
/// 現在名と変更後名(001 のプレビュー結果)を1行として供給する。
/// 未選択行は [newName] を持たない(`null` = プレビュー対象外。REQ-007)。
class RowView {
  /// 元ファイル(表示順に対応)。
  final FileEntry source;

  /// 現在のファイル名(= [FileEntry.name]。REQ-001)。
  final String currentName;

  /// 変更後のフルネーム。未選択行は `null`(REQ-006 / REQ-007)。
  final String? newName;

  /// この行が選択されているか。
  final bool selected;

  /// この行の item を**対象とする** 001 の検証警告(002 REQ-015)。
  ///
  /// **ルール全体への警告(連番の桁不足)は含まない。** [DigitShortageWarning] は
  /// 対象ファイルを持たず、特定の行に帰属しないためである([warningTargetOf])。
  /// 該当が無ければ空。**提示方法は 005 が定める**(場所は自由。005 revision 8.0)。
  final List<Warning> warnings;

  const RowView({
    required this.source,
    required this.currentName,
    required this.newName,
    required this.selected,
    this.warnings = const <Warning>[],
  });

  /// 変更後名を持つ(選択されプレビュー対象である)か。
  bool get hasNewName => newName != null;
}

/// [warning] が対象とするファイル。**ルール全体への警告なら `null`**(002 REQ-015)。
///
/// 001 の [DigitShortageWarning] はルール内の連番トークンに対する警告で、
/// `file` を持たない。行データへ載せるには 001 の判定を変えることになるため、
/// **ここで行から外す**(008:T15 の決定。判定は 001 のまま)。
FileEntry? warningTargetOf(Warning warning) => switch (warning) {
  DuplicateWarning(:final file) => file,
  EmptyNameWarning(:final file) => file,
  MissingSourceDateWarning(:final file) => file,
  DigitShortageWarning() => null,
};
