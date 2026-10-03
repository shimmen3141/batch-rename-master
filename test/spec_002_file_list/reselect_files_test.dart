// VER-001(008:T56): 同じ folder を開き直して確定したときの置き換え(002 REQ-021)。
//
// 観点: 置き換え・全件選択・同一ハンドルの集約は `setFiles`(REQ-008)と同じで、
// **並びだけが違う** — `custom` なら順を保ち、新しい item を後ろへ名前の昇順で並べる。
// キーの並びなら全体へ当てはめる。`setFiles` の「custom なら名前の昇順へ戻す」は変えない。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {int size = 0}) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 1, 1),
  size: size,
  sourceHandle: '/A/$name',
  sourceFolder: '/A',
);

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

/// 手で [order] の順へ並べた一覧(sortMode=custom)。
FileListController _custom(List<String> order) {
  final c = FileListController(files: [for (final n in order) _f(n)]);
  for (var i = 0; i < order.length; i++) {
    final from = c.items.indexWhere((e) => e.name == order[i]);
    c.reorder(from, i);
  }
  expect(_names(c), order);
  expect(c.sortMode, FileSortMode.custom);
  return c;
}

void main() {
  group('REQ-021: reselectFiles は置き換え、並びだけを変える', () {
    test('例28: 手で並べた [c,a,b] に d,e を足すと [c,a,b,d,e] で custom のまま', () {
      final c = _custom(['c', 'a', 'b']);

      c.reselectFiles([_f('a'), _f('b'), _f('c'), _f('e'), _f('d')]);

      expect(_names(c), ['c', 'a', 'b', 'd', 'e']);
      expect(c.sortMode, FileSortMode.custom);
    });

    test('例29: 手で並べた [c,a,b] で b を外して d を足すと [c,a,d]', () {
      final c = _custom(['c', 'a', 'b']);

      c.reselectFiles([_f('a'), _f('c'), _f('d')]);

      expect(_names(c), ['c', 'a', 'd'], reason: 'b は外れ、残りの順は保つ');
      expect(c.sortMode, FileSortMode.custom);
    });

    test('例30: サイズの降順なら全体へ当てはめ、並び順は変わらない', () {
      final c = FileListController(files: [_f('a', size: 1), _f('b', size: 3)])
        ..setSortMode(FileSortMode.size, direction: SortDirection.descending);

      c.reselectFiles([_f('a', size: 1), _f('b', size: 3), _f('c', size: 2)]);

      expect(_names(c), ['b', 'c', 'a']);
      expect(c.sortMode, FileSortMode.size);
      expect(c.sortDirection, SortDirection.descending);
    });

    test('例31: 改名で並べ直していない一覧でも、確定したら全体が並び直る', () {
      final c = FileListController(files: [_f('a'), _f('b')]);
      // 例27: a を z へ改名しても行は動かない(REQ-020)。
      c.replaceItems({c.items.first: _f('z')});
      expect(_names(c), ['z', 'b']);

      c.reselectFiles([_f('z'), _f('b'), _f('c')]);

      expect(_names(c), ['b', 'c', 'z']);
      expect(c.sortMode, FileSortMode.name);
    });

    test('全件が選択され、同一ハンドルは1件にまとめる(REQ-008 と同じ)', () {
      final c = _custom(['b', 'a']);

      c.reselectFiles([_f('a'), _f('c'), _f('c')]);

      expect(_names(c), ['a', 'c']);
      expect(c.selectedCount, 2);
    });

    test('custom でも、並べる位置は前の item から、中身は新しい値から取る', () {
      final c = _custom(['b', 'a']);
      final freshB = _f('b', size: 99);

      c.reselectFiles([_f('a'), freshB]);

      expect(_names(c), ['b', 'a']);
      expect(identical(c.items.first, freshB), isTrue);
    });

    test('REQ-008 は変えない: setFiles は custom を名前の昇順へ戻す', () {
      final c = _custom(['c', 'a', 'b']);

      c.setFiles([_f('a'), _f('b'), _f('c'), _f('d')]);

      expect(_names(c), ['a', 'b', 'c', 'd']);
      expect(c.sortMode, FileSortMode.name);
    });
  });
}
