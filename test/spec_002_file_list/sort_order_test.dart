// VER-001(008:T02): 並び順の状態層(002 spec 2026-09-30 `008:T01` の更新)。
// 対象: REQ-001(初期は名前の昇順), REQ-002(昇順・降順と降順の安定),
//       REQ-003(custom は選べない・キーを選ぶと手で並べた順は失われる),
//       REQ-008(読み込み直しで並び順を当てはめ、custom なら名前の昇順へ戻す),
//       REQ-011(作成日時順なら向きを問わず警告), REQ-017(取り消しは並び順も戻す),
//       REQ-020(実行後の差し替えは並べ直さない)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(
  String name, {
  DateTime? created,
  DateTime? modified,
  int size = 0,
  bool unknownCreated = false,
}) => FileEntry(
  name: name,
  createdAt: unknownCreated ? null : (created ?? DateTime(2026, 1, 1)),
  modifiedAt: modified ?? DateTime(2026, 1, 1),
  size: size,
  sourceHandle: 'h:$name',
);

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

void main() {
  group('REQ-001: 初期は名前の昇順', () {
    test('例1d: files=[b,a,c] で初期化すると [a,b,c]・name・昇順', () {
      final c = FileListController(files: [_f('b'), _f('a'), _f('c')]);
      expect(_names(c), ['a', 'b', 'c']);
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.ascending);
    });

    test('空の files でも name・昇順で始まる', () {
      final c = FileListController(files: const []);
      expect(c.items, isEmpty);
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.ascending);
    });
  });

  group('REQ-002: 昇順・降順', () {
    test('例1b: name の降順で [c,b,a]、sortDirection=descending', () {
      final c = FileListController(files: [_f('b'), _f('a'), _f('c')]);
      c.setSortMode(FileSortMode.name, direction: SortDirection.descending);
      expect(_names(c), ['c', 'b', 'a']);
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.descending);
    });

    test('例1c: size の降順でも同値の a と c は元の相対順のまま [b,a,c]', () {
      // 初期の名前順で [a,b,c] に並んだ状態を「この順」とする。
      final c = FileListController(
        files: [_f('a', size: 1), _f('b', size: 2), _f('c', size: 1)],
      );
      expect(_names(c), ['a', 'b', 'c']);
      c.setSortMode(FileSortMode.size, direction: SortDirection.descending);
      // 列の反転なら [b,c,a] になる。
      expect(_names(c), ['b', 'a', 'c']);
    });

    test('向きを指定しなければ昇順(キーを選ぶときの既定)', () {
      final c = FileListController(files: [_f('b'), _f('a')]);
      c.setSortMode(FileSortMode.name, direction: SortDirection.descending);
      c.setSortMode(FileSortMode.name);
      expect(_names(c), ['a', 'b']);
      expect(c.sortDirection, SortDirection.ascending);
    });

    test('更新日時・作成日時の降順は新しい順', () {
      final c = FileListController(
        files: [
          _f('old', created: DateTime(2020), modified: DateTime(2020)),
          _f('new', created: DateTime(2024), modified: DateTime(2024)),
          _f('mid', created: DateTime(2022), modified: DateTime(2022)),
        ],
      );
      c.setSortMode(
        FileSortMode.modifiedAt,
        direction: SortDirection.descending,
      );
      expect(_names(c), ['new', 'mid', 'old']);
      c.setSortMode(
        FileSortMode.createdAt,
        direction: SortDirection.descending,
      );
      expect(_names(c), ['new', 'mid', 'old']);
    });
  });

  group('REQ-003: custom は手で並べた結果を示す状態', () {
    test('setSortMode に custom は渡せない', () {
      final c = FileListController(files: [_f('a'), _f('b')]);
      expect(() => c.setSortMode(FileSortMode.custom), throwsArgumentError);
      expect(c.sortMode, FileSortMode.name);
      expect(_names(c), ['a', 'b']);
    });

    test('例1e: custom から name を選ぶと名前の昇順へ並べ直す', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c')]);
      c.reorder(2, 0); // 例2: c を先頭へ
      expect(_names(c), ['c', 'a', 'b']);
      expect(c.sortMode, FileSortMode.custom);

      c.setSortMode(FileSortMode.name);
      expect(_names(c), ['a', 'b', 'c']);
      expect(c.sortMode, FileSortMode.name);
    });
  });

  group('REQ-008: 読み込み直しで並び順を当てはめる', () {
    test('例22: name(昇順)で items=[a,b] のとき setFiles([z,y,x]) → [x,y,z]', () {
      final c = FileListController(files: [_f('a'), _f('b')]);
      c.setFiles([_f('z'), _f('y'), _f('x')]);
      expect(_names(c), ['x', 'y', 'z']);
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.ascending);
    });

    test('例23: 作成日時の降順を選んだまま読み込むと、新しい items も作成日時の降順', () {
      final c = FileListController(files: [_f('a')]);
      c.setSortMode(
        FileSortMode.createdAt,
        direction: SortDirection.descending,
      );
      c.setFiles([
        _f('p', created: DateTime(2021)),
        _f('q', created: DateTime(2023)),
        _f('r', created: DateTime(2022)),
      ]);
      expect(_names(c), ['q', 'r', 'p']);
      expect(c.sortMode, FileSortMode.createdAt);
      expect(c.sortDirection, SortDirection.descending);
    });

    test('例24: custom で setFiles([z,y,x]) → [x,y,z]・name・昇順へ戻る', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c')]);
      c.setSortMode(FileSortMode.size, direction: SortDirection.descending);
      c.reorder(2, 0);
      expect(c.sortMode, FileSortMode.custom);

      c.setFiles([_f('z'), _f('y'), _f('x')]);
      expect(_names(c), ['x', 'y', 'z']);
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.ascending);
    });

    test('当てはめても全件を選択状態にする', () {
      final c = FileListController(files: [_f('a')]);
      c.setFiles([_f('z'), _f('y')]);
      expect(c.selectedCount, 2);
      expect(c.items.every(c.selectedOf), isTrue);
    });
  });

  group('REQ-017: 取り消しは並び順も除去前へ戻す', () {
    test('例25: 手で並べた [c,a,b] で b を除去して戻すと [c,a,b]・custom のまま', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c')]);
      c.reorder(2, 0);
      expect(_names(c), ['c', 'a', 'b']);
      final before = c.items;
      final mode = c.sortMode;
      final direction = c.sortDirection;

      c.removeFile('h:b');
      c.restoreFiles(before, sortMode: mode, sortDirection: direction);

      expect(_names(c), ['c', 'a', 'b']);
      expect(c.sortMode, FileSortMode.custom);
      expect(c.items.every(c.selectedOf), isTrue);
    });

    test('降順の一覧で戻すと向きも戻る', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c')]);
      c.setSortMode(FileSortMode.name, direction: SortDirection.descending);
      final before = c.items;

      c.clearFiles();
      c.restoreFiles(
        before,
        sortMode: FileSortMode.name,
        sortDirection: SortDirection.descending,
      );

      expect(_names(c), ['c', 'b', 'a']);
      expect(c.sortDirection, SortDirection.descending);
    });
  });

  group('REQ-011: 作成日時順なら向きを問わず警告する', () {
    List<FileEntry> example8() => [
      _f('b', created: DateTime(2024)),
      _f('a', created: DateTime(2023)),
      _f('c', unknownCreated: true, modified: DateTime(2022)),
    ];

    test('例26: 例8 のデータを作成日時の降順 → [b,a,c]、警告1件', () {
      final c = FileListController(files: example8());
      c.setSortMode(
        FileSortMode.createdAt,
        direction: SortDirection.descending,
      );
      expect(_names(c), ['b', 'a', 'c']);
      expect(c.createdAtSortWarning?.unknownCount, 1);
    });

    test('手で並べて custom になったら警告しない', () {
      final c = FileListController(files: example8());
      c.setSortMode(
        FileSortMode.createdAt,
        direction: SortDirection.descending,
      );
      c.reorder(0, 1);
      expect(c.createdAtSortWarning, isNull);
    });
  });

  group('REQ-020: 実行後の差し替えは並べ直さない', () {
    test('例27: name の一覧で a が z へ改名されても行は動かず、name のまま', () {
      final a = _f('a');
      final c = FileListController(files: [a, _f('b'), _f('c')]);
      c.replaceItems({a: _f('z')});
      expect(_names(c), ['z', 'b', 'c']);
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.ascending);
    });
  });
}
