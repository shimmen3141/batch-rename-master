// VER-001(T4): 実 FileSource 実装のうち、実権限・ピッカーを伴わない部分の検証。
// 対象: REQ-002(ハンドル)/ REQ-003(作成日時は取得できたときだけ・代替しない)/
//       REQ-008(失敗の分類)/ REQ-009(表示用の場所)。
// 実権限・実ピッカー・複数フォルダ蓄積の確認はホスト側(emulator-verification.md)。
import 'dart:io';

import 'package:batch_rename_master/data/file_source/desktop_file_source.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/file_source/media_dates.dart';
import 'package:batch_rename_master/data/file_source/platform_file_source.dart';
import 'package:batch_rename_master/data/file_source/saf_file_source.dart';
import 'package:batch_rename_master/data/file_source/android_file_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

import 'support/content_fixtures.dart';

SafDocumentFile _doc({
  required String name,
  required String uri,
  bool isDir = false,
  int length = 100,
  int lastModified = 1767225600000, // 2026-01-01T00:00:00Z
}) => SafDocumentFile(
  uri: uri,
  name: name,
  isDir: isDir,
  length: length,
  lastModified: lastModified,
);

void main() {
  group('SafFileSource: SAF ドキュメント → FileEntry(REQ-002/REQ-003/REQ-009)', () {
    test('URI がハンドル、名前・更新日時・サイズが写る', () {
      final entry = SafFileSource.entryOf(
        _doc(
          name: 'a.jpg',
          uri: 'content://com.android.externalstorage/tree/x/document/y',
          length: 4096,
          lastModified: 1767225600000,
        ),
        location: 'ダウンロード',
      );

      expect(entry.name, 'a.jpg');
      expect(entry.sourceHandle, contains('content://'));
      expect(entry.size, 4096);
      expect(
        entry.modifiedAt,
        DateTime.fromMillisecondsSinceEpoch(1767225600000),
      );
      expect(entry.sourceLocation, 'ダウンロード');
    });

    test('作成日時は常に不明(SAF に列が無い。更新日時で代替しない)', () {
      final entry = SafFileSource.entryOf(
        _doc(name: 'a.jpg', uri: 'content://x'),
        location: null,
      );

      expect(entry.createdAt, isNull);
      expect(entry.modifiedAt, isNotNull);
    });

    test('個別選択では場所を持たない(親フォルダが分からないため)', () {
      final entry = SafFileSource.entryOf(
        _doc(name: 'a.jpg', uri: 'content://x'),
        location: null,
      );

      expect(entry.sourceLocation, isNull);
    });

    test('サイズ不明(-1)は 0 として扱う', () {
      final entry = SafFileSource.entryOf(
        _doc(name: 'a.jpg', uri: 'content://x', length: -1),
        location: null,
      );

      expect(entry.size, 0);
    });

    test('document URI から親フォルダ名を取り出す(REQ-009/REQ-012 の前提)', () {
      // 実機で得た実物の形(T8 のスパイクで確認したもの)。
      expect(
        SafFileSource.locationOfDocumentUri(
          'content://com.android.externalstorage.documents/document/'
          'primary%3ADownload%2Frename_test_a%2FIMG_0010.jpg',
        ),
        'rename_test_a',
      );
      expect(
        SafFileSource.locationOfDocumentUri(
          'content://com.android.externalstorage.documents/document/'
          'primary%3APictures%2Fa.jpg',
        ),
        'Pictures',
      );
    });

    test('親フォルダを導出できない形では null(ルート直下・想定外)', () {
      expect(
        SafFileSource.locationOfDocumentUri(
          'content://com.android.externalstorage.documents/document/'
          'primary%3Aa.jpg',
        ),
        isNull,
      );
      expect(SafFileSource.locationOfDocumentUri('nonsense'), isNull);
    });

    test('別フォルダの同名ファイルは異なる場所になる(REQ-012 の判定材料)', () {
      final a = SafFileSource.locationOfDocumentUri(
        'content://x/document/primary%3ADownload%2Fphotos%2FIMG.jpg',
      );
      final b = SafFileSource.locationOfDocumentUri(
        'content://x/document/primary%3ADownload%2Fdocs%2FIMG.jpg',
      );
      expect(a, 'photos');
      expect(b, 'docs');
      expect(a, isNot(b));
    });

    test('失敗の分類: 権限拒否は permissionDenied、それ以外は io(REQ-008)', () {
      expect(
        SafFileSource.errorOf(Exception('Permission denied by user')).kind,
        PickErrorKind.permissionDenied,
      );
      expect(
        SafFileSource.errorOf(Exception('SecurityException: denied')).kind,
        PickErrorKind.permissionDenied,
      );
      expect(
        SafFileSource.errorOf(Exception('failed to list documents')).kind,
        PickErrorKind.io,
      );
    });

    test('分類した失敗は理由の説明を保持する(通知に使う)', () {
      final error = SafFileSource.errorOf(Exception('Permission denied'));
      expect(error.message, contains('Permission denied'));
    });
  });

  group('DesktopFileSource: 実フォルダの列挙(REQ-002/REQ-003/REQ-009)', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('spec004_');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('直下のファイルを FileEntry にし、ハンドルは絶対パス', () {
      File('${dir.path}/a.txt').writeAsStringSync('hello');
      File('${dir.path}/b.log').writeAsStringSync('xx');

      final entries = DesktopFileSource.entriesOfDirectory(dir);

      expect(entries.map((e) => e.name).toSet(), {'a.txt', 'b.log'});
      final a = entries.firstWhere((e) => e.name == 'a.txt');
      expect(a.sourceHandle, '${dir.absolute.path}/a.txt');
      expect(a.size, 5); // 'hello'
      expect(a.modifiedAt, isNotNull);
    });

    test('中身に日時が無ければ作成日時は不明(FileStat に作成時刻が無い。更新日時で代替しない)', () {
      File('${dir.path}/a.txt').writeAsStringSync('hello');

      final entry = DesktopFileSource.entriesOfDirectory(dir).single;

      expect(entry.createdAt, isNull);
      expect(entry.modifiedAt, isNotNull);
    });

    test('動画に記録された日時が作成日時になる(REQ-010 ①。010:T02)', () {
      final utc = DateTime.utc(2026, 7, 1, 1);
      File(
        '${dir.path}/clip.mp4',
      ).writeAsBytesSync(mp4(creationSeconds1904: utcSeconds1904(utc)));

      final entry = DesktopFileSource.entriesOfDirectory(dir).single;

      expect(entry.createdAt, utc.toLocal());
    });

    test('表示用の場所は選んだフォルダ名(REQ-009)', () {
      File('${dir.path}/a.txt').writeAsStringSync('hello');

      final entry = DesktopFileSource.entriesOfDirectory(dir).single;

      expect(entry.sourceLocation, dir.path.split(Platform.pathSeparator).last);
    });

    test('サブフォルダは辿らない・含めない(スコープ外)', () {
      Directory('${dir.path}/sub').createSync();
      File('${dir.path}/sub/inner.txt').writeAsStringSync('x');
      File('${dir.path}/top.txt').writeAsStringSync('x');

      final entries = DesktopFileSource.entriesOfDirectory(dir);

      expect(entries.map((e) => e.name), ['top.txt']);
    });

    test('空フォルダは空リスト(空の Picked になる。REQ-001)', () {
      expect(DesktopFileSource.entriesOfDirectory(dir), isEmpty);
    });

    test('同名でも別フォルダならハンドルが異なる(REQ-002)', () {
      final other = Directory.systemTemp.createTempSync('spec004b_');
      addTearDown(() => other.deleteSync(recursive: true));
      File('${dir.path}/same.txt').writeAsStringSync('x');
      File('${other.path}/same.txt').writeAsStringSync('x');

      final a = DesktopFileSource.entriesOfDirectory(dir).single;
      final b = DesktopFileSource.entriesOfDirectory(other).single;

      expect(a.name, b.name);
      expect(a.sourceHandle, isNot(b.sourceHandle));
    });

    test('失敗の分類: 権限は permissionDenied、IO は io、その他は unknown(REQ-008)', () {
      expect(
        DesktopFileSource.errorOf(
          const PathAccessException('/x', OSError('denied', 13)),
        ).kind,
        PickErrorKind.permissionDenied,
      );
      expect(
        DesktopFileSource.errorOf(const FileSystemException('no such')).kind,
        PickErrorKind.io,
      );
      expect(
        DesktopFileSource.errorOf(ArgumentError('bad')).kind,
        PickErrorKind.unknown,
      );
    });

    test('存在しないフォルダの列挙は例外になり、io として分類できる', () {
      final missing = Directory('${dir.path}/nope');
      expect(
        () => DesktopFileSource.entriesOfDirectory(missing),
        throwsA(isA<FileSystemException>()),
      );
      try {
        DesktopFileSource.entriesOfDirectory(missing);
      } catch (error) {
        expect(DesktopFileSource.errorOf(error).kind, PickErrorKind.io);
      }
    });
  });

  group('createPlatformFileSource / UnsupportedFileSource(REQ-001)', () {
    Future<BrowserSelection?> noPick() async => null;

    test('実行中のプラットフォームに対して FileSource を返す', () {
      expect(createPlatformFileSource(pick: noPick), isA<FileSource>());
    });

    test('サンドボックス(Linux)ではデスクトップ実装が選ばれる', () {
      expect(createPlatformFileSource(pick: noPick), isA<DesktopFileSource>());
    }, skip: !Platform.isLinux);

    group('どの platform がどの FileSource を使うか(004 REQ-011 / REQ-015)', () {
      // **Android は app 内 file browser**、desktop は OS ピッカーのまま。
      // `Platform.isAndroid` を条件式へ直接書くと、この写像を Linux 上で
      // 固定できない(ADR-003 と同じ理由)。
      test('Android は app 内 browser を使う', () {
        expect(
          fileSourceFor(isAndroid: true, isDesktop: false, pick: noPick),
          isA<AndroidFileSource>(),
        );
      });

      test('Android は渡した MediaStore の照会を使う(004 REQ-010 ②③。010:T03)', () {
        const port = MethodChannelMediaDates();
        final android = fileSourceFor(
          isAndroid: true,
          isDesktop: false,
          pick: noPick,
          mediaDates: port,
        );
        expect((android as AndroidFileSource).mediaDates, same(port));
      });

      test('desktop は OS ピッカーのまま(013 は desktop を変えない)', () {
        expect(
          fileSourceFor(isAndroid: false, isDesktop: true, pick: noPick),
          isA<DesktopFileSource>(),
        );
      });

      test('開き直せる(004 REQ-021)のは Android だけで、渡した browser を使う', () async {
        String? opened;
        final android = fileSourceFor(
          isAndroid: true,
          isDesktop: false,
          pick: noPick,
          reopen: (folder, selected) async {
            opened = folder;
            return null;
          },
        );
        expect(android, isA<FolderReopenSource>());
        await (android as FolderReopenSource).reopenFolder(
          Directory.systemTemp.path,
          selected: const {},
        );
        expect(opened, Directory.systemTemp.path);

        expect(
          fileSourceFor(isAndroid: false, isDesktop: true, pick: noPick),
          isNot(isA<FolderReopenSource>()),
          reason: 'OS picker は選択の初期値を持てない',
        );
      });

      test('どちらでもない platform は Failed を返す実装', () {
        expect(
          fileSourceFor(isAndroid: false, isDesktop: false, pick: noPick),
          isA<UnsupportedFileSource>(),
        );
      });
    });

    test('未対応プラットフォームでは例外を投げず Failed を返す', () async {
      const source = UnsupportedFileSource();

      final result = await source.pickFiles();

      expect(result, isA<Failed>());
      expect((result as Failed).error.kind, PickErrorKind.unknown);
    });
  });
}
