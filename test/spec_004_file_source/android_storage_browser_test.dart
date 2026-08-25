// 004 VER-005: 実 filesystem を辿る [StorageBrowserPort](REQ-015 / REQ-017)。
//
// **browser の view は fake の port で検査してある**(`storage_browser_view_test.dart`)。
// ここで閉じるのは**その port の実装**である — 実 filesystem を触るのはこの class
// だけで、ここが「読めない folder」を「空の folder」として返すと、**利用者は
// 区別できない**(独立review attempt 1 の P1-4)。
//
// `primaryRoot` / `volumesDirectory` を注入できるので、Linux の temp directory を
// 保存場所として扱えば全域を実 file で確かめられる。
// **実機の mount 構成は `013:T08`** が引き受ける(`task.md` の宣言表)。
import 'dart:io';

import 'package:batch_rename_master/data/file_source/android_storage_browser.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/file_source/storage_browser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-storage-browser-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// [dir] を `/storage` に見立てた browser。
  AndroidStorageBrowser browserOf({String? primary}) => AndroidStorageBrowser(
    primaryRoot: primary ?? p.join(dir.path, 'emulated', '0'),
    volumesDirectory: dir.path,
  );

  group('REQ-015: 保存場所の一覧', () {
    test('内部共有ストレージと、装着されているボリュームが並ぶ', () async {
      await Directory(
        p.join(dir.path, 'emulated', '0'),
      ).create(recursive: true);
      await Directory(p.join(dir.path, '1A2B-3C4D')).create();

      final locations = await browserOf().locations();

      expect(locations.map((l) => l.name), ['内部ストレージ', '1A2B-3C4D']);
      expect(locations.first.root, p.join(dir.path, 'emulated', '0'));
    });

    test('`emulated` と `self` は保存場所にしない', () async {
      // **内部共有ストレージの上位を保存場所にすると、その root から
      // 兄弟 profile へ辿れてしまう**(REQ-015 の上限が破れる)。
      await Directory(
        p.join(dir.path, 'emulated', '0'),
      ).create(recursive: true);
      await Directory(p.join(dir.path, 'self')).create();

      final locations = await browserOf().locations();

      expect(locations.map((l) => l.name), ['内部ストレージ']);
      expect(
        locations.map((l) => l.root),
        isNot(contains(p.join(dir.path, 'emulated'))),
      );
    });

    test('fileは保存場所にしない', () async {
      await Directory(
        p.join(dir.path, 'emulated', '0'),
      ).create(recursive: true);
      await File(p.join(dir.path, 'not-a-volume')).writeAsString('x');

      final locations = await browserOf().locations();

      expect(locations.map((l) => l.name), ['内部ストレージ']);
    });

    test('列挙できなくても内部ストレージだけは返す(「保存場所が無い」と見せない)', () async {
      final primary = p.join(dir.path, 'emulated', '0');
      await Directory(primary).create(recursive: true);
      final browser = AndroidStorageBrowser(
        primaryRoot: primary,
        volumesDirectory: p.join(dir.path, 'missing'),
      );

      final locations = await browser.locations();

      expect(locations.map((l) => l.name), ['内部ストレージ']);
    });

    test('内部ストレージが無ければ出さない', () async {
      await Directory(p.join(dir.path, '1A2B-3C4D')).create();

      final locations = await browserOf().locations();

      expect(locations.map((l) => l.name), ['1A2B-3C4D']);
    });
  });

  group('REQ-015: 既知の場所への近道', () {
    test('実在するものだけを、決まった順で返す', () async {
      final root = p.join(dir.path, 'emulated', '0');
      await Directory(p.join(root, 'Download')).create(recursive: true);
      await Directory(p.join(root, 'Pictures')).create();
      // `DCIM` は作らない。
      final location = StorageLocation(name: '内部ストレージ', root: root);

      final shortcuts = await browserOf().shortcuts(location);

      expect(shortcuts.map((s) => s.name), ['Download', 'Pictures']);
      expect(shortcuts.every((s) => s.isDirectory), isTrue);
      expect(shortcuts.first.path, p.join(root, 'Download'));
    });

    test('1つも実在しなければ空(開いても空か失敗するだけの近道を出さない)', () async {
      final root = p.join(dir.path, 'emulated', '0');
      await Directory(root).create(recursive: true);

      final shortcuts = await browserOf().shortcuts(
        StorageLocation(name: '内部ストレージ', root: root),
      );

      expect(shortcuts, isEmpty);
    });
  });

  group('REQ-017: 絞り込まない', () {
    test('隠しfileもサブfolderもそのまま返す', () async {
      await File(p.join(dir.path, 'memo.txt')).writeAsString('x');
      await File(p.join(dir.path, '.hidden')).writeAsString('x');
      await Directory(p.join(dir.path, 'sub')).create();

      final listing = await browserOf().list(dir.path) as DirectoryListed;

      expect(listing.entries.map((e) => e.name).toSet(), {
        'memo.txt',
        '.hidden',
        'sub',
      });
    });

    test('folderが先、その中で名前順(集合は変えない)', () async {
      for (final name in ['b.txt', 'A.txt']) {
        await File(p.join(dir.path, name)).writeAsString('x');
      }
      for (final name in ['zdir', 'adir']) {
        await Directory(p.join(dir.path, name)).create();
      }

      final listing = await browserOf().list(dir.path) as DirectoryListed;

      expect(listing.entries.map((e) => e.name), [
        'adir',
        'zdir',
        'A.txt',
        'b.txt',
      ]);
      expect(listing.entries.map((e) => e.isDirectory), [
        true,
        true,
        false,
        false,
      ]);
    });
  });

  group('「読めなかった」と「entryが無い」を型で区別する', () {
    test('空folderは空の DirectoryListed', () async {
      final empty = await Directory(p.join(dir.path, 'empty')).create();

      final listing = await browserOf().list(empty.path);

      expect(listing, isA<DirectoryListed>());
      expect((listing as DirectoryListed).entries, isEmpty);
    });

    test('読めないfolderは DirectoryListingFailed(空のfolderに見せない)', () async {
      final locked = await Directory(p.join(dir.path, 'locked')).create();
      await File(p.join(locked.path, 'inner.txt')).writeAsString('x');
      await Process.run('chmod', ['000', locked.path]);
      addTearDown(() => Process.run('chmod', ['755', locked.path]));

      final listing = await browserOf().list(locked.path);

      expect(listing, isA<DirectoryListingFailed>());
      expect(
        (listing as DirectoryListingFailed).error.kind,
        PickErrorKind.permissionDenied,
      );
    });

    test('存在しないfolderも失敗として返す(例外を投げない)', () async {
      final listing = await browserOf().list(p.join(dir.path, 'missing'));

      expect(listing, isA<DirectoryListingFailed>());
    });
  });
}
