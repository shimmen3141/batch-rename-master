// VER-001: FileListController の状態・操作の検証(FEAT-002 / Light)。
// 対象: REQ-001(初期化・入力順・既定選択), REQ-002(ソート昇順・安定),
//       REQ-003(reorder → custom 自動切替), REQ-004(選択トグル/全選択/全解除),
//       REQ-005(setRule)。プレビュー行データ(REQ-006/007)は T3。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {DateTime? created, int size = 0}) => FileEntry(
  name: name,
  createdAt: created ?? DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: size,
);

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

void main() {
  group('REQ-001: 初期化', () {
    test('items は入力の並び順を保持し、現在名は FileEntry.name に等しい', () {
      final files = [_f('b.txt'), _f('a.txt'), _f('c.txt')];
      final c = FileListController(files: files);
      expect(_names(c), ['b.txt', 'a.txt', 'c.txt']);
    });

    test('既定は全選択、初期 sortMode は custom(入力順)', () {
      final files = [_f('a'), _f('b'), _f('c')];
      final c = FileListController(files: files);
      expect(c.sortMode, FileSortMode.custom);
      expect(c.selectedCount, 3);
      expect(files.every(c.selectedOf), isTrue);
    });

    test('空の files でも成立する', () {
      final c = FileListController(files: const []);
      expect(_names(c), isEmpty);
      expect(c.selectedCount, 0);
      expect(c.sortMode, FileSortMode.custom);
    });

    test('items は読み取り専用ビュー(外部から破壊できない)', () {
      final c = FileListController(files: [_f('a')]);
      expect(() => c.items.add(_f('x')), throwsUnsupportedError);
    });
  });

  group('REQ-002: ソート(昇順・安定)', () {
    test('name: 自然順・大文字小文字を区別しない', () {
      final c = FileListController(
        files: [_f('File10'), _f('file2'), _f('file1'), _f('Apple')],
      );
      c.setSortMode(FileSortMode.name);
      expect(_names(c), ['Apple', 'file1', 'file2', 'File10']);
      expect(c.sortMode, FileSortMode.name);
    });

    test('createdAt: 昇順', () {
      final c = FileListController(
        files: [
          _f('c', created: DateTime(2026, 3, 1)),
          _f('a', created: DateTime(2026, 1, 1)),
          _f('b', created: DateTime(2026, 2, 1)),
        ],
      );
      c.setSortMode(FileSortMode.createdAt);
      expect(_names(c), ['a', 'b', 'c']);
    });

    test('size: 昇順', () {
      final c = FileListController(
        files: [
          _f('big', size: 300),
          _f('small', size: 10),
          _f('mid', size: 50),
        ],
      );
      c.setSortMode(FileSortMode.size);
      expect(_names(c), ['small', 'mid', 'big']);
    });

    test('同値キーでは元の相対順を保持する(安定)', () {
      final t = DateTime(2026, 1, 1);
      final c = FileListController(
        files: [
          _f('x', created: t),
          _f('y', created: t),
          _f('z', created: t),
        ],
      );
      c.setSortMode(FileSortMode.createdAt);
      expect(_names(c), ['x', 'y', 'z']);
    });

    test('custom 指定は現在順を保持する', () {
      final c = FileListController(files: [_f('b'), _f('a')]);
      c.setSortMode(FileSortMode.custom);
      expect(_names(c), ['b', 'a']);
      expect(c.sortMode, FileSortMode.custom);
    });
  });

  group('REQ-003: reorder → custom 自動切替', () {
    test('下方向へ移動(ReorderableListView 規約)', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c'), _f('d')]);
      c.setSortMode(FileSortMode.name);
      c.reorder(0, 2);
      expect(_names(c), ['b', 'a', 'c', 'd']);
      expect(c.sortMode, FileSortMode.custom);
    });

    test('上方向へ移動', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c'), _f('d')]);
      c.reorder(2, 0);
      expect(_names(c), ['c', 'a', 'b', 'd']);
      expect(c.sortMode, FileSortMode.custom);
    });

    test('末尾へ移動', () {
      final c = FileListController(files: [_f('a'), _f('b'), _f('c')]);
      c.reorder(0, 3);
      expect(_names(c), ['b', 'c', 'a']);
    });
  });

  group('REQ-004: 選択', () {
    test('toggleSelection は選択を反転する', () {
      final files = [_f('a'), _f('b')];
      final c = FileListController(files: files);
      c.toggleSelection(files[0]);
      expect(c.selectedOf(files[0]), isFalse);
      expect(c.selectedCount, 1);
      c.toggleSelection(files[0]);
      expect(c.selectedOf(files[0]), isTrue);
      expect(c.selectedCount, 2);
    });

    test('clearAll / selectAll', () {
      final files = [_f('a'), _f('b'), _f('c')];
      final c = FileListController(files: files);
      c.clearAll();
      expect(c.selectedCount, 0);
      expect(files.any(c.selectedOf), isFalse);
      c.selectAll();
      expect(c.selectedCount, 3);
      expect(files.every(c.selectedOf), isTrue);
    });

    test('選択はソート・reorder をまたいで同一ファイルに追従する', () {
      final files = [_f('b'), _f('a'), _f('c')];
      final c = FileListController(files: files);
      c.toggleSelection(files[0]); // 'b' を未選択
      c.setSortMode(FileSortMode.name); // 並び替え
      final b = c.items.firstWhere((e) => e.name == 'b');
      expect(c.selectedOf(b), isFalse);
      expect(c.selectedCount, 2);
    });
  });

  group('REQ-005: setRule', () {
    test('rule を差し替えると getter に反映される', () {
      final c = FileListController(files: [_f('a')]);
      expect(c.rule.tokens, isEmpty);
      const rule = RenameRule([LiteralToken('x')]);
      c.setRule(rule);
      expect(c.rule, same(rule));
    });
  });

  group('通知', () {
    test('各操作で listener に通知する', () {
      final files = [_f('a'), _f('b')];
      final c = FileListController(files: files);
      var n = 0;
      c.addListener(() => n++);
      c.toggleSelection(files[0]);
      c.selectAll();
      c.clearAll();
      c.setSortMode(FileSortMode.name);
      c.reorder(0, 1);
      c.setRule(RenameRule.empty);
      expect(n, 6);
    });
  });
}
