// VER-004: 所属 folder ハンドル(REQ-013)と実在名の列挙(REQ-014)。
//
// 観点: 同じ場所の file は必ず同じ folder ハンドルを持ち、**別表記でも割れない**
// こと。`listNames` が**読み込んでいない file の名前も**返し、列挙できないときは
// **空の結果ではなく理由付きの失敗**を返すこと。
//
// 「空の `NamesListed`」と「`NameListFailed`」の区別が要点である。005 は前者を
// 「衝突が無い」、後者を「実行しない」と読む(005 REQ-027)。同じ値で表すと、
// 権限が無い folder が「衝突が無い」になり、読み込んでいない file を上書きしうる
// 名前で確認なしに実行へ入る。
import 'dart:io';

import 'package:batch_rename_master/data/file_source/desktop_file_source.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/file_source/platform_file_source.dart';
import 'package:batch_rename_master/data/file_source/saf_file_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Directory _tempDir(String prefix) =>
    Directory.systemTemp.createTempSync('brm-$prefix-');

void main() {
  group('REQ-013: 所属 folder ハンドル', () {
    test('同じディレクトリの file は同じ folder ハンドルを持つ', () {
      final dir = _tempDir('same-folder');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'a.txt')).writeAsStringSync('a');
      File(p.join(dir.path, 'b.txt')).writeAsStringSync('b');

      final entries = DesktopFileSource.entriesOfDirectory(dir);

      expect(entries, hasLength(2));
      expect(entries.map((e) => e.sourceFolder).toSet(), hasLength(1));
      expect(entries.first.sourceFolder, isNotNull);
    });

    test('別ディレクトリなら別の folder ハンドルになる', () {
      final a = _tempDir('folder-a');
      final b = _tempDir('folder-b');
      addTearDown(() => a.deleteSync(recursive: true));
      addTearDown(() => b.deleteSync(recursive: true));
      File(p.join(a.path, 'x.txt')).writeAsStringSync('x');
      File(p.join(b.path, 'x.txt')).writeAsStringSync('x');

      final fromA = DesktopFileSource.entriesOfDirectory(a).single;
      final fromB = DesktopFileSource.entriesOfDirectory(b).single;

      expect(fromA.sourceFolder, isNot(fromB.sourceFolder));
    });

    test('symlink 経由の別表記でも同じ folder ハンドルになる(OQ-004)', () {
      // `/sdcard/DCIM` と `/storage/emulated/0/DCIM` のような別名 path が別 key へ
      // 割れると、占有名が分割されて事前検出(005 REQ-026)がその分だけ効かない。
      final real = _tempDir('real');
      addTearDown(() => real.deleteSync(recursive: true));
      final linkPath = p.join(
        Directory.systemTemp.path,
        'brm-link-${real.path.hashCode}',
      );
      final link = Link(linkPath);
      link.createSync(real.path);
      addTearDown(() => link.deleteSync());

      final viaReal = DesktopFileSource.folderHandleOf(real.path);
      final viaLink = DesktopFileSource.folderHandleOf(linkPath);

      expect(viaLink, viaReal);
    });

    test('末尾スラッシュや `.` を含む表記でも同じ folder ハンドルになる', () {
      final dir = _tempDir('normalize');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        DesktopFileSource.folderHandleOf('${dir.path}/'),
        DesktopFileSource.folderHandleOf(dir.path),
      );
      expect(
        DesktopFileSource.folderHandleOf('${dir.path}/.'),
        DesktopFileSource.folderHandleOf(dir.path),
      );
    });

    test('SAF: 同じ親を持つ document URI は同じ folder ハンドルになる', () {
      const prefix = 'content://com.android.externalstorage.documents/document';
      final a = SafFileSource.folderHandleOfDocumentUri(
        '$prefix/${Uri.encodeComponent('primary:Download/photos/a.jpg')}',
      );
      final b = SafFileSource.folderHandleOfDocumentUri(
        '$prefix/${Uri.encodeComponent('primary:Download/photos/b.jpg')}',
      );
      final other = SafFileSource.folderHandleOfDocumentUri(
        '$prefix/${Uri.encodeComponent('primary:Download/scans/a.jpg')}',
      );

      expect(a, b);
      expect(a, isNot(other));
    });
  });

  group('REQ-014: listNames', () {
    test('読み込んでいない file の名前も返す', () async {
      final dir = _tempDir('list');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'loaded.txt')).writeAsStringSync('a');
      File(p.join(dir.path, 'never-loaded.txt')).writeAsStringSync('b');

      final result = await const DesktopFileSource().listNames(
        DesktopFileSource.folderHandleOf(dir.path),
      );

      expect(result, isA<NamesListed>());
      expect(
        (result as NamesListed).names,
        containsAll(['loaded.txt', 'never-loaded.txt']),
      );
    });

    test('サブフォルダの名前も数える', () async {
      // 名前を占めていることに変わりはない。その名前へ改名しようとすれば失敗する。
      final dir = _tempDir('subdir');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'sub')).createSync();

      final result = await const DesktopFileSource().listNames(
        DesktopFileSource.folderHandleOf(dir.path),
      );

      expect((result as NamesListed).names, contains('sub'));
    });

    test('隠しファイルもフィルタしない(決定 D-2)', () async {
      final dir = _tempDir('hidden');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, '.hidden')).writeAsStringSync('h');

      final result = await const DesktopFileSource().listNames(
        DesktopFileSource.folderHandleOf(dir.path),
      );

      expect((result as NamesListed).names, contains('.hidden'));
    });

    test('空フォルダは空の NamesListed(失敗ではない)', () async {
      final dir = _tempDir('empty');
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await const DesktopFileSource().listNames(
        DesktopFileSource.folderHandleOf(dir.path),
      );

      expect(result, isA<NamesListed>());
      expect((result as NamesListed).names, isEmpty);
    });

    test('存在しないフォルダは NameListFailed(空の結果にしない)', () async {
      final missing = p.join(
        Directory.systemTemp.path,
        'brm-does-not-exist-42',
      );

      final result = await const DesktopFileSource().listNames(missing);

      expect(
        result,
        isA<NameListFailed>(),
        reason: '「取得できなかった」を「entry が無い」と混同しない(005 REQ-027)',
      );
    });

    test('例外を投げない(REQ-014)', () async {
      // path として不正な入力でも結果型で返る。
      expect(
        () async => const DesktopFileSource().listNames(''),
        returnsNormally,
      );
      expect(
        await const DesktopFileSource().listNames(''),
        isA<NameListResult>(),
      );
    });

    test('SAF は列挙権限が無いことを理由付きで返す', () async {
      // pickFiles が取るのは1 file ずつの読み取り権限で、親 folder を列挙する
      // 権限は含まれない。**空の NamesListed にしない**(005 REQ-027)。
      final result = await SafFileSource(
        safUtil: null,
      ).listNames('content://tree/whatever');

      expect(result, isA<NameListFailed>());
      expect(
        (result as NameListFailed).error.kind,
        PickErrorKind.permissionDenied,
      );
    });

    test('未対応プラットフォームも NameListFailed を返す', () async {
      final result = await const UnsupportedFileSource().listNames('/anywhere');

      expect(result, isA<NameListFailed>());
    });
  });
}
