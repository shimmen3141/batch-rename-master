// VER-002: プレビュー生成の検証(FEAT-001)。
// 対象: REQ-006(選択のみ・表示順保持・上から連番), OP-002(generatePreview),
//       INV-001(任意順・重複可のトークン列)。
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

void main() {
  group('REQ-006 / OP-002: プレビュー生成', () {
    test('選択ファイルのみ・表示順保持・連番は上から1始まり', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 2)]);
      final files = [
        _file('a.jpg'),
        _file('b.jpg', selected: false),
        _file('c.jpg'),
        _file('d.jpg'),
      ];
      final preview = generatePreview(rule, files, _now);
      expect(preview.map((e) => e.source.name).toList(), [
        'a.jpg',
        'c.jpg',
        'd.jpg',
      ]);
      expect(preview.map((e) => e.resultName).toList(), [
        '01.jpg',
        '02.jpg',
        '03.jpg',
      ]);
    });

    test('未選択のみ -> 空', () {
      const rule = RenameRule([OriginalNameToken()]);
      final files = [_file('a', selected: false), _file('b', selected: false)];
      expect(generatePreview(rule, files, _now), isEmpty);
    });

    test('空入力 -> 空', () {
      const rule = RenameRule([OriginalNameToken()]);
      expect(generatePreview(rule, const <FileEntry>[], _now), isEmpty);
    });

    test('順序保持(元名トークン)', () {
      const rule = RenameRule([OriginalNameToken()]);
      final files = [_file('z.txt'), _file('a.txt'), _file('m.txt')];
      expect(
        generatePreview(rule, files, _now).map((e) => e.resultName).toList(),
        ['z.txt', 'a.txt', 'm.txt'],
      );
    });

    test('INV-001: 同一種別の重複・任意順トークンでも動く', () {
      const rule = RenameRule([
        SequenceToken(start: 1, digits: 1),
        LiteralToken('-'),
        SequenceToken(start: 10, digits: 2),
      ]);
      final files = [_file('a.png'), _file('b.png')];
      final preview = generatePreview(rule, files, _now);
      expect(preview.map((e) => e.resultName).toList(), [
        '1-10.png',
        '2-11.png',
      ]);
    });

    test('OP-002 事後条件: i番目の結果は buildName(rule, file, i, now) に一致', () {
      const rule = RenameRule([SequenceToken(start: 5, digits: 1)]);
      final files = [_file('a'), _file('b', selected: false), _file('c')];
      final preview = generatePreview(rule, files, _now);
      expect(preview[0].resultName, buildName(rule, files[0], 1, _now));
      expect(preview[1].resultName, buildName(rule, files[2], 2, _now));
    });
  });
}
