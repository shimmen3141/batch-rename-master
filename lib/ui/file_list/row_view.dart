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

/// この行で**名前が変わらない**か(005 用語「変更が生じるファイル」の否定)。
///
/// **`008:T20` でここへ移した。** 提示(`file_list_view.dart`)と実行の門
/// (`RenameExecutionController.execute`)が**同じ判定を使う**必要があるためである。
/// 005 REQ-019 は「buttonだけ無効にして別経路から実体を変更できる実装」を排除して
/// おり、2つの層が別々の定義を持つとその排除が成り立たない。
///
/// 次のいずれかで真になる。
///
/// - **ルールが空**。生成後名は拡張子だけの名前になるが、005 REQ-019 により
///   実行が始まらないので実体は変わらない。
/// - 生成後名が現在名と**同じ**。
/// - **空名で改名の対象にならない**(005 REQ-022)。この行は自動解決の前の
///   生成後名がベース名を持たず、改名されない。
///
/// **未選択行はここに含めない** — プレビュー対象外であって「変わらない」のとは違う。
bool rowHasNoChange(RowView row, {required bool ruleIsEmpty}) {
  final newName = row.newName;
  if (newName == null) return false;
  if (ruleIsEmpty) return true;
  if (newName == row.currentName) return true;
  return row.warnings.whereType<EmptyNameWarning>().isNotEmpty;
}
