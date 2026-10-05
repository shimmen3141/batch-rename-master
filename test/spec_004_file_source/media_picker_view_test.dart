// 004 REQ-022 / REQ-023: 写真・動画の選択画面(`010:T07`)。
//
// 一覧は fake の port から渡す。MediaStore の照会そのものは `010:T07` の端末確認が
// 引き受ける(task.md の宣言)。日の見出しを押すまとめ選択は `010:T08`。

import 'dart:typed_data';

import 'package:batch_rename_master/data/file_source/media_library.dart';
import 'package:batch_rename_master/ui/file_source/media_picker_view.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _camera = 1;
const _screenshots = 2;
const _download = 3;

MediaItem _photo(String path, DateTime taken, {int album = _camera}) =>
    MediaItem(
      id: path.hashCode,
      path: path,
      kind: MediaKind.photo,
      taken: taken,
      albumId: album,
    );

MediaItem _video(
  String path,
  DateTime taken, {
  int album = _download,
  Duration duration = const Duration(seconds: 83),
}) => MediaItem(
  id: path.hashCode,
  path: path,
  kind: MediaKind.video,
  taken: taken,
  duration: duration,
  albumId: album,
);

/// 代表例 55 の a・b・c。
final _a = _photo('/s/DCIM/Camera/a.jpg', DateTime(2026, 10, 5, 9));
final _b = _photo(
  '/s/Pictures/Screenshots/b.png',
  DateTime(2026, 10, 4, 9),
  album: _screenshots,
);
final _c = _video('/s/Download/c.mp4', DateTime(2026, 10, 3, 9));

class _FakeLibrary implements MediaLibraryPort {
  _FakeLibrary(this.items, {List<MediaAlbum>? albums})
    : albumList =
          albums ??
          const [
            MediaAlbum(
              id: _camera,
              name: 'Camera',
              count: 1,
              folder: '/s/DCIM/Camera',
            ),
            MediaAlbum(
              id: _screenshots,
              name: 'Screenshots',
              count: 1,
              folder: '/s/Pictures/Screenshots',
            ),
            MediaAlbum(
              id: _download,
              name: 'Download',
              count: 1,
              folder: '/s/Download',
            ),
          ];

  /// 新しい順。
  final List<MediaItem> items;
  final List<MediaAlbum> albumList;

  /// 次の [page] を失敗させる回数。
  int failPages = 0;
  bool failAlbums = false;
  final calls = <(MediaFilter, int, int)>[];

  @override
  Future<MediaPageResult> page(
    MediaFilter filter, {
    required int offset,
    required int limit,
  }) async {
    calls.add((filter, offset, limit));
    if (failPages > 0) {
      failPages--;
      return const MediaPageFailed('写真・動画を取得できませんでした: テスト');
    }
    final matching = [
      for (final item in items)
        if ((filter.albumId == null || item.albumId == filter.albumId) &&
            switch (filter.kind) {
              MediaKindFilter.all => true,
              MediaKindFilter.photos => item.kind == MediaKind.photo,
              MediaKindFilter.videos => item.kind == MediaKind.video,
            })
          item,
    ];
    final slice = matching.skip(offset).take(limit).toList();
    return MediaPage(slice, hasMore: slice.length >= limit);
  }

  @override
  Future<MediaAlbumsResult> albums() async => failAlbums
      ? const MediaAlbumsFailed('アルバムを取得できませんでした: テスト')
      : MediaAlbumsListed(albumList);

  @override
  Future<Uint8List?> thumbnail(MediaItem item, {required int maxEdge}) async =>
      null;
}

/// 選択画面を push し、閉じたときの結果を返す。
class _Harness {
  List<String>? result;
  bool closed = false;
}

Future<_Harness> _open(
  WidgetTester tester,
  MediaLibraryPort library, {
  int pageSize = 120,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              harness.result = await Navigator.of(context).push<List<String>>(
                MaterialPageRoute(
                  builder: (_) => MediaPickerView(
                    library: library,
                    pageSize: pageSize,
                    now: () => DateTime(2026, 10, 5, 12),
                  ),
                ),
              );
              harness.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

Finder _item(MediaItem item) => find.byKey(mediaPickerItemKey(item.path));

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(mediaPickerTitleKey)).data!;

bool _confirmEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(mediaPickerConfirmKey)).onPressed !=
    null;

Future<void> _kind(WidgetTester tester, MediaKindFilter kind) async {
  await tester.tap(find.byKey(mediaPickerKindSegmentKey(kind)));
  await tester.pumpAndSettle();
}

Future<void> _album(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(mediaPickerAlbumButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, Key item) async {
  await tester.tap(find.byKey(mediaPickerMenuKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(item));
  await tester.pumpAndSettle();
}

/// [header] の見出しより下、次の見出しより上にある item を返す。
List<MediaItem> _itemsUnder(
  WidgetTester tester,
  List<MediaItem> all,
  Finder header,
  Finder? nextHeader,
) {
  final top = tester.getTopLeft(header).dy;
  final bottom = nextHeader == null
      ? double.infinity
      : tester.getTopLeft(nextHeader).dy;
  return [
    for (final item in all)
      if (_item(item).evaluate().isNotEmpty &&
          tester.getCenter(_item(item)).dy > top &&
          tester.getCenter(_item(item)).dy < bottom)
        item,
  ];
}

void main() {
  group('REQ-022: 何が並ぶか・並び順と日付', () {
    testWidgets('例54・55: 全件で開き、撮影日の新しい順に日ごとの見出しの下へ並ぶ。動画は再生時間を示す', (
      tester,
    ) async {
      final library = _FakeLibrary([_a, _b, _c]);
      await _open(tester, library);

      // **最初は全件**(種類「すべて」・すべてのアルバム)。
      final (filter, offset, _) = library.calls.first;
      expect(filter.kind, MediaKindFilter.all);
      expect(filter.albumId, isNull);
      expect(offset, 0);

      final day5 = find.byKey(mediaPickerDayHeaderKey(DateTime(2026, 10, 5)));
      final day4 = find.byKey(mediaPickerDayHeaderKey(DateTime(2026, 10, 4)));
      final day3 = find.byKey(mediaPickerDayHeaderKey(DateTime(2026, 10, 3)));
      expect(find.text('10月5日(月)'), findsOneWidget);
      expect(_itemsUnder(tester, [_a, _b, _c], day5, day4), [_a]);
      expect(_itemsUnder(tester, [_a, _b, _c], day4, day3), [_b]);
      expect(_itemsUnder(tester, [_a, _b, _c], day3, null), [_c]);

      expect(find.byKey(mediaPickerDurationKey(_c.path)), findsOneWidget);
      expect(find.text('1:23'), findsOneWidget);
      expect(find.byKey(mediaPickerDurationKey(_a.path)), findsNothing);
    });

    testWidgets('例55: 種類を動画に絞ると c だけ、アルバムを Screenshots に絞ると b だけ', (
      tester,
    ) async {
      await _open(tester, _FakeLibrary([_a, _b, _c]));

      await _kind(tester, MediaKindFilter.videos);
      expect(_item(_c), findsOneWidget);
      expect(_item(_a), findsNothing);
      expect(_item(_b), findsNothing);

      await _kind(tester, MediaKindFilter.all);
      await _album(tester, mediaPickerAlbumKey(_screenshots));
      expect(_item(_b), findsOneWidget);
      expect(_item(_a), findsNothing);
      expect(_item(_c), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(mediaPickerAlbumButtonKey),
          matching: find.text('Screenshots'),
        ),
        findsOneWidget,
      );

      await _album(tester, mediaPickerAllAlbumsKey);
      expect(_item(_a), findsOneWidget);
      expect(_item(_c), findsOneWidget);
    });

    testWidgets('並ぶものが無いときは、無いことを示す', (tester) async {
      await _open(tester, _FakeLibrary(const []));

      expect(find.byKey(mediaPickerEmptyKey), findsOneWidget);
      expect(find.text('写真・動画がありません'), findsOneWidget);
    });

    testWidgets('絞り込んで無ければ、その条件では無いことを示す', (tester) async {
      await _open(tester, _FakeLibrary([_a]));

      await _kind(tester, MediaKindFilter.videos);

      expect(find.text('この条件の写真・動画はありません'), findsOneWidget);
    });

    testWidgets('取れなかったときは「無い」とは別に理由を示し、読み直せる', (tester) async {
      final library = _FakeLibrary([_a])..failPages = 1;
      await _open(tester, library);

      expect(find.byKey(mediaPickerFailedKey), findsOneWidget);
      expect(find.textContaining('テスト'), findsOneWidget);
      expect(find.byKey(mediaPickerEmptyKey), findsNothing);

      await tester.tap(find.byKey(mediaPickerRetryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(mediaPickerFailedKey), findsNothing);
      expect(_item(_a), findsOneWidget);
    });

    testWidgets('アルバムを取れなかったときは、アルバムの一覧に理由を示す', (tester) async {
      await _open(tester, _FakeLibrary([_a])..failAlbums = true);

      await tester.tap(find.byKey(mediaPickerAlbumButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('media-picker-albums-failed')),
        findsOneWidget,
      );
      // 「すべてのアルバム」へは戻れる。
      expect(find.byKey(mediaPickerAllAlbumsKey), findsOneWidget);
    });

    testWidgets('少しずつ読む: 続きがあれば次の範囲を頼む', (tester) async {
      final items = [
        for (var i = 0; i < 5; i++)
          _photo('/s/DCIM/Camera/p$i.jpg', DateTime(2026, 10, 5, 10 - i)),
      ];
      final library = _FakeLibrary(items);
      await _open(tester, library, pageSize: 2);

      expect(
        [for (final (_, offset, limit) in library.calls) (offset, limit)],
        [(0, 2), (2, 2), (4, 2)],
      );
      for (final item in items) {
        expect(_item(item), findsOneWidget);
      }
    });
  });

  group('REQ-023: 選び方', () {
    testWidgets('例60: 何も選んでいなければ確定できず、まとめて解除は提示しない', (tester) async {
      await _open(tester, _FakeLibrary([_a, _b, _c]));

      expect(_title(tester), '写真・動画');
      expect(_confirmEnabled(tester), isFalse);
      expect(find.byKey(mediaPickerClearSelectionKey), findsNothing);
      await tester.tap(find.byKey(mediaPickerMenuKey));
      await tester.pumpAndSettle();
      expect(find.byKey(mediaPickerMenuClearSelectionKey), findsNothing);
    });

    testWidgets('押すと選択が切り替わり、件数を示す', (tester) async {
      await _open(tester, _FakeLibrary([_a, _b, _c]));

      await tester.tap(_item(_a));
      await tester.pump();
      expect(_title(tester), '1件選択中');
      expect(_confirmEnabled(tester), isTrue);

      await tester.tap(_item(_a));
      await tester.pump();
      expect(_title(tester), '写真・動画');
      expect(_confirmEnabled(tester), isFalse);
    });

    testWidgets('例56・57: 絞り込みを変えても選択は保たれ、見えていない選択も確定に含まれる', (tester) async {
      final harness = await _open(tester, _FakeLibrary([_a, _b, _c]));

      await tester.tap(_item(_a));
      await tester.pump();
      await _album(tester, mediaPickerAlbumKey(_screenshots));
      await tester.tap(_item(_b));
      await tester.pump();
      // 例57: 種類を動画に絞る(a,b は見えなくなる)。
      await _album(tester, mediaPickerAllAlbumsKey);
      await _kind(tester, MediaKindFilter.videos);
      expect(_item(_a), findsNothing);
      expect(_item(_b), findsNothing);
      expect(_title(tester), '2件選択中');

      await tester.tap(find.byKey(mediaPickerConfirmKey));
      await tester.pumpAndSettle();

      expect(harness.result, unorderedEquals([_a.path, _b.path]));
    });

    testWidgets('すべて選択は今の絞り込みで並ぶ item を足す(まだ読んでいない分も)', (tester) async {
      final photos = [
        for (var i = 0; i < 5; i++)
          _photo('/s/DCIM/Camera/p$i.jpg', DateTime(2026, 10, 5, 10 - i)),
      ];
      final video = _video('/s/Download/v.mp4', DateTime(2026, 10, 1));
      // 1ページ目の後に止めて、読んでいない分があるようにする。
      final library = _FakeLibrary([...photos, video]);
      final harness = await _open(tester, library, pageSize: 2);
      await tester.tap(_item(video));
      await tester.pump();
      await _kind(tester, MediaKindFilter.photos);

      await _menu(tester, mediaPickerSelectAllKey);

      // 写真5件 + 先に選んでいた動画(足すので消えない)。
      expect(_title(tester), '6件選択中');
      await tester.tap(find.byKey(mediaPickerConfirmKey));
      await tester.pumpAndSettle();
      expect(
        harness.result,
        unorderedEquals([...photos.map((e) => e.path), video.path]),
      );
    });

    testWidgets('すべて選択は、読み切れなければ一部だけを選ばない', (tester) async {
      final photos = [
        for (var i = 0; i < 300; i++)
          _photo(
            '/s/DCIM/Camera/p$i.jpg',
            DateTime(2026, 9, 1).subtract(Duration(hours: i)),
          ),
      ];
      final library = _FakeLibrary(photos);
      await _open(tester, library, pageSize: 100);
      final asked = library.calls.length;
      library.failPages = 1;

      await _menu(tester, mediaPickerSelectAllKey);

      expect(library.calls.length, greaterThan(asked));
      expect(_title(tester), '写真・動画');
    });

    testWidgets('すべて解除は見えていない選択も外す(× とケバブの両方)', (tester) async {
      await _open(tester, _FakeLibrary([_a, _b, _c]));

      await tester.tap(_item(_a));
      await tester.pump();
      await _kind(tester, MediaKindFilter.videos);
      await tester.tap(_item(_c));
      await tester.pump();
      expect(_title(tester), '2件選択中');

      await tester.tap(find.byKey(mediaPickerClearSelectionKey));
      await tester.pump();
      expect(_title(tester), '写真・動画');
      expect(_confirmEnabled(tester), isFalse);

      await tester.tap(_item(_c));
      await tester.pump();
      await _kind(tester, MediaKindFilter.all);
      await tester.tap(_item(_a));
      await tester.pump();
      await _menu(tester, mediaPickerMenuClearSelectionKey);
      expect(_title(tester), '写真・動画');
    });

    testWidgets('長押しで drag すると表示順の範囲を選び、戻ると drag が足した分だけ外す', (tester) async {
      final items = [
        for (var i = 0; i < 12; i++)
          _photo('/s/DCIM/Camera/p$i.jpg', DateTime(2026, 10, 5, 23 - i)),
      ];
      final harness = await _open(tester, _FakeLibrary(items));
      // drag の前から選択済み(drag は外さない)。
      await tester.tap(_item(items[3]));
      await tester.pump();

      // 1行目の p1 から、次の行の p9 まで(格子なので、指が通らない item も範囲に入る)。
      final gesture = await tester.startGesture(
        tester.getCenter(_item(items[1])),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(_item(items[9])));
      await tester.pump();
      expect(_title(tester), '9件選択中');

      // p2 まで戻る: p3〜p9 は範囲から外れる。drag が足した p4〜p9 は外れ、
      // **p3 は drag の前から選ばれていたので残る**。
      await gesture.moveTo(tester.getCenter(_item(items[2])));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(_title(tester), '3件選択中');

      await tester.tap(find.byKey(mediaPickerConfirmKey));
      await tester.pumpAndSettle();
      expect(
        harness.result,
        unorderedEquals([
          for (final i in [1, 2, 3]) items[i].path,
        ]),
      );
    });

    testWidgets('閉じると決定していない(null)。選択は捨てる(REQ-008)', (tester) async {
      final harness = await _open(tester, _FakeLibrary([_a]));

      await tester.tap(_item(_a));
      await tester.pump();
      await tester.tap(find.byKey(mediaPickerBackKey));
      await tester.pumpAndSettle();

      expect(harness.closed, isTrue);
      expect(harness.result, isNull);
    });
  });

  group('見出しと再生時間の書き方', () {
    test('今年なら年を省き、日時が無ければ「日付不明」', () {
      final now = DateTime(2026, 10, 5);
      expect(mediaDayLabel(DateTime(2026, 10, 4), now: now), '10月4日(日)');
      expect(mediaDayLabel(DateTime(2025, 12, 31), now: now), '2025年12月31日(水)');
      expect(mediaDayLabel(null, now: now), '日付不明');
    });

    test('再生時間は m:ss、1時間以上は h:mm:ss', () {
      expect(mediaDurationLabel(const Duration(seconds: 5)), '0:05');
      expect(
        mediaDurationLabel(const Duration(minutes: 1, seconds: 23)),
        '1:23',
      );
      expect(
        mediaDurationLabel(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });
}
