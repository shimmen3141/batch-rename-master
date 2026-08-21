// VER-004: 自動解決の検証(FEAT-001)。
// 対象: REQ-010(重複回避 (n)), REQ-011(桁自動拡張), REQ-012/INV-003(結果は
//       重複・桁不足なし), REQ-015(占有名を避ける), OP-004(autoResolve)。
//
// **判定(validate)だけでなく解決(autoResolve)も占有名を避ける**(005 REQ-026)。
// 片方だけだと、警告は占有名で出るのに確定した名前は占有名と衝突したまま実行へ
// 渡る。ここはその「解決側」を固定する。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name, {bool selected = true, String? folder}) =>
    FileEntry(
      name: name,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
      size: 0,
      selected: selected,
      sourceFolder: folder,
    );

final DateTime _now = DateTime(2026, 7, 26, 9, 8, 7);

List<String> _names(List<ResolvedEntry> r) =>
    r.map((e) => e.resultName).toList();

void main() {
  group('REQ-010: 重複回避 (n)', () {
    test('例11: 3件が同名 -> dup.jpg / dup (1).jpg / dup (2).jpg', () {
      const rule = RenameRule([LiteralToken('dup')]);
      final files = [_file('a.jpg'), _file('b.jpg'), _file('c.jpg')];
      expect(_names(autoResolve(rule, files, _now)), [
        'dup.jpg',
        'dup (1).jpg',
        'dup (2).jpg',
      ]);
    });

    test('未選択の既存名と衝突する場合も (n) で回避', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [_file('x.png'), _file('keep.png', selected: false)];
      expect(_names(autoResolve(rule, files, _now)), ['keep (1).png']);
    });

    test('拡張子なしでも (n) を付与', () {
      const rule = RenameRule([LiteralToken('n')]);
      final files = [_file('a'), _file('b')];
      expect(_names(autoResolve(rule, files, _now)), ['n', 'n (1)']);
    });
  });

  group('REQ-011: 連番桁の自動拡張', () {
    test('例12相当: 桁2 で最大100 -> 3桁へ拡張(099,100)', () {
      const rule = RenameRule([SequenceToken(start: 99, digits: 2)]);
      final files = [_file('a'), _file('b')];
      expect(_names(autoResolve(rule, files, _now)), ['099', '100']);
    });

    test('桁に収まるなら拡張しない', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 2)]);
      final files = [_file('a'), _file('b'), _file('c')];
      expect(_names(autoResolve(rule, files, _now)), ['01', '02', '03']);
    });
  });

  group('REQ-012 / INV-003: 結果は重複・桁不足なし', () {
    test('自動解決後の最終名集合(未選択含む)に重複がない', () {
      const rule = RenameRule([LiteralToken('dup')]);
      final files = [
        _file('dup.jpg', selected: false), // 既存の同名
        _file('a.jpg'),
        _file('b.jpg'),
        _file('c.jpg'),
        _file('d.jpg'),
      ];
      final resolved = autoResolve(rule, files, _now);
      final finalNames = <String>[
        for (final f in files)
          if (!f.selected) f.name,
        ..._names(resolved),
      ];
      expect(finalNames.toSet().length, finalNames.length);
    });

    test('自動解決の結果に対して validate は桁不足・重複を返さない', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 1)]);
      // 12件 -> 桁1では不足。拡張後は 01..12。
      final files = List.generate(12, (i) => _file('f$i.txt'));
      final resolved = autoResolve(rule, files, _now);
      expect(_names(resolved).toSet().length, 12); // 重複なし
      expect(_names(resolved).first, '01.txt');
      expect(_names(resolved).last, '12.txt');
    });
  });

  group('OP-004: 健全なルールは素通し', () {
    test('衝突なし・桁十分なら buildName と一致(先頭は据え置き)', () {
      const rule = RenameRule([OriginalNameToken()]);
      final files = [_file('a.jpg'), _file('b.jpg')];
      final resolved = autoResolve(rule, files, _now);
      expect(_names(resolved), ['a.jpg', 'b.jpg']);
    });
  });

  group('REQ-015: 自動解決も占有名を避ける', () {
    test('占有名と衝突する目標名は ` (n)` で回避する(005 例25)', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [_file('a.png', folder: '/A')];

      final resolved = autoResolve(
        rule,
        files,
        _now,
        occupiedNames: {
          '/A': {'keep.png'},
        },
      );

      expect(_names(resolved), ['keep (1).png']);
    });

    test('占有名が埋まっているぶんだけ n が進む', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [_file('a.png', folder: '/A')];

      final resolved = autoResolve(
        rule,
        files,
        _now,
        occupiedNames: {
          '/A': {'keep.png', 'keep (1).png'},
        },
      );

      expect(_names(resolved), ['keep (2).png']);
    });

    test('占有名を与えなければ ` (n)` は付かない', () {
      // 「常に (n) を付ける実装」を排除する。
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [_file('a.png', folder: '/A')];

      expect(_names(autoResolve(rule, files, _now)), ['keep.png']);
    });

    test('別 folder の占有名は避けない(005 例25d)', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [_file('a.png', folder: '/A')];

      final resolved = autoResolve(
        rule,
        files,
        _now,
        occupiedNames: {
          '/A': <String>{},
          '/B': {'keep.png'},
        },
      );

      expect(_names(resolved), ['keep.png']);
    });

    test('確定した名前は、その folder の占有名と一致しない(OP-004 事後条件)', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [
        _file('a.png', folder: '/A'),
        _file('b.png', folder: '/A'),
        _file('c.png', folder: '/B'),
      ];
      final occupied = {
        '/A': {'keep.png', 'keep (1).png'},
        '/B': {'keep.png'},
      };

      final resolved = autoResolve(rule, files, _now, occupiedNames: occupied);

      for (final entry in resolved) {
        expect(
          occupied[entry.source.sourceFolder],
          isNot(contains(entry.resultName)),
          reason: '${entry.source.name} -> ${entry.resultName}',
        );
      }
      // 同じ folder の中では互いにも衝突しない(INV-003)。
      expect(_names(resolved), [
        'keep (2).png',
        'keep (3).png',
        'keep (1).png',
      ]);
    });
  });

  group('REQ-010: 解決も folder ごと(OQ-006)', () {
    test('別 folder の未選択 file と同名でも ` (n)` を付けない', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [
        _file('x.png', folder: '/A'),
        _file('keep.png', selected: false, folder: '/B'),
      ];

      expect(_names(autoResolve(rule, files, _now)), ['keep.png']);
    });

    test('別 folder の選択 file どうしが同名でも ` (n)` を付けない', () {
      const rule = RenameRule([LiteralToken('dup')]);
      final files = [
        _file('a.jpg', folder: '/A'),
        _file('b.jpg', folder: '/B'),
      ];

      expect(_names(autoResolve(rule, files, _now)), ['dup.jpg', 'dup.jpg']);
    });
  });
}
