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

/// ドライラン検証(OP-003 / REQ-007〜009)。実行はせず警告のみを返す。
///
/// 最終名集合 = 未選択ファイルの現在名 ∪ 選択ファイルの生成後名。選択ファイルの
/// 生成後名がこの集合で2回以上出現すれば重複([DuplicateWarning])。連番トークンが
/// 選択数に対して桁不足なら [DigitShortageWarning]。生成後ベース名が空なら
/// [EmptyNameWarning]。該当が無い箇所については警告を含めない。
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

  // 重複・空名は選択ファイル(プレビュー)ごとに判定する。
  for (final entry in preview) {
    if ((counts[entry.resultName] ?? 0) >= 2) {
      warnings.add(
        DuplicateWarning(file: entry.source, resultName: entry.resultName),
      );
    }
    if (_hasEmptyBase(entry)) {
      warnings.add(EmptyNameWarning(entry.source));
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
