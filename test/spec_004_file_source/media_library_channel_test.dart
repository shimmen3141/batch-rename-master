// 004 REQ-022: 写真・動画とアルバムの一覧を platform から受け取る側の写像(`010:T06`)。
//
// **Kotlin 側の照会そのものは、ここでは分からない。** channel の相手を差し替えて、
// 何を頼み、返ってきた値をどう読むかだけを閉じる。端末は `010:T07` の manual が
// 引き受ける。

import 'package:batch_rename_master/data/file_source/media_library.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const port = MethodChannelMediaLibrary();

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      MethodChannelMediaLibrary.channel,
      handler,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        MethodChannelMediaLibrary.channel,
        null,
      ),
    );
  }

  final taken = DateTime.utc(2026, 10, 5, 1, 2, 3);
  final added = DateTime.utc(2026, 10, 4, 9);

  Map<String, Object?> photoRow({int id = 1, String path = '/p/a.jpg'}) => {
    'id': id,
    'path': path,
    'kind': 'photo',
    'taken': taken.millisecondsSinceEpoch,
    'added': added.millisecondsSinceEpoch ~/ 1000,
    'duration': null,
    'albumId': -12345,
  };

  group('page', () {
    test('種類・アルバム・範囲を渡す', () async {
      final received = <MethodCall>[];
      answerWith((call) async {
        received.add(call);
        return <Object?>[];
      });

      await port.page(
        const MediaFilter(kind: MediaKindFilter.videos, albumId: 7),
        offset: 40,
        limit: 20,
      );
      await port.page(const MediaFilter(), offset: 0, limit: 10);
      await port.page(
        const MediaFilter(kind: MediaKindFilter.photos),
        offset: 0,
        limit: 10,
      );

      expect(received.map((call) => call.method), everyElement('page'));
      expect(received[0].arguments, {
        'kind': 'videos',
        'albumId': 7,
        'offset': 40,
        'limit': 20,
      });
      // 既定は「すべて」「すべてのアルバム」(004 REQ-022: 最初は全件)。
      expect(received[1].arguments, {
        'kind': 'all',
        'albumId': null,
        'offset': 0,
        'limit': 10,
      });
      expect((received[2].arguments as Map)['kind'], 'photos');
    });

    test('日時は端末の時刻帯、動画には再生時間、アルバムの id は負でも保つ', () async {
      answerWith(
        (call) async => [
          photoRow(),
          {
            'id': 2,
            'path': '/v/b.mp4',
            'kind': 'video',
            'taken': null,
            'added': added.millisecondsSinceEpoch ~/ 1000,
            'duration': 83500,
            'albumId': 9,
          },
        ],
      );

      final result = await port.page(const MediaFilter(), offset: 0, limit: 10);

      final items = (result as MediaPage).items;
      expect(items, hasLength(2));
      final photo = items[0];
      expect(photo.id, 1);
      expect(photo.path, '/p/a.jpg');
      expect(photo.kind, MediaKind.photo);
      expect(photo.taken, taken.toLocal());
      expect(photo.added, added.toLocal());
      expect(photo.duration, isNull);
      expect(photo.albumId, -12345);
      // 並び順と見出しの日付は DATE_TAKEN(REQ-022)。
      expect(photo.date, taken.toLocal());

      final video = items[1];
      expect(video.kind, MediaKind.video);
      expect(video.duration, const Duration(milliseconds: 83500));
      // DATE_TAKEN が無ければ DATE_ADDED(REQ-022)。
      expect(video.taken, isNull);
      expect(video.date, added.toLocal());
    });

    test('写真に再生時間は付けない・0 は「記録していない」', () async {
      answerWith(
        (call) async => [
          {...photoRow(), 'duration': 5000, 'taken': 0, 'added': 0},
          {...photoRow(id: 2), 'kind': 'video', 'duration': 0, 'albumId': null},
        ],
      );

      final items =
          ((await port.page(const MediaFilter(), offset: 0, limit: 10))
                  as MediaPage)
              .items;

      expect(items[0].duration, isNull);
      expect(items[0].taken, isNull);
      expect(items[0].added, isNull);
      expect(items[0].date, isNull);
      expect(items[1].duration, isNull);
      expect(items[1].albumId, isNull);
    });

    test('形の崩れた行は落とすが、続きの有無は届いた行数で決める', () async {
      answerWith(
        (call) async => [
          photoRow(),
          'not a map',
          {...photoRow(id: 3), 'path': ''},
          {...photoRow(id: 4), 'kind': 'audio'},
          {...photoRow(id: 5), 'id': '5'},
        ],
      );

      final result = await port.page(const MediaFilter(), offset: 0, limit: 5);

      final page = result as MediaPage;
      expect(page.items.map((item) => item.id), [1]);
      expect(page.hasMore, isTrue);
    });

    test('limit に満たなければ続きは無い・空でも「取れた」', () async {
      answerWith((call) async => [photoRow()]);
      final short = await port.page(const MediaFilter(), offset: 0, limit: 2);
      expect((short as MediaPage).hasMore, isFalse);

      answerWith((call) async => <Object?>[]);
      final empty = await port.page(const MediaFilter(), offset: 0, limit: 2);
      expect(empty, isA<MediaPage>());
      expect((empty as MediaPage).items, isEmpty);
      expect(empty.hasMore, isFalse);
    });

    test('失敗・応答なし・想定外の値・channel が無いは「取れなかった」(空と混同しない)', () async {
      answerWith((call) async => throw PlatformException(code: 'failed'));
      expect(
        await port.page(const MediaFilter(), offset: 0, limit: 2),
        isA<MediaPageFailed>(),
      );

      answerWith((call) async => null);
      expect(
        await port.page(const MediaFilter(), offset: 0, limit: 2),
        isA<MediaPageFailed>(),
      );

      answerWith((call) async => {'not': 'a list'});
      expect(
        await port.page(const MediaFilter(), offset: 0, limit: 2),
        isA<MediaPageFailed>(),
      );

      // 相手が居ない(MissingPluginException)。
      messenger.setMockMethodCallHandler(
        MethodChannelMediaLibrary.channel,
        null,
      );
      final missing = await port.page(const MediaFilter(), offset: 0, limit: 2);
      expect(missing, isA<MediaPageFailed>());
      expect((missing as MediaPageFailed).reason, contains('写真・動画'));
    });
  });

  group('albums', () {
    test('名前・件数・場所・代表の item を読む。名前が無ければ folder の名前', () async {
      MethodCall? received;
      answerWith((call) async {
        received = call;
        return [
          {
            'id': -12345,
            'name': 'Camera',
            'folder': '/storage/emulated/0/DCIM/Camera',
            'count': 3,
            'cover': photoRow(),
          },
          {
            'id': 9,
            'name': null,
            'folder': '/storage/1234-5678/Pictures/Trip',
            'count': 1,
            'cover': 'broken',
          },
        ];
      });

      final result = await port.albums();

      expect(received!.method, 'albums');
      final albums = (result as MediaAlbumsListed).albums;
      expect(albums, hasLength(2));
      expect(albums[0].id, -12345);
      expect(albums[0].name, 'Camera');
      expect(albums[0].folder, '/storage/emulated/0/DCIM/Camera');
      expect(albums[0].count, 3);
      expect(albums[0].cover!.path, '/p/a.jpg');
      expect(albums[1].name, 'Trip');
      expect(albums[1].cover, isNull);
    });

    test('id・場所・件数が無い行は落とす', () async {
      answerWith(
        (call) async => [
          {'id': 1, 'folder': '/a', 'count': 1},
          {'folder': '/b', 'count': 1},
          {'id': 2, 'folder': '', 'count': 1},
          {'id': 3, 'folder': '/c'},
          'not a map',
        ],
      );

      final albums = ((await port.albums()) as MediaAlbumsListed).albums;

      expect(albums.map((album) => album.id), [1]);
    });

    test('失敗・応答なし・channel が無いは「取れなかった」', () async {
      answerWith((call) async => throw PlatformException(code: 'failed'));
      expect(await port.albums(), isA<MediaAlbumsFailed>());

      answerWith((call) async => null);
      expect(await port.albums(), isA<MediaAlbumsFailed>());

      answerWith((call) async => <Object?>[]);
      expect(await port.albums(), isA<MediaAlbumsListed>());

      messenger.setMockMethodCallHandler(
        MethodChannelMediaLibrary.channel,
        null,
      );
      expect(await port.albums(), isA<MediaAlbumsFailed>());
    });
  });

  group('thumbnail', () {
    const video = MediaItem(id: 42, path: '/v/b.mp4', kind: MediaKind.video);

    test('id・種類・大きさを渡し、bytes を返す', () async {
      MethodCall? received;
      answerWith((call) async {
        received = call;
        return Uint8List.fromList([1, 2, 3]);
      });

      final bytes = await port.thumbnail(video, maxEdge: 192);

      expect(received!.method, 'thumbnail');
      expect(received!.arguments, {'id': 42, 'kind': 'video', 'maxEdge': 192});
      expect(bytes, [1, 2, 3]);
    });

    test('作れなければ null(選ぶことはできる)', () async {
      answerWith((call) async => throw PlatformException(code: 'failed'));
      expect(await port.thumbnail(video, maxEdge: 192), isNull);

      answerWith((call) async => null);
      expect(await port.thumbnail(video, maxEdge: 192), isNull);
    });
  });
}
