import '../../core/rename_engine.dart';
import '../file_source/file_source.dart';

/// folder ごとの**占有名**(005 spec `terms`: 占有名)。
///
/// 占有名 = 対象 folder の実在名 − **その folder 内で**この実行で改名される選択
/// file の現在名。除くのは、その名前がこの実行で空くからである。除かないと、
/// `IMG_0001..0100` を1つずらすような改名でほぼ全 file が自分たち自身の現在名と
/// 衝突し、ほぼ全件に ` (n)` が付く。
///
/// **REQ-022 で除外される file の現在名は改名されないので、占有名に含まれる**
/// (005 spec 例25c)。
///
/// **この型は全域である**(005 contract OP-001 / OP-002 の事前条件、OQ-003)。
/// [of] は key の無い folder に対して**例外を投げる** — 「key が無い」を「占有名が
/// 空」として黙って通すと、実在名を取得できなかった folder が「衝突が無い」と
/// 読まれてしまう(REQ-027)。生の `Map` を回すとその取り違えを型で防げないので、
/// 実行経路(`planExecution` / `executePlan`)はこの型だけを受け取る。
class OccupiedNames {
  /// [byFolder] の key に含まれる folder についてのみ全域な占有名。
  OccupiedNames(Map<String?, Set<String>> byFolder)
    : _byFolder = {
        for (final entry in byFolder.entries)
          entry.key: Set.unmodifiable(entry.value),
      };

  /// [folders] について**占有名が空である**ことを明示する(全域)。
  ///
  /// 「まだ取得していない」ではなく「取得した結果、占有している名前が無い」を表す。
  /// 空フォルダと、占有名を用いない検証で使う。
  factory OccupiedNames.emptyFor(Iterable<String?> folders) =>
      OccupiedNames({for (final folder in folders) folder: const {}});

  final Map<String?, Set<String>> _byFolder;

  /// [folder] の占有名。**key が無ければ例外を投げる**(OQ-003)。
  Set<String> of(String? folder) {
    final names = _byFolder[folder];
    if (names == null) {
      throw ArgumentError.value(
        folder,
        'folder',
        'この folder の占有名が与えられていません。occupiedNames は対象となる '
            'すべての folder について値を持たなければなりません'
            '(005 contract OP-001 / OP-002 の事前条件)',
      );
    }
    return names;
  }

  /// [folder] の占有名を持っているか。
  bool covers(String? folder) => _byFolder.containsKey(folder);

  /// 001 の `validate` / `autoResolve` へ渡す形(001 REQ-015)。
  ///
  /// 001 は与えられなかった folder を空として扱う純粋関数なので、全域性の保証は
  /// こちら側に残る。
  Map<String?, Set<String>> get asMap => Map.unmodifiable(_byFolder);

  @override
  String toString() => 'OccupiedNames($_byFolder)';
}

/// [collectOccupiedNames] の結果(005 contract OP-005)。
sealed class OccupiedNamesResult {
  const OccupiedNamesResult();
}

/// 対象 folder の実在名をすべて取得でき、占有名を組み立てられた。
class OccupiedNamesReady extends OccupiedNamesResult {
  const OccupiedNamesReady(this.names);

  /// 対象 folder について全域な占有名。
  final OccupiedNames names;
}

/// 1つ以上の folder で実在名を取得できなかった(REQ-027)。
///
/// **このとき実行は行われない。** 「取得できなかった」を「衝突が無い」と読まない。
class OccupiedNamesUnavailable extends OccupiedNamesResult {
  OccupiedNamesUnavailable(Map<String?, PickError> reasons)
    : reasons = Map.unmodifiable(reasons);

  /// 取得できなかった folder → その理由。
  final Map<String?, PickError> reasons;
}

/// 実在名の供給元(004 REQ-014 の `FileSource.listNames`)。
///
/// 005 は `FileSource` 全体ではなくこの1操作だけに依存する。
typedef FolderNameLister = Future<NameListResult> Function(String folder);

/// 対象 folder の実在名を集めて占有名を組み立てる(005 contract OP-005)。
///
/// 対象 folder は**この実行で改名される選択 file** が属する folder だけである。
/// 未選択 file しか無い folder は改名の行き先にならないので問い合わせない。
///
/// [entries] は現在の一覧のすべての file(選択状態を [FileEntry.selected] に写した
/// もの)。[rule] と [now] は REQ-022 の除外(生成後ベース名が空になる file)を
/// 判別するために使う — **除外される file は改名されないので、その現在名は占有名に
/// 含まれる**。
///
/// 実体ハンドルを持たない file(起動時の UI サンプル)は改名の対象にならないため
/// 対象 folder に数えない。
///
/// 1つでも実在名を取得できなければ [OccupiedNamesUnavailable] を返す(REQ-027)。
/// **空の列挙結果と同一視しない** — 004 が型で区別している(`NamesListed` /
/// `NameListFailed`)。
Future<OccupiedNamesResult> collectOccupiedNames({
  required List<FileEntry> entries,
  required RenameRule rule,
  required DateTime now,
  required FolderNameLister listNames,
}) async {
  // この実行で改名される選択 file(REQ-022 の除外後)。
  final renamed = <FileEntry>[];
  for (final preview in generatePreview(rule, entries, now)) {
    final file = preview.source;
    if (file.sourceHandle == null) continue;
    if (_hasEmptyBase(file, preview.resultName)) continue;
    renamed.add(file);
  }

  final byFolder = <String?, Set<String>>{};
  final reasons = <String?, PickError>{};
  // 同じ folder を二度問い合わせない。順序は再現できるよう出現順にする。
  final targets = <String?>[];
  for (final file in renamed) {
    if (!targets.contains(file.sourceFolder)) targets.add(file.sourceFolder);
  }

  for (final folder in targets) {
    if (folder == null) {
      // 実体ハンドルはあるのに所属 folder が無い。実在名を問い合わせる先が無いので
      // 「取得できなかった」として扱う(REQ-027)。**空として通さない。**
      reasons[folder] = const PickError(
        PickErrorKind.unknown,
        '所属フォルダが分からないため、そのフォルダのファイル名を確認できません',
      );
      continue;
    }
    final result = await listNames(folder);
    switch (result) {
      case NamesListed(:final names):
        // 占有名 = 実在名 − この folder で改名される選択 file の現在名。
        byFolder[folder] = {...names}
          ..removeAll([
            for (final file in renamed)
              if (file.sourceFolder == folder) file.name,
          ]);
      case NameListFailed(:final error):
        reasons[folder] = error;
    }
  }

  if (reasons.isNotEmpty) return OccupiedNamesUnavailable(reasons);
  return OccupiedNamesReady(OccupiedNames(byFolder));
}

/// 生成後ベース名(拡張子を除く)が空になるか(005 REQ-022)。
bool _hasEmptyBase(FileEntry file, String resultName) {
  final extension = file.extension;
  return extension.isEmpty ? resultName.isEmpty : resultName == '.$extension';
}
