// VER-001: トークン評価と名前組み立ての検証(FEAT-001)。
// 対象: REQ-001(元名/分割), REQ-002(リテラル), REQ-005(組み立て+拡張子),
//       INV-002(拡張子不変), OP-001(buildName)。
// 連番・日時トークン(REQ-003/004)は T3 で本ファイルに追加する。
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
}
