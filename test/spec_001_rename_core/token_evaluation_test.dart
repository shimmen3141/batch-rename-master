// VER-001: トークン評価と名前組み立ての検証(FEAT-001)。
// 対象: REQ-001(元名/分割), REQ-002(リテラル), REQ-003(連番), REQ-004(日時),
//       REQ-005(組み立て+拡張子), INV-002(拡張子不変), OP-001(buildName)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
);

final DateTime _now = DateTime(2026, 7, 26, 9, 8, 7);

void main() {
  group('REQ-001: ベース名/拡張子の分割', () {
    const cases = <(String, String, String)>[
      ('photo.jpg', 'photo', 'jpg'), // 通常
      ('.gitignore', '.gitignore', ''), // 先頭ドットは境界としない(例5)
      ('archive.tar.gz', 'archive.tar', 'gz'), // 最後のドットのみ(例6)
      ('noext', 'noext', ''), // ドットなし
    ];
    for (final (name, base, ext) in cases) {
      test('$name -> base=$base ext=$ext', () {
        final f = _file(name);
        expect(f.baseName, base);
        expect(f.extension, ext);
      });
    }
  });

  group('REQ-001 + REQ-005 + INV-002: 元名トークンと拡張子温存', () {
    const rule = RenameRule([OriginalNameToken()]);
    test('例1: [元名] photo.jpg -> photo.jpg', () {
      expect(buildName(rule, _file('photo.jpg'), 1, _now), 'photo.jpg');
    });
    test('例5: [元名] .gitignore -> .gitignore', () {
      expect(buildName(rule, _file('.gitignore'), 1, _now), '.gitignore');
    });
    test('例6: [元名] archive.tar.gz -> archive.tar.gz', () {
      expect(
        buildName(rule, _file('archive.tar.gz'), 1, _now),
        'archive.tar.gz',
      );
    });
    test('拡張子なしファイルにドットを付けない', () {
      expect(buildName(rule, _file('noext'), 1, _now), 'noext');
    });
  });

  group('REQ-002: リテラルトークン(区切り記号を含む)', () {
    test('リテラル + 区切り + 元名', () {
      const rule = RenameRule([
        LiteralToken('IMG'),
        LiteralToken('_'),
        OriginalNameToken(),
      ]);
      expect(buildName(rule, _file('a.png'), 1, _now), 'IMG_a.png');
    });

    test('ハイフン/アンダーバー/スペースはリテラルとして出力される', () {
      for (final sep in const ['-', '_', ' ']) {
        final rule = RenameRule([
          const OriginalNameToken(),
          LiteralToken(sep),
          const LiteralToken('x'),
        ]);
        expect(buildName(rule, _file('a.txt'), 1, _now), 'a${sep}x.txt');
      }
    });

    test('空リテラルのみのルールはベース名が空になる(拡張子は温存)', () {
      const rule = RenameRule([LiteralToken('')]);
      expect(buildName(rule, _file('a.jpg'), 1, _now), '.jpg');
    });
  });

  group('INV-002 性質: 任意の元名/リテラル・ルールで拡張子が変化しない', () {
    const names = ['a.jpg', 'b.PNG', 'c', 'd.tar.gz', '.env'];
    final rules = <RenameRule>[
      const RenameRule([OriginalNameToken()]),
      const RenameRule([
        LiteralToken('X'),
        OriginalNameToken(),
        LiteralToken('_end'),
      ]),
      const RenameRule([LiteralToken('fixed')]),
    ];
    test('出力は元ファイルの拡張子で終わる(拡張子が空の場合はドットを付けない)', () {
      for (final n in names) {
        final f = _file(n);
        for (final r in rules) {
          final out = buildName(r, f, 1, _now);
          if (f.extension.isEmpty) {
            expect(
              out.endsWith('.'),
              isFalse,
              reason: '$n: 拡張子が空なのに末尾ドットが付いた ($out)',
            );
          } else {
            expect(
              out.endsWith('.${f.extension}'),
              isTrue,
              reason: '$n: 出力 $out が .${f.extension} で終わらない',
            );
          }
        }
      }
    });
  });

  group('OP-001: buildName は position/now に依存せず(元名/リテラルのみでは)決定的', () {
    test('同一入力で同一出力', () {
      const rule = RenameRule([LiteralToken('n'), OriginalNameToken()]);
      final f = _file('a.jpg');
      expect(buildName(rule, f, 1, _now), buildName(rule, f, 1, _now));
    });
    test('元名/リテラルのみのルールは position が変わっても同じ', () {
      const rule = RenameRule([OriginalNameToken()]);
      final f = _file('a.jpg');
      expect(buildName(rule, f, 1, _now), buildName(rule, f, 99, _now));
    });
  });

  group('REQ-003: 連番トークン', () {
    test('例2: [IMG][_][連番 開始1 桁3] a.png position5 -> IMG_005.png', () {
      const rule = RenameRule([
        LiteralToken('IMG'),
        LiteralToken('_'),
        SequenceToken(start: 1, digits: 3),
      ]);
      expect(buildName(rule, _file('a.png'), 5, _now), 'IMG_005.png');
    });
    test('ゼロ埋め: 開始1 桁2 position1 -> 01', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 2)]);
      expect(buildName(rule, _file('a'), 1, _now), '01');
    });
    test('増分: 開始10 増分5 桁1 position3 -> 20', () {
      const rule = RenameRule([
        SequenceToken(start: 10, digits: 1, increment: 5),
      ]);
      expect(buildName(rule, _file('a'), 3, _now), '20');
    });
    test('桁超過は切り詰めない: 開始1 桁2 position100 -> 100(桁不足検出は T5)', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 2)]);
      expect(buildName(rule, _file('a'), 100, _now), '100');
    });
    test('valueAt: 開始1 増分1 は position に等しい', () {
      const token = SequenceToken(start: 1, increment: 1);
      expect(token.valueAt(1), 1);
      expect(token.valueAt(7), 7);
    });
  });

  group('REQ-004: 日時トークン', () {
    // _now = 2026-07-26 09:08:07
    test('例3: 現在 YYYYMMDD -> 20260726', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.current, format: 'YYYYMMDD'),
      ]);
      expect(buildName(rule, _file('x.txt'), 1, _now), '20260726.txt');
    });
    test('例4: 現在 YY-MM-DD_HHmmss -> 26-07-26_090807', () {
      const rule = RenameRule([
        DateTimeToken(
          source: DateTimeSource.current,
          format: 'YY-MM-DD_HHmmss',
        ),
      ]);
      expect(buildName(rule, _file('x.txt'), 1, _now), '26-07-26_090807.txt');
    });
    test('非該当文字はリテラル: YYYY年MM月DD日 -> 2026年07月26日', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.current, format: 'YYYY年MM月DD日'),
      ]);
      expect(buildName(rule, _file('x'), 1, _now), '2026年07月26日');
    });
    test('大小区別: MMmm(月と分) -> 0708', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.current, format: 'MMmm'),
      ]);
      expect(buildName(rule, _file('x'), 1, _now), '0708');
    });
    test('最長一致: YYYYMM -> 202607(YY に食われない)', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.current, format: 'YYYYMM'),
      ]);
      expect(buildName(rule, _file('x'), 1, _now), '202607');
    });
    test('基準=作成日時', () {
      final f = FileEntry(
        name: 'x.txt',
        createdAt: DateTime(2020, 3, 4),
        modifiedAt: DateTime(2021, 5, 6),
        size: 0,
      );
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]);
      expect(buildName(rule, f, 1, _now), '20200304.txt');
    });
    test('基準=更新日時', () {
      final f = FileEntry(
        name: 'x.txt',
        createdAt: DateTime(2020, 3, 4),
        modifiedAt: DateTime(2021, 5, 6),
        size: 0,
      );
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.modified, format: 'YYYYMMDD'),
      ]);
      expect(buildName(rule, f, 1, _now), '20210506.txt');
    });
    test('YY はゼロ埋め: 2005 -> 05', () {
      final f = FileEntry(
        name: 'x',
        createdAt: DateTime(2005, 1, 1),
        modifiedAt: DateTime(2005, 1, 1),
        size: 0,
      );
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YY'),
      ]);
      expect(buildName(rule, f, 1, _now), '05');
    });
  });
}
