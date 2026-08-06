// VER-002: リスト操作の検証(004 REQ-002/REQ-004/REQ-005/REQ-006 = 002 REQ-008/REQ-009)。
// 置き換え・同一ハンドルの集約・全件選択・除去・全消去・順序保持。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {required String handle, String? location}) =>
    FileEntry(
      name: name,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 2),
      size: 10,
      sourceHandle: handle,
      sourceLocation: location,
    );

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

void main() {
  test('setFiles は供給された順で並べ、全件を選択する(REQ-004/REQ-005)', () {
    final c = FileListController(files: const []);
    final a = _entry('a.txt', handle: 'h:a');
    final b = _entry('b.txt', handle: 'h:b');

    c.setFiles([a, b]);

    expect(_names(c), ['a.txt', 'b.txt']);
    expect(c.selectedCount, 2);
    expect(c.selectedOf(a), isTrue);
    expect(c.selectedOf(b), isTrue);
  });

  test('例2: 2回目の setFiles は前回を残さず置き換える(蓄積しない。REQ-004)', () {
    final c = FileListController(files: [_entry('a.txt', handle: 'h:a')]);

    c.setFiles([
      _entry('c.txt', handle: 'h:c'),
      _entry('d.txt', handle: 'h:d'),
    ]);

    expect(_names(c), ['c.txt', 'd.txt']);
  });

  test('例6b: 同一ハンドルが複数含まれていたら1件にまとめる(REQ-002/REQ-004)', () {
    final c = FileListController(files: const []);

    c.setFiles([
      _entry('a.txt', handle: 'h:a'),
      _entry('a.txt', handle: 'h:a'),
    ]);

    expect(c.items, hasLength(1));
  });

  test('例6: 同名でもハンドルが異なれば別ファイルとして載る(REQ-002)', () {
    final c = FileListController(files: const []);

    c.setFiles([
      _entry('IMG_001.jpg', handle: 'h:photos/IMG_001.jpg', location: '写真'),
      _entry('IMG_001.jpg', handle: 'h:dl/IMG_001.jpg', location: 'ダウンロード'),
    ]);

    expect(c.items, hasLength(2));
    expect(c.items.map((e) => e.sourceLocation), ['写真', 'ダウンロード']);
  });

  test('例7: 空リストで置き換えるとリストが空になる(REQ-004)', () {
    final c = FileListController(files: [_entry('a.txt', handle: 'h:a')]);

    c.setFiles(const []);

    expect(c.items, isEmpty);
    expect(c.selectedCount, 0);
  });

  test('ハンドルを持たない要素はまとめずそのまま並べる(同一性を判定できないため)', () {
    final c = FileListController(files: const []);
    FileEntry noHandle() =>
        FileEntry(name: 'x.txt', modifiedAt: DateTime(2026), size: 0);

    c.setFiles([noHandle(), noHandle()]);

    expect(c.items, hasLength(2));
    expect(c.items.every((e) => e.sourceHandle == null), isTrue);
  });

  test('例4: removeFile は一致 item をリストと選択から除去する(REQ-006)', () {
    final a = _entry('a.txt', handle: 'h:a');
    final c = FileListController(
      files: [
        a,
        _entry('b.txt', handle: 'h:b'),
      ],
    );

    c.removeFile('h:a');

    expect(_names(c), ['b.txt']);
    expect(c.selectedCount, 1);
    expect(c.selectedOf(a), isFalse);
  });

  test('removeFile は一致が無ければ無変化・通知もしない(REQ-006)', () {
    final c = FileListController(files: [_entry('a', handle: 'h:a')]);
    var notified = 0;
    c.addListener(() => notified++);

    c.removeFile('h:zzz');

    expect(c.items, hasLength(1));
    expect(notified, 0);
  });

  test('例5: clearFiles はリストと選択を空にする(REQ-006)', () {
    final c = FileListController(
      files: [
        _entry('a', handle: 'h:a'),
        _entry('b', handle: 'h:b'),
      ],
    );

    c.clearFiles();

    expect(c.items, isEmpty);
    expect(c.selectedCount, 0);
  });

  test('空のリストへの clearFiles は通知しない(REQ-006)', () {
    final c = FileListController(files: const []);
    var notified = 0;
    c.addListener(() => notified++);

    c.clearFiles();

    expect(notified, 0);
  });

  test('選択結果の順が表示順になり、初期ソートは custom(REQ-007)', () {
    final c = FileListController(files: const []);

    c.setFiles([
      _entry('z.txt', handle: 'h:z'),
      _entry('a.txt', handle: 'h:a'),
    ]);

    expect(c.sortMode, FileSortMode.custom);
    expect(_names(c), ['z.txt', 'a.txt']);
  });
}
