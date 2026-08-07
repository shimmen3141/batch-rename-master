// CON-001: 実行計画の立案と実行オーケストレーションは `package:flutter` および
// `dart:io` に依存してはならない。実ファイルへの作用は改名ポートの実装だけが持つ。
//
// 実装(T5)がプラットフォーム固有のファイルを同じディレクトリへ足しても壊れない
// よう、対象は計画・実行・ポート定義の3ファイルに限って検査する。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'lib/data/rename_exec/rename_plan.dart',
  'lib/data/rename_exec/rename_execution.dart',
  'lib/data/rename_exec/rename_executor.dart',
];

void main() {
  test('計画立案と実行は flutter / dart:io に依存しない(CON-001)', () {
    for (final path in _files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path が無い');

      final imports = file
          .readAsLinesSync()
          .where((l) => l.startsWith('import ') || l.startsWith('export '))
          .toList();

      expect(
        imports.where((l) => l.contains('package:flutter')),
        isEmpty,
        reason: '$path が package:flutter に依存している',
      );
      expect(
        imports.where((l) => l.contains("dart:io")),
        isEmpty,
        reason: '$path が dart:io に依存している',
      );
    }
  });
}
