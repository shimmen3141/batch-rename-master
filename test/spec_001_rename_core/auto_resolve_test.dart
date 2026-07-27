// VER-004: 自動解決の検証(FEAT-001)。
// 対象: REQ-010(重複回避 (n)), REQ-011(桁自動拡張), REQ-012/INV-003(結果は
//       重複・桁不足なし), OP-004(autoResolve)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name, {bool selected = true}) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
  selected: selected,
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
}
