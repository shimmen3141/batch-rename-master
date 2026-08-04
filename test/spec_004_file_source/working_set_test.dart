// VER-002: 作業セットの操作(004 REQ-002/004/005/006 = 002 REQ-008/009)。
// 追加・ハンドルによる重複排除・既定選択・除去・全消去・追加順の保持。
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

void main() {
  test('addFiles は与えられた順で末尾へ追加し、追加分を選択する(REQ-004/005)', () {
    final controller = FileListController(files: const []);
    final a = _entry('a.txt', handle: 'h:a');
    final b = _entry('b.txt', handle: 'h:b');

    controller.addFiles([a, b]);

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.selectedCount, 2);
    expect(controller.selectedOf(a), isTrue);
    expect(controller.selectedOf(b), isTrue);
  });

  test('既存ハンドルと一致するものは追加しない(REQ-002/004)', () {
    final a = _entry('a.txt', handle: 'h:a');
    final controller = FileListController(files: [a]);

    controller.addFiles([
      _entry('a-renamed.txt', handle: 'h:a'), // 同ハンドル = 同一ファイル
      _entry('c.txt', handle: 'h:c'),
    ]);

    expect(controller.items.map((e) => e.name), ['a.txt', 'c.txt']);
  });

  test('同一呼び出し内の重複もハンドルで排除する(REQ-004)', () {
    final controller = FileListController(files: const []);

    controller.addFiles([
      _entry('a.txt', handle: 'h:a'),
      _entry('a.txt', handle: 'h:a'),
    ]);

    expect(controller.items, hasLength(1));
  });

  test('同名でもハンドルが異なれば別ファイルとして追加される(REQ-002)', () {
    final controller = FileListController(files: const []);

    controller.addFiles([
      _entry('IMG_001.jpg', handle: 'h:photos/IMG_001.jpg', location: '写真'),
      _entry('IMG_001.jpg', handle: 'h:dl/IMG_001.jpg', location: 'ダウンロード'),
    ]);

    expect(controller.items, hasLength(2));
    expect(controller.items.map((e) => e.sourceLocation), ['写真', 'ダウンロード']);
  });

  test('別フォルダの選択を重ねると混在して蓄積される(REQ-004)', () {
    final controller = FileListController(files: const []);

    controller.addFiles([_entry('a.txt', handle: 'h:a')]);
    controller.addFiles([
      _entry('b.jpg', handle: 'h:b'),
      _entry('a.txt', handle: 'h:a'),
    ]);
    controller.addFiles([_entry('c.pdf', handle: 'h:c')]);

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.jpg', 'c.pdf']);
  });

  test('空リストの追加は無変化・通知もしない(REQ-004)', () {
    final controller = FileListController(files: [_entry('a', handle: 'h:a')]);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.addFiles(const []);

    expect(controller.items, hasLength(1));
    expect(notified, 0);
  });

  test('全件が既存ハンドルなら無変化・通知もしない(REQ-004)', () {
    final controller = FileListController(files: [_entry('a', handle: 'h:a')]);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.addFiles([_entry('a2', handle: 'h:a')]);

    expect(controller.items, hasLength(1));
    expect(notified, 0);
  });

  test('removeFile は一致 item を作業セットと選択から除去する(REQ-006)', () {
    final a = _entry('a.txt', handle: 'h:a');
    final b = _entry('b.txt', handle: 'h:b');
    final controller = FileListController(files: [a, b]);

    controller.removeFile('h:a');

    expect(controller.items.map((e) => e.name), ['b.txt']);
    expect(controller.selectedCount, 1);
    expect(controller.selectedOf(a), isFalse);
  });

  test('removeFile は一致が無ければ無変化・通知もしない(REQ-006)', () {
    final controller = FileListController(files: [_entry('a', handle: 'h:a')]);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.removeFile('h:zzz');

    expect(controller.items, hasLength(1));
    expect(notified, 0);
  });

  test('clearFiles は作業セットと選択を空にする(REQ-006)', () {
    final controller = FileListController(
      files: [
        _entry('a', handle: 'h:a'),
        _entry('b', handle: 'h:b'),
      ],
    );

    controller.clearFiles();

    expect(controller.items, isEmpty);
    expect(controller.selectedCount, 0);
  });

  test('空の作業セットへの clearFiles は通知しない(REQ-006)', () {
    final controller = FileListController(files: const []);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.clearFiles();

    expect(notified, 0);
  });

  test('追加順が表示順になり、初期ソートは custom(REQ-004 / 004 REQ-007)', () {
    final controller = FileListController(files: const []);

    controller.addFiles([
      _entry('z.txt', handle: 'h:z'),
      _entry('a.txt', handle: 'h:a'),
    ]);

    expect(controller.sortMode, FileSortMode.custom);
    expect(controller.items.map((e) => e.name), ['z.txt', 'a.txt']);
  });
}
