// VER-001(続き): 行データ(プレビュー連携)の検証(FEAT-002 / Light)。
// 対象: REQ-005(setRule が行データに反映), REQ-006(items 順・選択行の変更後名が
//       generatePreview に一致), REQ-007(未選択行は変更後名を持たない)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {DateTime? created}) => FileEntry(
  name: name,
  createdAt: created ?? DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
);

const _seq2 = RenameRule([SequenceToken(start: 1, digits: 2)]);

List<String?> _newNames(FileListController c) =>
    c.rows.map((r) => r.newName).toList();

void main() {
  group('REQ-006: 行データは items 順・選択行は generatePreview に一致', () {
    test('rows は items と同じ順・件数で、currentName は name に等しい', () {
      final files = [_f('b.txt'), _f('a.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      expect(c.rows.map((r) => r.currentName).toList(), [
        'b.txt',
        'a.txt',
        'c.txt',
      ]);
      expect(c.rows.length, files.length);
    });

    test('選択行の変更後名は表示順の連番割り当て(generatePreview と一致)', () {
      final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      expect(_newNames(c), ['01.txt', '02.txt', '03.txt']);
      // 参照実装(generatePreview)と一致することを直接照合。
      final ref = generatePreview(
        _seq2,
        files, // 全選択(FileEntry.selected 既定 true)
        DateTime(2026, 1, 1),
      ).map((e) => e.resultName).toList();
      expect(ref, ['01.txt', '02.txt', '03.txt']);
    });

    test('reorder すると連番は新しい表示順で振り直される', () {
      final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.reorder(2, 0); // c を先頭へ -> [c, a, b]
      expect(c.rows.map((r) => r.currentName).toList(), [
        'c.txt',
        'a.txt',
        'b.txt',
      ]);
      expect(_newNames(c), ['01.txt', '02.txt', '03.txt']);
    });

    test('setRule でルールを差し替えると行データに反映される(REQ-005)', () {
      final files = [_f('photo.jpg')];
      final c = FileListController(files: files);
      // 既定(空ルール)は元名のみ相当 -> ベース名なしで拡張子のみ… ではなく空。
      expect(c.rows.single.newName, '.jpg');
      c.setRule(const RenameRule([OriginalNameToken()]));
      expect(c.rows.single.newName, 'photo.jpg');
    });

    test('現在日時トークンは注入した clock を用いる', () {
      final files = [_f('a.txt')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.current, format: 'YYYY'),
        ]),
        clock: () => DateTime(2030, 5, 6),
      );
      expect(c.rows.single.newName, '2030.txt');
    });
  });

  group('REQ-007: 未選択行は変更後名を持たない', () {
    test('中間の未選択行は newName=null、選択行のみ連番', () {
      final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.toggleSelection(files[1]); // b を未選択
      final rows = c.rows;
      expect(rows[1].newName, isNull);
      expect(rows[1].hasNewName, isFalse);
      // 選択行 a, c は表示順で 01, 02。
      expect(rows[0].newName, '01.txt');
      expect(rows[2].newName, '02.txt');
    });

    test('全解除ならすべて newName=null', () {
      final files = [_f('a.txt'), _f('b.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.clearAll();
      expect(c.rows.every((r) => r.newName == null), isTrue);
    });

    test('空 files では rows も空', () {
      final c = FileListController(files: const [], rule: _seq2);
      expect(c.rows, isEmpty);
    });

    test('rows の selected は選択状態を反映する', () {
      final files = [_f('a'), _f('b')];
      final c = FileListController(files: files, rule: _seq2);
      c.toggleSelection(files[0]);
      final rows = c.rows;
      expect(rows[0].selected, isFalse);
      expect(rows[1].selected, isTrue);
    });
  });

  group('反映: ソートも行データに反映される', () {
    test('name ソート後は rows も並び替わる', () {
      final files = [_f('b.txt'), _f('a.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.setSortMode(FileSortMode.name);
      expect(c.rows.map((r) => r.currentName).toList(), ['a.txt', 'b.txt']);
    });
  });
}
