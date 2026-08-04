// VER-001: FileSource ポート契約(REQ-001/002/003)。
// Picked / Cancelled / Failed の区別、元場所ハンドル、メタデータ、no-throw。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(
  String name, {
  String? handle,
  String? location,
  DateTime? modifiedAt,
  int size = 10,
}) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: modifiedAt ?? DateTime(2026, 1, 2),
  size: size,
  sourceHandle: handle ?? 'content://tree/$name',
  sourceLocation: location ?? 'ダウンロード',
);

void main() {
  test('pickFolder/pickFiles は Picked を返し、entries を保持する(REQ-001)', () async {
    final source = FakeFileSource(
      folderResults: [
        Picked([_entry('a.txt'), _entry('b.txt')]),
      ],
      fileResults: [
        Picked([_entry('c.txt')]),
      ],
    );

    final folder = await source.pickFolder();
    final files = await source.pickFiles();

    expect(folder, isA<Picked>());
    expect((folder as Picked).entries.map((e) => e.name), ['a.txt', 'b.txt']);
    expect((files as Picked).entries.single.name, 'c.txt');
  });

  test('空フォルダは空の Picked(Cancelled ではない)(REQ-001)', () async {
    final source = FakeFileSource(folderResults: [const Picked([])]);
    final result = await source.pickFolder();

    expect(result, isA<Picked>());
    expect((result as Picked).entries, isEmpty);
  });

  test('閉じて未選択は Cancelled(REQ-001)', () async {
    final source = FakeFileSource(folderResults: [const Cancelled()]);
    expect(await source.pickFolder(), isA<Cancelled>());
  });

  test('権限拒否・IO 失敗は Failed と理由を返す(REQ-001)', () async {
    final source = FakeFileSource(
      folderResults: [
        const Failed(PickError(PickErrorKind.permissionDenied, '拒否されました')),
      ],
      fileResults: [const Failed(PickError(PickErrorKind.io))],
    );

    final folder = await source.pickFolder() as Failed;
    final files = await source.pickFiles() as Failed;

    expect(folder.error.kind, PickErrorKind.permissionDenied);
    expect(folder.error.message, '拒否されました');
    expect(files.error.kind, PickErrorKind.io);
    expect(files.error.message, isNull);
  });

  test('いずれの操作も例外を投げない(REQ-001)', () async {
    final source = FakeFileSource();
    await expectLater(source.pickFolder(), completes);
    await expectLater(source.pickFiles(), completes);
  });

  test('結果が尽きたら exhausted(既定 Cancelled)を返す', () async {
    final source = FakeFileSource(folderResults: [const Picked([])]);
    expect(await source.pickFolder(), isA<Picked>());
    expect(await source.pickFolder(), isA<Cancelled>());
    expect(source.folderCallCount, 2);
  });

  test('各 FileEntry は元場所ハンドルに対応づく(REQ-002)', () async {
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('a.txt', handle: 'content://tree/photos/a.txt'),
          _entry('a.txt', handle: 'content://tree/docs/a.txt'),
        ]),
      ],
    );

    final entries = (await source.pickFiles() as Picked).entries;

    // 同名でもハンドルが異なれば別ファイル(REQ-002)。
    expect(entries[0].sourceHandle, isNot(entries[1].sourceHandle));
    expect(entries.every((e) => e.sourceHandle != null), isTrue);
  });

  test('各 FileEntry は name・modifiedAt・size を持つ(REQ-003)', () async {
    final modified = DateTime(2026, 8, 4, 12, 30);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('memo.txt', modifiedAt: modified, size: 4096)]),
      ],
    );

    final entry = (await source.pickFiles() as Picked).entries.single;

    expect(entry.name, 'memo.txt');
    expect(entry.modifiedAt, modified);
    expect(entry.size, 4096);
    // 表示用の場所も供給される(REQ-009)。
    expect(entry.sourceLocation, 'ダウンロード');
  });
}
