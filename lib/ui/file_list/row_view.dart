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
  /// 重複・空名・基準日時不明は 001 が対象ファイルを持たせて返す([warningTargetOf])。
  /// **連番の桁不足は 001 が対象ファイルを持たないので、ここへ導出して載せる**
  /// (008:T17 で 002 REQ-015 を改訂した)。導出は次の2つを守る。
  ///
  /// - **001 が桁不足の警告を返しているときだけ**導出する。返していないなら
  ///   どの行にも載せない — **判定は 001 が持ち、行データが作らない。**
  /// - 返っているとき、該当する行は**必ず1件以上**ある。001 は選択件数における
  ///   最大値で判定するので、その値を持つ行が該当する。
  ///
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

/// [warning] が **001 のうえで**対象とするファイル。持たないなら `null`。
///
/// 001 の [DigitShortageWarning] はルール内の連番トークンに対する警告で `file` を
/// 持たない。**その対象は [sequenceOverflowsAt] で選択順位から導出する**
/// (008:T17 で 002 REQ-015 を改訂した。**001 の判定は変えていない**)。
FileEntry? warningTargetOf(Warning warning) => switch (warning) {
  DuplicateWarning(:final file) => file,
  EmptyNameWarning(:final file) => file,
  MissingSourceDateWarning(:final file) => file,
  DigitShortageWarning() => null,
};

/// 連番トークンが、選択順位 [position](1始まり)で**指定桁数を超えて描かれる**か
/// (002 REQ-015 の導出)。
///
/// [SequenceToken.render] は `valueAt(position).toString().padLeft(digits, '0')`
/// で、**埋めるだけで切り詰めない**。したがって「超えて描かれる」は、値の10進表記が
/// 桁数より長いことと同じである。
///
/// [position] は 001 の `generatePreview` と同じ数え方 — **選択されている行だけを
/// 表示順に 1 から数える**。未選択行を数えると桁がずれる。
bool sequenceOverflowsAt(SequenceToken token, int position) =>
    token.valueAt(position).toString().length > token.digits;
