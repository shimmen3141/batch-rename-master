// repository 固有の検査を、CI が必ず走らせる `flutter test` から呼ぶ。
//
// `.github/workflows/ci.yml` は format / analyze / test だけを走らせる(このrepoの
// 規約により workflow の変更は人間の作業である)。**そのため、手で走らせるしかない
// 検査は `dev` 上で黙って腐る。** 独立review attempt 6 の指摘。
//
// ここから呼べば workflow を触らずに閉じられる。**検査そのものの中身は各 script の
// docstring が正本**で、ここは「CI で必ず走ること」だけを保証する。
@Tags(['tooling'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const checks = {
    '規範の書き写し': 'tool/check_normative_terms.py',
    'OS判定の境界': 'tool/check_platform_boundary.py',
  };

  checks.forEach((name, script) {
    test('$name — `python3 $script` が PASS する', () {
      final result = Process.runSync('python3', [script]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });
  });
}
