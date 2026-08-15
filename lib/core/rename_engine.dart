/// コア命名エンジン(FEAT-001)の公開 API。
///
/// UI・ファイルIO・プラットフォーム固有処理から分離した純粋 Dart 層。
/// `package:flutter` および `dart:io` に依存しない(CON-001 / INV-004)。
library;

import 'file_entry.dart';
import 'rename_rule.dart';
import 'token.dart';

export 'file_entry.dart';
export 'rename_rule.dart';
export 'token.dart';

/// 1ファイルの生成後フルネームを構成する(OP-001)。
///
/// ルール内のトークンを順に評価・連結し(REQ-001〜005)、対象ファイルの
/// 拡張子を後置する(拡張子が空でなければ先頭にドットを付ける、REQ-005)。
/// 拡張子は変更しない(INV-002)。
///
/// [position] は選択順位(1始まり)。事前条件として 1 以上でなければならない
/// (OP-001)。[now] は現在日時(INV-004)。
String buildName(RenameRule rule, FileEntry file, int position, DateTime now) {
  assert(position >= 1, 'position は 1 以上でなければならない(OP-001 事前条件)');
  final ctx = RenameContext(file: file, position: position, now: now);
  final base = rule.tokens.map((token) => token.render(ctx)).join();
  final ext = file.extension;
  return ext.isEmpty ? base : '$base.$ext';
}

/// プレビューの1エントリ(OP-002 の出力要素)。
class PreviewEntry {
  /// 元ファイル。
  final FileEntry source;

  /// [source] に対する生成後フルネーム。
  final String resultName;

  const PreviewEntry({required this.source, required this.resultName});
}

/// 選択・並び順を反映したプレビューを生成する(OP-002 / REQ-006)。
///
/// [files] のうち選択されたものだけを、入力の並び順を保ったまま対象とし、
/// 上から選択順位 1, 2, 3... を割り当てて各ファイルの生成後名を求める。
/// 未選択ファイルは結果に含めない。
List<PreviewEntry> generatePreview(
  RenameRule rule,
  List<FileEntry> files,
  DateTime now,
) {
  final result = <PreviewEntry>[];
  var position = 0;
  for (final file in files) {
    if (!file.selected) continue;
    position += 1;
    result.add(
      PreviewEntry(
        source: file,
        resultName: buildName(rule, file, position, now),
      ),
    );
  }
  return result;
}

/// ドライラン検証で検出した警告(OP-003)。
sealed class Warning {
  const Warning();
}

/// 生成後名が最終名集合の中で重複する(REQ-007)。
class DuplicateWarning extends Warning {
  /// 重複する生成後名を持つ選択ファイル。
  final FileEntry file;

  /// 衝突する生成後フルネーム。
  final String resultName;

  const DuplicateWarning({required this.file, required this.resultName});
}

/// 連番トークンの計算値が指定桁数に収まらない(REQ-008)。
class DigitShortageWarning extends Warning {
  /// ルール内での連番トークンの位置(0始まり)。
  final int tokenIndex;

  /// 桁不足を起こした連番トークン。
  final SequenceToken token;

  /// 最大の計算値を表すのに必要な桁数([SequenceToken.digits] より大きい)。
  final int requiredDigits;

  const DigitShortageWarning({
    required this.tokenIndex,
    required this.token,
    required this.requiredDigits,
  });
}

/// 生成後ベース名(拡張子を除く)が空になる(REQ-009)。
class EmptyNameWarning extends Warning {
  /// 生成後ベース名が空になる選択ファイル。
  final FileEntry file;

  const EmptyNameWarning(this.file);
}

/// 日時トークンの基準日時が取得不能(REQ-014)。
///
/// 基準が作成日時で、対象ファイルの作成日時が不明なときに生じる。該当トークンは
/// 空文字列を出力し(REQ-004)、更新日時・現在日時では代替しない(INV-006)。
class MissingSourceDateWarning extends Warning {
  /// 基準日時を取得できなかった選択ファイル。
  final FileEntry file;

  /// ルール内での日時トークンの位置(0始まり)。
  final int tokenIndex;

  /// 基準日時を取得できなかった日時トークン。
  final DateTimeToken token;

  const MissingSourceDateWarning({
    required this.file,
    required this.tokenIndex,
    required this.token,
  });
}

/// ドライラン検証(OP-003 / REQ-007〜009・REQ-014)。実行はせず警告のみを返す。
///
/// 最終名集合 = 未選択ファイルの現在名 ∪ 選択ファイルの生成後名。選択ファイルの
/// 生成後名がこの集合で2回以上出現すれば重複([DuplicateWarning])。連番トークンが
/// 選択数に対して桁不足なら [DigitShortageWarning]。生成後ベース名が空なら
/// [EmptyNameWarning]。日時トークンの基準日時が取得不能なら
/// [MissingSourceDateWarning]。該当が無い箇所については警告を含めない。
List<Warning> validate(RenameRule rule, List<FileEntry> files, DateTime now) {
  final warnings = <Warning>[];
  final preview = generatePreview(rule, files, now);

  // 最終名集合: 未選択ファイルの現在名 + 選択ファイルの生成後名。
  final counts = <String, int>{};
  for (final file in files) {
    if (!file.selected) {
      counts[file.name] = (counts[file.name] ?? 0) + 1;
    }
  }
  for (final entry in preview) {
    counts[entry.resultName] = (counts[entry.resultName] ?? 0) + 1;
  }

  // 重複・空名・基準日時不明は選択ファイル(プレビュー)ごとに判定する。
  for (final entry in preview) {
    if ((counts[entry.resultName] ?? 0) >= 2) {
      warnings.add(
        DuplicateWarning(file: entry.source, resultName: entry.resultName),
      );
    }
    if (_hasEmptyBase(entry)) {
      warnings.add(EmptyNameWarning(entry.source));
    }
    // 基準日時が取得不能な日時トークンごとに1件(REQ-014)。
    for (var i = 0; i < rule.tokens.length; i++) {
      final token = rule.tokens[i];
      if (token is DateTimeToken &&
          token.baseDateOf(entry.source, now) == null) {
        warnings.add(
          MissingSourceDateWarning(
            file: entry.source,
            tokenIndex: i,
            token: token,
          ),
        );
      }
    }
  }

  // 桁不足は連番トークンごとに、選択数に対する最大値で判定する。
  final count = preview.length;
  if (count > 0) {
    for (var i = 0; i < rule.tokens.length; i++) {
      final token = rule.tokens[i];
      if (token is SequenceToken) {
        final maxValue = _maxSequenceValue(token, count);
        final requiredDigits = _decimalDigits(maxValue);
        if (requiredDigits > token.digits) {
          warnings.add(
            DigitShortageWarning(
              tokenIndex: i,
              token: token,
              requiredDigits: requiredDigits,
            ),
          );
        }
      }
    }
  }

  return warnings;
}

/// プレビューエントリの生成後ベース名(拡張子を除く)が空かどうか(REQ-009)。
bool _hasEmptyBase(PreviewEntry entry) {
  final ext = entry.source.extension;
  return ext.isEmpty ? entry.resultName.isEmpty : entry.resultName == '.$ext';
}

/// 連番トークンが選択数 [count] に対して取りうる最大の計算値。
int _maxSequenceValue(SequenceToken token, int count) {
  final first = token.valueAt(1);
  final last = token.valueAt(count);
  return first > last ? first : last;
}

/// 整数 [value] を10進表記するのに必要な桁数(符号は数えない)。
int _decimalDigits(int value) {
  final magnitude = value.abs();
  return magnitude == 0 ? 1 : magnitude.toString().length;
}

/// 自動解決で確定した1エントリ(OP-004 の出力要素)。
class ResolvedEntry {
  /// 元ファイル。
  final FileEntry source;

  /// 衝突しない最終フルネーム。
  final String resultName;

  const ResolvedEntry({required this.source, required this.resultName});
}

/// 自動解決(OP-004 / REQ-010〜012 / INV-003)。強制実行時の最終名を確定する。
///
/// まず連番トークンの桁不足を、選択数に対する最大値が収まる桁数まで拡張する
/// (REQ-011)。次にプレビューを求め、最終名集合(未選択の現在名 + 確定済みの
/// 名前)で衝突する場合は、リスト表示順で最初の出現をそのまま残し、以降の衝突には
/// ベース名の末尾へ ' (n)'(n は1始まり)を付与して衝突しない最小の n を選ぶ
/// (REQ-010)。結果の最終名集合は重複と桁不足を含まない(REQ-012 / INV-003)。
List<ResolvedEntry> autoResolve(
  RenameRule rule,
  List<FileEntry> files,
  DateTime now,
) {
  final count = files.where((file) => file.selected).length;
  final expandedRule = RenameRule([
    for (final token in rule.tokens) _expandDigits(token, count),
  ]);
  final preview = generatePreview(expandedRule, files, now);

  // 未選択ファイルの現在名を既使用として初期化する(上書き防止)。
  final taken = <String>{
    for (final file in files)
      if (!file.selected) file.name,
  };

  final resolved = <ResolvedEntry>[];
  for (final entry in preview) {
    var candidate = entry.resultName;
    if (taken.contains(candidate)) {
      final ext = entry.source.extension;
      final base = ext.isEmpty
          ? entry.resultName
          : entry.resultName.substring(
              0,
              entry.resultName.length - ext.length - 1,
            );
      var n = 1;
      while (taken.contains(_withSuffix(base, n, ext))) {
        n += 1;
      }
      candidate = _withSuffix(base, n, ext);
    }
    taken.add(candidate);
    resolved.add(ResolvedEntry(source: entry.source, resultName: candidate));
  }
  return resolved;
}

/// 桁不足を起こす連番トークンの桁数を、最大値が収まる桁数まで拡張する(REQ-011)。
Token _expandDigits(Token token, int selectedCount) {
  if (token is! SequenceToken || selectedCount == 0) return token;
  final requiredDigits = _decimalDigits(
    _maxSequenceValue(token, selectedCount),
  );
  if (requiredDigits <= token.digits) return token;
  return SequenceToken(
    start: token.start,
    digits: requiredDigits,
    increment: token.increment,
  );
}

/// ベース名 [base] の末尾に ' (n)' を付与し、拡張子 [ext] を後置する(REQ-010)。
String _withSuffix(String base, int n, String ext) =>
    ext.isEmpty ? '$base ($n)' : '$base ($n).$ext';

/// フルネーム [fullName] の拡張子境界。[FileEntry] と同じ規則(REQ-001)。
///
/// 最後に出現するドット。ただし先頭文字のドットは境界としない。境界が無ければ `-1`。
int _extensionBoundary(String fullName) {
  final i = fullName.lastIndexOf('.');
  return i <= 0 ? -1 : i;
}

/// [fullName] が [taken] と衝突するとき、自動解決規則で次の候補名を返す
/// (005 contract revision 4 の REQ-023 が呼ぶ操作)。
///
/// [autoResolve] が選択集合の内側で行っている解決と**同じ接尾辞規則**である —
/// ベース名の末尾へ ` (n)` を付け、[taken] と衝突しない最小の n を選ぶ。005 は
/// 実行の途中で「その時点の生存名」に対して次候補を求める必要があり、
/// [autoResolve] のように選択集合から集合を組み立てる形では表現できない。
///
/// **拡張子境界の取り方だけは異なる。** [autoResolve] は元 file の
/// [FileEntry.extension] を使い、この関数は [fullName] の最後のドットで切る。
/// 拡張子の無い file に `my.file` のような名前を付けた場合、前者は
/// `my.file (1)`、後者は `my (1).file` になる。**実行時の再採番では元 file の
/// 拡張子ではなく、いま付けようとしている名前の見た目を保つほうが利用者の
/// 期待に近い**ので、この違いは意図したものである。
///
/// [limit] は探索する n の上限(005 contract の `open_questions` OQ-001)。
/// 上限内に空きが見つからなければ `null` を返す。呼び出し側はそれを失敗として
/// 扱う(REQ-023)。**無限に試さない。**
///
/// [fullName] 自身が [taken] に含まれない場合でも、この関数は必ず ` (n)` 付きの
/// **別の名前**を返す。衝突したから呼ばれる操作なので、同じ名前を返しても
/// 呼び出し側は同じ失敗を繰り返すだけである。
String? nextCandidateName(
  String fullName,
  Set<String> taken, {
  int limit = 10000,
}) {
  final boundary = _extensionBoundary(fullName);
  final base = boundary < 0 ? fullName : fullName.substring(0, boundary);
  final ext = boundary < 0 ? '' : fullName.substring(boundary + 1);
  for (var n = 1; n <= limit; n++) {
    final candidate = _withSuffix(base, n, ext);
    if (!taken.contains(candidate)) return candidate;
  }
  return null;
}
