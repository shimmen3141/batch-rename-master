// VER-003: FileSource の結果でリストを置き換える結線(REQ-004/005/007/008)。
// UI 提示(種類選択・通知の見た目・場所の表示)は ui_entry_test。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_loading.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
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
  test('Picked の結果でリストが置き換わる(REQ-007)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('a.txt', handle: 'h:a'),
          _entry('b.txt', handle: 'h:b'),
        ]),
      ],
    );

    final error = await loadFilesInto(source, controller.setFiles);

    expect(error, isNull);
    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.selectedCount, 2);
  });

  test('プレビュー(変更後名)に反映される(REQ-007)', () async {
    final controller = FileListController(
      files: const [],
      rule: const RenameRule([
        LiteralToken('IMG_'),
        SequenceToken(start: 1, digits: 2, increment: 1),
      ]),
    );
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('one.jpg', handle: 'h:1'),
          _entry('two.jpg', handle: 'h:2'),
        ]),
      ],
    );

    await loadFilesInto(source, controller.setFiles);

    expect(controller.rows.map((r) => r.newName), ['IMG_01.jpg', 'IMG_02.jpg']);
  });

  test('2回目の選択は前回を残さず置き換える(蓄積しない。REQ-004)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('a.txt', handle: 'h:a', location: '写真')]),
        Picked([_entry('b.txt', handle: 'h:b', location: 'ダウンロード')]),
      ],
    );

    await loadFilesInto(source, controller.setFiles);
    await loadFilesInto(source, controller.setFiles);

    expect(controller.items.map((e) => e.name), ['b.txt']);
    expect(controller.items.map((e) => e.sourceLocation), ['ダウンロード']);
  });

  test('MIME フィルタがソースへ渡る(種類「文書」用。REQ-011)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(fileResults: [const Picked([])]);

    await loadFilesInto(
      source,
      controller.setFiles,
      mimeTypes: const ['application/pdf'],
    );

    expect(source.lastMimeTypes, ['application/pdf']);
  });

  test('Cancelled はリスト無変化・エラーなし(前回の選択が保たれる。REQ-008)', () async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(fileResults: [const Cancelled()]);
    var notified = 0;
    controller.addListener(() => notified++);

    final error = await loadFilesInto(source, controller.setFiles);

    expect(error, isNull);
    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(notified, 0);
  });

  test('Failed はリスト無変化のまま理由を返す(REQ-008)', () async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(
      fileResults: [
        const Failed(PickError(PickErrorKind.permissionDenied, 'アクセスできません')),
      ],
    );
    var notified = 0;
    controller.addListener(() => notified++);

    final error = await loadFilesInto(source, controller.setFiles);

    expect(error, isNotNull);
    expect(error!.kind, PickErrorKind.permissionDenied);
    expect(error.message, 'アクセスできません');
    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(notified, 0);
  });

  test('例7: 空の Picked で置き換えるとリストが空になる(REQ-001/004)', () async {
    final controller = FileListController(
      files: [_entry('old.txt', handle: 'h:old')],
    );
    final source = FakeFileSource(fileResults: [const Picked([])]);

    final error = await loadFilesInto(source, controller.setFiles);

    expect(error, isNull);
    expect(controller.items, isEmpty);
  });

  test('成功の後に失敗しても、直前の結果は保たれる(REQ-008)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('c.pdf', handle: 'h:c')]),
        const Failed(PickError(PickErrorKind.io)),
      ],
    );

    final first = await loadFilesInto(source, controller.setFiles);
    final second = await loadFilesInto(source, controller.setFiles);

    expect(first, isNull);
    expect(second?.kind, PickErrorKind.io);
    expect(controller.items.map((e) => e.name), ['c.pdf']);
    expect(source.fileCallCount, 2);
  });

  test('読み込んだ FileEntry は場所を保持したまま行データへ渡る(REQ-009 の前提)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('a.txt', handle: 'h:a', location: 'ダウンロード')]),
      ],
    );

    await loadFilesInto(source, controller.setFiles);

    expect(controller.rows.single.source.sourceLocation, 'ダウンロード');
  });
}
