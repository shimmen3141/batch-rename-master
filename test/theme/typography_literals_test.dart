// 文字の大きさは theme の段(`AppFontSize`)から取る(`008:T10`)。
//
// 2026-10-01 の開発者の決定で、値は変えずに名前だけ付けて theme へ寄せた。画面側へ
// 数字の直書きが戻ると、段を変えたときにその箇所だけ取り残される。
import 'dart:io';

import 'package:batch_rename_master/ui/theme/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ui の fontSize は数字を直書きしない(008:T10)', () {
    final literal = RegExp(r'fontSize:\s*[0-9]');
    final offenders = <String>[];
    for (final entity in Directory('lib/ui').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_typography.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('段は小さい順に並び、名前を付ける前の10種類と見出しの値を保つ(008:T10)', () {
    // 値を変えないという決定の検査。段を寄せるときは、この期待値を決定と一緒に直す。
    expect(
      [
        AppFontSize.micro,
        AppFontSize.tiny,
        AppFontSize.caption,
        AppFontSize.small,
        AppFontSize.label,
        AppFontSize.bodySmall,
        AppFontSize.body,
        AppFontSize.bodyLarge,
        AppFontSize.title,
        AppFontSize.titleLarge,
        AppFontSize.heading,
      ],
      [9, 10, 10.5, 11, 11.5, 12, 12.5, 13, 14, 15, 16],
    );
  });
}
