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
