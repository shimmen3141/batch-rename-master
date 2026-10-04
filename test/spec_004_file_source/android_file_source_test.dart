// 004 VER-004 / VER-005: Android の [FileSource](REQ-002 / REQ-013 / REQ-014)。
//
// 観点: 元場所ハンドルが**絶対 path** になること、所属 folder を保持すること、
// **`listNames` が Android で成功する**こと(005 REQ-026 の占有名がここから来る)。
//
// **実 file で確かめる。** `dart:io` の API は Android でも同じなので、Linux の
// temp directory で列挙すれば写像は閉じられる。**実機の mount 構成と権限は
// `013:T08`** が引き受ける(`task.md` の宣言表)。
import 'dart:io';

import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/android_file_source.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/file_source/media_dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/content_fixtures.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-android-source-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<String> makeFile(String name, [String body = 'x']) async {
    final file = File(p.join(dir.path, name));
    await file.writeAsString(body);
    return file.path;
  }

  group('REQ-010 ①: ファイルの中身の日時を作成日時にする(010:T02)', () {
    test('EXIF の撮影日時を持つ写真は、その日時が作成日時になる(代表例 10・44)', () async {
      final photo = p.join(dir.path, 'photo.jpg');
      File(
        photo,
      ).writeAsBytesSync(jpeg(tiff(dateTimeOriginal: '2026:07:01 10:00:00')));
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: dir.path, paths: [photo]),
      );

      final result = await source.pickFiles() as Picked;

      expect(result.entries.single.createdAt, DateTime(2026, 7, 1, 10));
    });

    test('壊れたファイルが混ざっても読み込みは成功し、そのファイルだけ不明(代表例 52)', () async {
      final good = p.join(dir.path, 'good.jpg');
      File(
        good,
      ).writeAsBytesSync(jpeg(tiff(dateTimeOriginal: '2026:07:01 10:00:00')));
      final broken = p.join(dir.path, 'broken.jpg');
      File(broken).writeAsBytesSync(
        jpeg(tiff(dateTimeOriginal: '2026:07:01 10:00:00')).sublist(0, 30),
      );
      final source = AndroidFileSource(
        pick: () async =>
            BrowserSelection(folder: dir.path, paths: [good, broken]),
      );

      final result = await source.pickFiles() as Picked;

      final byName = {for (final e in result.entries) e.name: e};
      expect(byName.keys, {'good.jpg', 'broken.jpg'});
      expect(byName['good.jpg']!.createdAt, DateTime(2026, 7, 1, 10));
      expect(byName['broken.jpg']!.createdAt, isNull);
    });
  });

  group('REQ-010 ②③: MediaStore の日時で補う(010:T03)', () {
    final taken = DateTime(2026, 7, 1, 10);
    final added = DateTime(2026, 9, 1, 12);

    Future<Map<String, FileEntry>> load(
      List<String> paths,
      _FakeMediaDates port,
    ) async {
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: dir.path, paths: paths),
        mediaDates: port,
      );
      final result = await source.pickFiles() as Picked;
      return {for (final e in result.entries) e.name: e};
    }

    test('中身の日時(①)があれば MediaStore より先(代表例 47)', () async {
      final photo = p.join(dir.path, 'photo.jpg');
      File(
        photo,
      ).writeAsBytesSync(jpeg(tiff(dateTimeOriginal: '2020:01:02 03:04:05')));
      final port = _FakeMediaDates({
        photo: MediaDates(taken: taken, added: added),
      });

      final byName = await load([photo], port);

      expect(byName['photo.jpg']!.createdAt, DateTime(2020, 1, 2, 3, 4, 5));
      // ①がある file は照会しない。
      expect(port.asked, isEmpty);
    });

    test('①が無ければ DATE_TAKEN(②。代表例 48)、それも無ければ DATE_ADDED(③。代表例 49)', () async {
      final shot = await makeFile('shot.png');
      final download = await makeFile('doc.pdf');
      final own = await makeFile('own.txt');
      final port = _FakeMediaDates({
        shot: MediaDates(taken: taken, added: added),
        download: MediaDates(added: added),
        // own.txt は MediaStore に載っていない(この app が作った file)。
      });

      final byName = await load([shot, download, own], port);

      expect(byName['shot.png']!.createdAt, taken);
      expect(byName['doc.pdf']!.createdAt, added);
      expect(
        byName['own.txt']!.createdAt,
        isNull,
        reason: '①〜③が無ければ不明(代表例 53)',
      );
      expect(port.asked.single, unorderedEquals([shot, download, own]));
    });

    test('補っても他の項目は変えない', () async {
      final download = await makeFile('doc.pdf', 'hello');
      final port = _FakeMediaDates({download: MediaDates(added: added)});

      final entry = (await load([download], port))['doc.pdf']!;

      expect(entry.sourceHandle, download);
      expect(entry.sourceFolder, dir.path);
      expect(entry.size, 5);
      expect(entry.selected, isTrue);
    });

    test('照会が失敗しても読み込みは成功し、不明のまま', () async {
      final download = await makeFile('doc.pdf');

      final byName = await load([download], _FakeMediaDates.failing());

      expect(byName['doc.pdf']!.createdAt, isNull);
    });

    test('開き直し(REQ-021)でも補う', () async {
      final download = await makeFile('doc.pdf');
      final source = AndroidFileSource(
        pick: () async => null,
        reopen: (folder, selected) async =>
            BrowserSelection(folder: folder, paths: [download]),
        mediaDates: _FakeMediaDates({download: MediaDates(added: added)}),
      );

      final result =
          await source.reopenFolder(dir.path, selected: const {}) as Picked;

      expect(result.entries.single.createdAt, added);
    });
  });

  group('REQ-002 / REQ-013: 元場所ハンドルは絶対pathで、所属folderを保持する', () {
    test('選んだfileが絶対pathのハンドルと所属folderを持つ', () async {
      final a = await makeFile('a.txt', 'hello');
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: dir.path, paths: [a]),
      );

      final result = await source.pickFiles() as Picked;

      expect(result.entries, hasLength(1));
      final entry = result.entries.single;
      expect(entry.name, 'a.txt');
      expect(entry.sourceHandle, a, reason: 'SAF の URI ではなく絶対 path');
      expect(entry.sourceFolder, dir.path, reason: '所属 folder を保持する');
      expect(entry.size, 5);
      expect(entry.modifiedAt, isNotNull);
      // 中身に日時が無く、POSIX の `stat` にも作成時刻が無い(004 REQ-003)。
      expect(entry.createdAt, isNull);
    });

    test('所属folderはbrowserが確定した値で、ハンドルから導出しない', () async {
      // **導出すると、browser が「どの folder を見ていたか」が失われる**
      // (004 REQ-013 / OQ-004)。symlink や `.` を含む path では `dirname` と
      // 確定値が一致しない。005 の衝突判定は folder 単位なので、ここがずれると
      // 別 folder の名前を同じ folder のものとして数えうる。
      final a = await makeFile('a.txt');
      final viaDot = p.join(dir.path, '.');
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: viaDot, paths: [a]),
      );

      final result = await source.pickFiles() as Picked;

      expect(
        result.entries.single.sourceFolder,
        viaDot,
        reason: 'browser が確定した値をそのまま持つ',
      );
      expect(
        result.entries.single.sourceFolder,
        isNot(p.dirname(a)),
        reason: 'ハンドルから導出していない',
      );
    });

    test('別の保存場所を跨いでもfolderの区別が失われない', () async {
      // browser の選択は同一 folder 内に限るので、跨ぐのは**読み込みを重ねた**
      // ときである。`sourceFolder` が別なら、005 の衝突判定は folder 単位で
      // 正しく効く(`013:T10`)。
      final sd = await Directory(p.join(dir.path, 'sd')).create();
      final internal = await Directory(p.join(dir.path, 'internal')).create();
      final one = File(p.join(sd.path, 'x.txt'))..writeAsStringSync('1');
      final two = File(p.join(internal.path, 'x.txt'))..writeAsStringSync('2');

      final fromSd =
          await AndroidFileSource(
                pick: () async =>
                    BrowserSelection(folder: sd.path, paths: [one.path]),
              ).pickFiles()
              as Picked;
      final fromInternal =
          await AndroidFileSource(
                pick: () async =>
                    BrowserSelection(folder: internal.path, paths: [two.path]),
              ).pickFiles()
              as Picked;

      expect(fromSd.entries.single.sourceFolder, sd.path);
      expect(fromInternal.entries.single.sourceFolder, internal.path);
      expect(
        fromSd.entries.single.sourceFolder,
        isNot(fromInternal.entries.single.sourceFolder),
        reason: '同名でも別 folder として区別される',
      );
    });

    test('表示用の場所は人間可読にする(rootのbasenameは意味を持たない)', () async {
      // `/storage/emulated/0` の basename は `0` で、行に出しても意味が無い
      // (004 REQ-009 は人間可読を求めている)。browser が知っている保存場所名を
      // 使う(独立review attempt 1 の P2-8)。
      final a = await makeFile('a.txt');
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: dir.path, paths: [a]),
        locationNameOf: (folder) =>
            folder == dir.path ? '内部ストレージ' : p.basename(folder),
      );

      final result = await source.pickFiles() as Picked;

      expect(result.entries.single.sourceLocation, '内部ストレージ');
    });

    test('保存場所名が分からなければ basename へ落とす', () async {
      final a = await makeFile('a.txt');
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: dir.path, paths: [a]),
      );

      final result = await source.pickFiles() as Picked;

      expect(result.entries.single.sourceLocation, p.basename(dir.path));
    });

    test('選んだ直後に消えていたfileは落とす(空リストで混同しない)', () async {
      final a = await makeFile('a.txt');
      final missing = p.join(dir.path, 'gone.txt');
      final source = AndroidFileSource(
        pick: () async =>
            BrowserSelection(folder: dir.path, paths: [a, missing]),
      );

      final result = await source.pickFiles() as Picked;

      expect(result.entries.map((e) => e.name), ['a.txt']);
    });
  });

  group('004 REQ-001: 決定していない / 失敗を型で区別する', () {
    test('browserを閉じたら Cancelled', () async {
      final source = AndroidFileSource(pick: () async => null);
      expect(await source.pickFiles(), isA<Cancelled>());
    });

    test('browserが投げても例外を通さず Failed にする', () async {
      final source = AndroidFileSource(
        pick: () async => throw StateError('boom'),
      );
      expect(await source.pickFiles(), isA<Failed>());
    });

    test('0件で確定したら空の Picked(Cancelled と混同しない)', () async {
      final source = AndroidFileSource(
        pick: () async => BrowserSelection(folder: dir.path, paths: const []),
      );
      final result = await source.pickFiles();
      expect(result, isA<Picked>());
      expect((result as Picked).entries, isEmpty);
    });
  });

  group('REQ-014: listNames が Android で成功する', () {
    test('読み込んでいないfileもサブfolderも隠しfileも含む', () async {
      await makeFile('loaded.txt');
      await makeFile('not-loaded.jpg');
      await makeFile('.hidden');
      await Directory(p.join(dir.path, 'sub')).create();
      final source = AndroidFileSource(pick: () async => null);

      final result = await source.listNames(dir.path) as NamesListed;

      expect(result.names, {'loaded.txt', 'not-loaded.jpg', '.hidden', 'sub'});
    });

    test('空フォルダは空の NamesListed(失敗と混同しない)', () async {
      final empty = await Directory(p.join(dir.path, 'empty')).create();
      final source = AndroidFileSource(pick: () async => null);

      final result = await source.listNames(empty.path);

      expect(result, isA<NamesListed>());
      expect((result as NamesListed).names, isEmpty);
    });

    test('列挙できなければ NameListFailed(例外を投げない)', () async {
      final source = AndroidFileSource(pick: () async => null);

      final result = await source.listNames(p.join(dir.path, 'missing'));

      expect(result, isA<NameListFailed>());
    });

    test('読めないfolderは permissionDenied として返す', () async {
      final locked = await Directory(p.join(dir.path, 'locked')).create();
      await File(p.join(locked.path, 'inner.txt')).writeAsString('x');
      await Process.run('chmod', ['000', locked.path]);
      addTearDown(() => Process.run('chmod', ['755', locked.path]));
      final source = AndroidFileSource(pick: () async => null);

      final result = await source.listNames(locked.path);

      expect(result, isA<NameListFailed>());
      expect(
        (result as NameListFailed).error.kind,
        PickErrorKind.permissionDenied,
      );
    });
  });

  group('REQ-021: 一覧の所属folderを、一覧の状態を初期値にして開き直す', () {
    test('folderと一覧のハンドルを渡して開き、確定を Picked にする', () async {
      final a = await makeFile('a.txt');
      final b = await makeFile('b.txt');
      String? openedFolder;
      Set<String>? openedWith;
      final source = AndroidFileSource(
        pick: () async => fail('開き直しで pick は使わない'),
        reopen: (folder, selected) async {
          openedFolder = folder;
          openedWith = selected;
          return BrowserSelection(folder: folder, paths: [a, b]);
        },
      );

      final result =
          await source.reopenFolder(dir.path, selected: {a}) as Picked;

      expect(openedFolder, dir.path);
      expect(openedWith, {a});
      expect(result.entries.map((e) => e.sourceHandle), [a, b]);
      expect(result.entries.map((e) => e.sourceFolder).toSet(), {dir.path});
    });

    test('閉じたら Cancelled(代表例 39)', () async {
      final source = AndroidFileSource(
        pick: () async => null,
        reopen: (folder, selected) async => null,
      );

      expect(
        await source.reopenFolder(dir.path, selected: const {}),
        isA<Cancelled>(),
      );
    });

    test('代表例 42: folder が無ければ browser を開かずに Failed', () async {
      var opened = false;
      final source = AndroidFileSource(
        pick: () async => null,
        reopen: (folder, selected) async {
          opened = true;
          return null;
        },
      );

      final result = await source.reopenFolder(
        p.join(dir.path, 'gone'),
        selected: const {},
      );

      expect(result, isA<Failed>());
      expect(opened, isFalse, reason: 'browser に入らない');
    });

    test('開き直す browser が無ければ Failed(例外を投げない)', () async {
      final source = AndroidFileSource(pick: () async => null);

      expect(
        await source.reopenFolder(dir.path, selected: const {}),
        isA<Failed>(),
      );
    });

    test('browser が投げても Failed にする', () async {
      final source = AndroidFileSource(
        pick: () async => null,
        reopen: (folder, selected) async => throw StateError('壊れた'),
      );

      expect(
        await source.reopenFolder(dir.path, selected: const {}),
        isA<Failed>(),
      );
    });
  });
}

class _FakeMediaDates implements MediaDatesPort {
  _FakeMediaDates(this.dates) : fails = false;
  _FakeMediaDates.failing() : dates = const {}, fails = true;

  final Map<String, MediaDates> dates;
  final bool fails;
  final asked = <List<String>>[];

  @override
  Future<Map<String, MediaDates>> datesOf(List<String> paths) async {
    asked.add(paths);
    if (fails) throw StateError('照会できない');
    // 尋ねられていない path の値も返す。①がある file を照会しないことと、
    // 返ってきても上書きしないことを、別々に確かめるためである。
    return dates;
  }
}
