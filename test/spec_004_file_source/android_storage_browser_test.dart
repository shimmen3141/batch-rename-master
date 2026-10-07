// 004 VER-005: 実 filesystem を辿る [StorageBrowserPort](REQ-015 / REQ-017)。
//
// **browser の view は fake の port で検査してある**(`storage_browser_view_test.dart`)。
// ここで閉じるのは**その port の実装**である — 実 filesystem を触るのはこの class
// だけで、ここが「読めない folder」を「空の folder」として返すと、**利用者は
// 区別できない**(独立review attempt 1 の P1-4)。
//
// `primaryRoot` と保存場所の port を注入できるので、Linux の temp directory を
// 保存場所として扱えば全域を実 file で確かめられる。
// **実機の mount 構成は `013:T08`** が引き受ける(`task.md` の宣言表)。
import 'dart:io';

import 'package:batch_rename_master/data/file_source/android_storage_browser.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/file_source/storage_browser.dart';
import 'package:batch_rename_master/data/file_source/storage_volumes.dart';
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

  /// 保存場所を返す fake。**実 filesystem を歩かない** — プラットフォームが
  /// 列挙した結果を写すのがこの実装の役目である(`013:T12`)。
  AndroidStorageBrowser browserOf({
    StorageVolumesResult volumes = const VolumesListed([]),
    String? primary,
  }) => AndroidStorageBrowser(
    primaryRoot: primary ?? p.join(dir.path, 'emulated', '0'),
    volumes: _FakeVolumes(volumes),
  );

  group('REQ-015: 保存場所の一覧', () {
    test('プラットフォームが列挙したボリュームがそのまま並ぶ', () async {
      final result = await browserOf(
        volumes: VolumesListed([
          StorageVolume(
            path: p.join(dir.path, 'emulated', '0'),
            name: '内部ストレージ',
          ),
          StorageVolume(path: p.join(dir.path, '1A2B-3C4D'), name: 'SD カード'),
        ]),
      ).locations();

      expect(result.locations.map((l) => l.name), ['内部ストレージ', 'SD カード']);
      expect(result.locations.first.root, p.join(dir.path, 'emulated', '0'));
      expect(result.failure, isNull);
    });

    test('**取得できなければ理由を返す**(「保存場所が無い」と見せない)', () async {
      // `013:T07` は `/storage` を列挙していたが、app からは `EACCES` である。
      // **黙って内部ストレージだけ返すと、装着されている媒体が無いように見える**
      // (`013:T08` の実機観測)。
      final primary = p.join(dir.path, 'emulated', '0');
      await Directory(primary).create(recursive: true);

      final result = await browserOf(
        volumes: const VolumesUnavailable('取得できませんでした: EACCES'),
        primary: primary,
      ).locations();

      expect(result.locations.map((l) => l.name), ['内部ストレージ']);
      expect(result.failure, contains('EACCES'));
    });

    test('**1件も返らないのも欠落として扱う**', () async {
      final primary = p.join(dir.path, 'emulated', '0');
      await Directory(primary).create(recursive: true);

      final result = await browserOf(
        volumes: const VolumesListed([]),
        primary: primary,
      ).locations();

      expect(result.locations.map((l) => l.name), ['内部ストレージ']);
      expect(result.failure, isNotNull);
    });

    test('**port が投げても、この関数は投げない**(browserが読み込み中で止まる)', () async {
      final primary = p.join(dir.path, 'emulated', '0');
      await Directory(primary).create(recursive: true);

      final result = await AndroidStorageBrowser(
        primaryRoot: primary,
        volumes: const _ThrowingVolumes(),
      ).locations();

      expect(result.locations.map((l) => l.name), ['内部ストレージ']);
      expect(result.failure, contains('列挙が落ちた'));
    });

    test('**拠り所の親が辿れなくても投げない**(exists は false ではなく投げる)', () async {
      // `Directory.exists()` は親を辿れないと **`false` を返さず投げる**。
      // ここで抜けると browser が読み込み中のまま止まる。
      final parent = Directory(p.join(dir.path, 'unreadable-parent'));
      await Directory(p.join(parent.path, '0')).create(recursive: true);
      final chmod = await Process.run('chmod', ['000', parent.path]);
      expect(chmod.exitCode, 0, reason: 'chmod できないと前提が崩れる');
      addTearDown(() => Process.run('chmod', ['700', parent.path]));

      final result = await AndroidStorageBrowser(
        primaryRoot: p.join(parent.path, '0'),
        volumes: const _FakeVolumes(VolumesUnavailable('EACCES')),
      ).locations();

      expect(result.locations, isEmpty);
      expect(result.failure, contains('EACCES'));
    });

    test('取得できず、内部ストレージも読めなければ空になる', () async {
      final result = await browserOf(
        volumes: const VolumesUnavailable('理由'),
        primary: p.join(dir.path, 'missing'),
      ).locations();

      expect(result.locations, isEmpty);
      expect(result.failure, isNotNull);
    });

    test('**拠り所へ落ちるのは欠落のときだけ**(取得できたら内部ストレージを足さない)', () async {
      // 足すと、プラットフォームが返した名前と二重に並ぶ。
      final primary = p.join(dir.path, 'emulated', '0');
      await Directory(primary).create(recursive: true);

      final result = await browserOf(
        volumes: VolumesListed([
          StorageVolume(path: primary, name: 'Internal shared storage'),
        ]),
        primary: primary,
      ).locations();

      expect(result.locations.map((l) => l.name), ['Internal shared storage']);
    });
  });

  group('REQ-015: 既知の場所への近道は出さない(2026-09-22に取りやめた)', () {
    test('rootの列挙は、既知の名前のfolderを1回だけ返す', () async {
      // **近道は`008:T11`で取りやめた。** 実体のfolderが一覧に並ぶだけで、
      // 同じfolderが二重に出ない。
      final root = p.join(dir.path, 'emulated', '0');
      await Directory(p.join(root, 'Download')).create(recursive: true);
      await Directory(p.join(root, 'Pictures')).create();

      final listing = await browserOf().list(root) as DirectoryListed;

      // 順序は問わない(並びは `008:T58` の test が見る)。**各1回**であることを見る。
      expect(
        listing.entries.map((e) => e.name),
        unorderedEquals(['Download', 'Pictures']),
      );
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

    test('集合は変えない(並べ替えても entry を足しも外しもしない)', () async {
      for (final name in ['b.txt', 'A.txt']) {
        await File(p.join(dir.path, name)).writeAsString('x');
      }
      for (final name in ['zdir', 'adir']) {
        await Directory(p.join(dir.path, name)).create();
      }

      final listing = await browserOf().list(dir.path) as DirectoryListed;

      expect(listing.entries.map((e) => e.name).toSet(), {
        'adir',
        'zdir',
        'A.txt',
        'b.txt',
      });
      expect(listing.entries.where((e) => e.isDirectory).length, 2);
    });
  });

  // 008:T58 2行目の更新日時・大きさと、新しい順の並び(2026-10-07 の開発者の要望)。
  group('008:T58: 更新日時と大きさ、新しい順', () {
    /// 更新日時を [at] にする。folder には `setLastModified` が無いので `touch` を使う。
    Future<void> touch(String path, DateTime at) async {
      final stamp = (at.millisecondsSinceEpoch ~/ 1000).toString();
      final result = await Process.run('touch', ['-m', '-d', '@$stamp', path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }

    final t1 = DateTime(2026, 1, 1, 9);
    final t2 = DateTime(2026, 5, 1, 9);
    final t3 = DateTime(2026, 9, 1, 9);

    test('folder が先、それぞれ更新日時の新しい順', () async {
      final files = {'old.txt': t1, 'new.txt': t3, 'mid.txt': t2};
      for (final MapEntry(key: name, value: at) in files.entries) {
        final path = p.join(dir.path, name);
        await File(path).writeAsString('x');
        await touch(path, at);
      }
      final dirs = {'adir': t1, 'zdir': t3};
      for (final MapEntry(key: name, value: at) in dirs.entries) {
        final path = p.join(dir.path, name);
        await Directory(path).create();
        await touch(path, at);
      }

      final listing = await browserOf().list(dir.path) as DirectoryListed;

      expect(listing.entries.map((e) => e.name), [
        'zdir',
        'adir',
        'new.txt',
        'mid.txt',
        'old.txt',
      ]);
    });

    test('同じ日時なら名前順(大文字・小文字を区別しない)', () async {
      for (final name in ['b.txt', 'A.txt', 'c.txt']) {
        final path = p.join(dir.path, name);
        await File(path).writeAsString('x');
        await touch(path, t2);
      }

      final listing = await browserOf().list(dir.path) as DirectoryListed;

      expect(listing.entries.map((e) => e.name), ['A.txt', 'b.txt', 'c.txt']);
    });

    test('ファイルは更新日時と大きさ、folder は更新日時だけを持つ', () async {
      final file = p.join(dir.path, 'photo.jpg');
      await File(file).writeAsBytes(List.filled(2048, 0));
      await touch(file, t2);
      final sub = p.join(dir.path, 'sub');
      await Directory(sub).create();
      await touch(sub, t1);

      final listing = await browserOf().list(dir.path) as DirectoryListed;
      final byName = {for (final e in listing.entries) e.name: e};

      expect(byName['photo.jpg']!.modifiedAt, t2);
      expect(byName['photo.jpg']!.size, 2048);
      expect(byName['sub']!.modifiedAt, t1);
      expect(byName['sub']!.size, isNull, reason: 'folder の大きさは出さない');
    });

    test('読めない entry(壊れた link)も外さず、日時と大きさを空にして最後に置く', () async {
      final file = p.join(dir.path, 'z.txt');
      await File(file).writeAsString('x');
      await touch(file, t1);
      await Link(p.join(dir.path, 'a-broken')).create(p.join(dir.path, 'gone'));

      final listing = await browserOf().list(dir.path) as DirectoryListed;

      expect(listing.entries.map((e) => e.name), ['z.txt', 'a-broken']);
      final broken = listing.entries.last;
      expect(broken.isDirectory, isFalse);
      expect(broken.modifiedAt, isNull);
      expect(broken.size, isNull);
    });
  });

  group('008:T58: compareBrowserEntries', () {
    BrowserEntry e(String name, {bool dir = false, DateTime? at}) =>
        BrowserEntry(
          name: name,
          path: '/x/$name',
          isDirectory: dir,
          modifiedAt: at,
        );

    test('日時を読めなかった folder は folder の群の最後で、ファイルより前', () {
      final entries = [
        e('f-old', at: DateTime(2020)),
        e('d-unknown', dir: true),
        e('d-new', dir: true, at: DateTime(2026)),
        e('f-unknown'),
      ]..sort(compareBrowserEntries);

      expect(entries.map((x) => x.name), [
        'd-new',
        'd-unknown',
        'f-old',
        'f-unknown',
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

/// 保存場所の列挙を差し替える fake。
class _FakeVolumes implements StorageVolumesPort {
  const _FakeVolumes(this.result);

  final StorageVolumesResult result;

  @override
  Future<StorageVolumesResult> list() async => result;
}

/// **約束を破って投げる** port。守りが構造で入っているかを見るために使う。
class _ThrowingVolumes implements StorageVolumesPort {
  const _ThrowingVolumes();

  @override
  Future<StorageVolumesResult> list() async => throw StateError('列挙が落ちた');
}
