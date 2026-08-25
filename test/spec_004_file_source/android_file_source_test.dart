// 004 VER-004 / VER-005: Android の [FileSource](REQ-002 / REQ-013 / REQ-014)。
//
// 観点: 元場所ハンドルが**絶対 path** になること、所属 folder を保持すること、
// **`listNames` が Android で成功する**こと(005 REQ-026 の占有名がここから来る)。
//
// **実 file で確かめる。** `dart:io` の API は Android でも同じなので、Linux の
// temp directory で列挙すれば写像は閉じられる。**実機の mount 構成と権限は
// `013:T08`** が引き受ける(`task.md` の宣言表)。
import 'dart:io';

import 'package:batch_rename_master/data/file_source/android_file_source.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
      // POSIX の `stat` に作成時刻が無いので取得できない(004 REQ-003)。
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
}
