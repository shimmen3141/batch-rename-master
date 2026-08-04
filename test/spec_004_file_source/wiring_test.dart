// VER-003(T2 の範囲): FileSource の結果を作業セットへ反映する結線
// (REQ-004/005/007/008)。UI 提示(通知の見た目・場所の表示)は T3。
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
  test('Picked の結果が作業セットへ追加され、リストに現れる(REQ-007)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      folderResults: [
        Picked([
          _entry('a.txt', handle: 'h:a'),
          _entry('b.txt', handle: 'h:b'),
        ]),
      ],
    );

    final error = await loadFolderInto(source, controller.addFiles);

    expect(error, isNull);
    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.selectedCount, 2);
  });

  test('プレビュー(変更後名)に追加分が現れる(REQ-007)', () async {
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

    await loadFilesInto(source, controller.addFiles);

    expect(controller.rows.map((r) => r.newName), ['IMG_01.jpg', 'IMG_02.jpg']);
  });

  test('複数回の選択で別フォルダ分が蓄積される(REQ-004/007)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      folderResults: [
        Picked([_entry('a.txt', handle: 'h:a', location: '写真')]),
        Picked([
          _entry('a.txt', handle: 'h:a', location: '写真'), // 重複
          _entry('b.txt', handle: 'h:b', location: 'ダウンロード'),
        ]),
      ],
    );

    await loadFolderInto(source, controller.addFiles);
    await loadFolderInto(source, controller.addFiles);

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.items.map((e) => e.sourceLocation), ['写真', 'ダウンロード']);
  });

  test('Cancelled は作業セット無変化・エラーなし(REQ-008)', () async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(folderResults: [const Cancelled()]);
    var notified = 0;
    controller.addListener(() => notified++);

    final error = await loadFolderInto(source, controller.addFiles);

    expect(error, isNull);
    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(notified, 0);
  });

  test('Failed は作業セット無変化のまま理由を返す(REQ-008)', () async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(
      folderResults: [
        const Failed(PickError(PickErrorKind.permissionDenied, 'アクセスできません')),
      ],
    );
    var notified = 0;
    controller.addListener(() => notified++);

    final error = await loadFolderInto(source, controller.addFiles);

    expect(error, isNotNull);
    expect(error!.kind, PickErrorKind.permissionDenied);
    expect(error.message, 'アクセスできません');
    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(notified, 0);
  });

  test('空フォルダ(空の Picked)は無変化でエラーにもならない(REQ-001/007)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(folderResults: [const Picked([])]);

    final error = await loadFolderInto(source, controller.addFiles);

    expect(error, isNull);
    expect(controller.items, isEmpty);
  });

  test('ファイル選択の結線も同じ契約で動く(REQ-007/008)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('c.pdf', handle: 'h:c')]),
        const Failed(PickError(PickErrorKind.io)),
      ],
    );

    final first = await loadFilesInto(source, controller.addFiles);
    final second = await loadFilesInto(source, controller.addFiles);

    expect(first, isNull);
    expect(second?.kind, PickErrorKind.io);
    expect(controller.items.map((e) => e.name), ['c.pdf']);
    expect(source.fileCallCount, 2);
  });

  test('追加された FileEntry は場所を保持したまま行データへ渡る(REQ-009 の前提)', () async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('a.txt', handle: 'h:a', location: 'ダウンロード')]),
      ],
    );

    await loadFilesInto(source, controller.addFiles);

    expect(controller.rows.single.source.sourceLocation, 'ダウンロード');
  });
}
