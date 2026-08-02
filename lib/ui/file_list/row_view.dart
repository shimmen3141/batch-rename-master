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

  const RowView({
    required this.source,
    required this.currentName,
    required this.newName,
    required this.selected,
  });

  /// 変更後名を持つ(選択されプレビュー対象である)か。
  bool get hasNewName => newName != null;
}
