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

  group('list', () {
    test('全件を頼む(絞り込みと並べ替えは app の側。010:T11)', () async {
      MethodCall? received;
      answerWith((call) async {
        received = call;
        return <Object?>[];
      });

      await port.list();

      expect(received!.method, 'list');
      expect(received!.arguments, isNull);
    });

    test('日時は端末の時刻帯、動画には再生時間、アルバムの id は負でも保つ', () async {
      final modified = DateTime.utc(2026, 10, 5, 3);
      answerWith(
        (call) async => [
          {...photoRow(), 'modified': modified.millisecondsSinceEpoch ~/ 1000},
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

      final result = await port.list();

      final items = (result as MediaListed).items;
      expect(items, hasLength(2));
      final photo = items[0];
      expect(photo.id, 1);
      expect(photo.path, '/p/a.jpg');
      expect(photo.kind, MediaKind.photo);
      expect(photo.taken, taken.toLocal());
      expect(photo.added, added.toLocal());
      expect(photo.modified, modified.toLocal());
      expect(photo.content, isNull, reason: '中身の日時は channel からは来ない');
      expect(photo.duration, isNull);
      expect(photo.albumId, -12345);
      // 並び順と見出しの日付は DATE_TAKEN(REQ-022)。
      expect(photo.date, taken.toLocal());

      final video = items[1];
      expect(video.kind, MediaKind.video);
      expect(video.duration, const Duration(milliseconds: 83500));
      expect(video.modified, isNull);
      // DATE_TAKEN が無く、中身の日時もまだ無ければ DATE_ADDED(REQ-022)。
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

      final items = ((await port.list()) as MediaListed).items;

      expect(items[0].duration, isNull);
      expect(items[0].taken, isNull);
      expect(items[0].added, isNull);
      expect(items[0].date, isNull);
      expect(items[1].duration, isNull);
      expect(items[1].albumId, isNull);
    });

    test('形の崩れた行は落とす', () async {
      answerWith(
        (call) async => [
          photoRow(),
          'not a map',
          {...photoRow(id: 3), 'path': ''},
          {...photoRow(id: 4), 'kind': 'audio'},
          {...photoRow(id: 5), 'id': '5'},
        ],
      );

      final items = ((await port.list()) as MediaListed).items;

      expect(items.map((item) => item.id), [1]);
    });

    test('空でも「取れた」', () async {
      answerWith((call) async => <Object?>[]);
      final empty = await port.list();
      expect(empty, isA<MediaListed>());
      expect((empty as MediaListed).items, isEmpty);
    });

    test('失敗・応答なし・想定外の値・channel が無いは「取れなかった」(空と混同しない)', () async {
      answerWith((call) async => throw PlatformException(code: 'failed'));
      expect(await port.list(), isA<MediaListFailed>());

      answerWith((call) async => null);
      expect(await port.list(), isA<MediaListFailed>());

      answerWith((call) async => {'not': 'a list'});
      expect(await port.list(), isA<MediaListFailed>());

      // 相手が居ない(MissingPluginException)。
      messenger.setMockMethodCallHandler(
        MethodChannelMediaLibrary.channel,
        null,
      );
      final missing = await port.list();
      expect(missing, isA<MediaListFailed>());
      expect((missing as MediaListFailed).reason, contains('写真・動画'));
    });
  });

  group('並び順と絞り込み(app の側。004 REQ-022)', () {
    MediaItem item(
      int id, {
      DateTime? taken,
      DateTime? content,
      DateTime? added,
      MediaKind kind = MediaKind.photo,
      int? albumId,
    }) => MediaItem(
      id: id,
      path: '/p$id',
      kind: kind,
      taken: taken,
      added: added,
      albumId: albumId,
    ).withContent(content);

    test('日付は DATE_TAKEN → 中身の日時 → DATE_ADDED', () {
      final t = DateTime(2026, 10, 5);
      final c = DateTime(2008, 5, 30);
      final a = DateTime(2026, 10, 4);
      expect(item(1, taken: t, content: c, added: a).date, t);
      expect(item(2, content: c, added: a).date, c);
      expect(item(3, added: a).date, a);
      expect(item(4).date, isNull);
    });

    test('新しい順、日時の無いものは最後、同じ日時は id の大きい順', () {
      final day = DateTime(2026, 10, 5);
      final sorted = sortedByDate([
        item(1, added: day),
        item(2),
        item(3, content: DateTime(2008, 5, 30)),
        item(4, taken: DateTime(2026, 10, 6)),
        item(5, added: day),
      ]);
      expect(sorted.map((e) => e.id), [4, 5, 1, 3, 2]);
    });

    test('種類とアルバムで絞る', () {
      final photo = item(1, albumId: 7);
      final video = item(2, kind: MediaKind.video, albumId: 8);
      expect(const MediaFilter().matches(photo), isTrue);
      expect(
        const MediaFilter(kind: MediaKindFilter.photos).matches(video),
        isFalse,
      );
      expect(
        const MediaFilter(kind: MediaKindFilter.videos).matches(video),
        isTrue,
      );
      expect(const MediaFilter(albumId: 7).matches(photo), isTrue);
      expect(const MediaFilter(albumId: 7).matches(video), isFalse);
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
