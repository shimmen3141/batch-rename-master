// 004 REQ-022 / REQ-023: 写真・動画の選択画面(`010:T07`)。
//
// 一覧は fake の port から渡す。MediaStore の照会そのものは `010:T07` の端末確認が
// 引き受ける(task.md の宣言)。日の見出しを押すまとめ選択は `010:T08`。

import 'dart:async';
import 'dart:typed_data';

import 'package:batch_rename_master/data/file_source/media_content_dates.dart';
import 'package:batch_rename_master/data/file_source/media_library.dart';
import 'package:batch_rename_master/ui/common/drag_selection_controller.dart';
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

  /// 新しい順で書く(fake は逆順で返す)。
  final List<MediaItem> items;
  final List<MediaAlbum> albumList;

  /// 次の [list] を失敗させる回数。
  int failLists = 0;
  bool failAlbums = false;
  int listCalls = 0;

  /// 並べずに返す(並べるのは選択画面の側。010:T11)。
  @override
  Future<MediaListResult> list() async {
    listCalls++;
    if (failLists > 0) {
      failLists--;
      return const MediaListFailed('写真・動画を取得できませんでした: テスト');
    }
    return MediaListed(items.reversed.toList());
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
  MediaContentDatesPort contentDates = const _NoContentDates(),
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
                    contentDates: contentDates,
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
      expect(library.listCalls, 1);
      expect(
        tester
            .widget<SegmentedButton<MediaKindFilter>>(
              find.byKey(mediaPickerKindKey),
            )
            .selected,
        {MediaKindFilter.all},
      );

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
      final library = _FakeLibrary([_a])..failLists = 1;
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

    testWidgets('絞り込みを変えても一覧を取り直さない(全件を受け取り app の側で絞る)', (tester) async {
      final library = _FakeLibrary([_a, _b, _c]);
      await _open(tester, library);

      await _kind(tester, MediaKindFilter.videos);
      await _album(tester, mediaPickerAlbumKey(_screenshots));

      expect(library.listCalls, 1);
    });
  });

  group('REQ-022: 日付を作成日時に揃える(010:T11)', () {
    testWidgets('例67: DATE_TAKEN が無いダウンロードは、中身の撮影日の見出しに並ぶ', (tester) async {
      final download = MediaItem(
        id: 99,
        path: '/s/Download/Canon_40D.jpg',
        kind: MediaKind.photo,
        added: DateTime(2026, 10, 5, 14, 54),
        albumId: _download,
      );
      await _open(
        tester,
        _FakeLibrary([_a, download]),
        contentDates: _FixedContentDates({99: DateTime(2008, 5, 30, 15, 56)}),
      );

      final day2008 = find.byKey(
        mediaPickerDayHeaderKey(DateTime(2008, 5, 30)),
      );
      expect(day2008, findsOneWidget);
      expect(find.text('2008年5月30日(金)'), findsOneWidget);
      expect(_itemsUnder(tester, [_a, download], day2008, null), [download]);
      // 今日(10/5)の見出しには a だけ。
      final today = find.byKey(mediaPickerDayHeaderKey(DateTime(2026, 10, 5)));
      expect(_itemsUnder(tester, [_a, download], today, day2008), [_a]);
    });

    testWidgets('並べ終わるまでは格子を出さない(item が後から別の見出しへ跳ばない)', (tester) async {
      final gate = Completer<Map<int, DateTime>>();
      final download = MediaItem(
        id: 99,
        path: '/s/Download/x.jpg',
        kind: MediaKind.photo,
        added: DateTime(2026, 10, 5, 14, 54),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: MediaPickerView(
            library: _FakeLibrary([download]),
            contentDates: _GatedContentDates(gate),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('media-picker-loading')), findsOneWidget);
      expect(_item(download), findsNothing);

      gate.complete({99: DateTime(2008, 5, 30)});
      await tester.pumpAndSettle();
      expect(_item(download), findsOneWidget);
    });

    testWidgets('例69: ⓘ で説明が開き、閉じても選択と絞り込みは変わらない', (tester) async {
      await _open(tester, _FakeLibrary([_a, _b, _c]));
      await tester.tap(_item(_a));
      await tester.pump();
      await _kind(tester, MediaKindFilter.photos);

      await tester.tap(find.byKey(mediaPickerDateHelpKey));
      await tester.pumpAndSettle();

      expect(find.byKey(mediaDateHelpDialogKey), findsOneWidget);
      expect(find.text('並び順と日付について'), findsOneWidget);
      expect(find.text(MediaDateHelpDialog.intro), findsOneWidget);
      expect(find.text(MediaDateHelpDialog.contentCase), findsOneWidget);
      expect(find.text('・ダウンロードしたファイルなど'), findsOneWidget);
      expect(find.text(MediaDateHelpDialog.savedCase), findsOneWidget);
      expect(find.text('・多くのスクリーンショットなど'), findsOneWidget);

      await tester.tap(find.byKey(mediaDateHelpCloseKey));
      await tester.pumpAndSettle();

      expect(find.byKey(mediaDateHelpDialogKey), findsNothing);
      expect(_title(tester), '1件選択中');
      expect(_item(_c), findsNothing, reason: '写真に絞ったまま');
    });

    test('説明の文言は開発者が決めたもの(004「010:T11 由来の更新」)', () {
      expect(MediaDateHelpDialog.title, '並び順と日付について');
      expect(MediaDateHelpDialog.intro, '写真・動画は撮影日時の新しい順に、日付ごとにまとめて並びます。');
      expect(
        MediaDateHelpDialog.contentCase,
        '端末が撮影日時を把握できないものは、ファイル内部に記録された作成日時で並びます。',
      );
      expect(MediaDateHelpDialog.contentExamples, ['ダウンロードしたファイルなど']);
      expect(
        MediaDateHelpDialog.savedCase,
        '撮影日時・ファイル内部の作成日時のどちらも無いものは、この端末に保存された日時で並びます。',
      );
      expect(MediaDateHelpDialog.savedExamples, ['多くのスクリーンショットなど']);
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

    testWidgets('すべて選択は今の絞り込みで並ぶ item を足す(画面の外のものも)', (tester) async {
      final photos = [
        for (var i = 0; i < 60; i++)
          _photo(
            '/s/DCIM/Camera/p$i.jpg',
            DateTime(2026, 10, 5).subtract(Duration(days: i)),
          ),
      ];
      final video = _video('/s/Download/v.mp4', DateTime(2026, 10, 6));
      final harness = await _open(tester, _FakeLibrary([video, ...photos]));
      await tester.tap(_item(video));
      await tester.pump();
      await _kind(tester, MediaKindFilter.photos);
      expect(_item(photos.last), findsNothing, reason: '画面の外');

      await _menu(tester, mediaPickerSelectAllKey);

      // 写真60件 + 先に選んでいた動画(足すので消えない)。
      expect(_title(tester), '61件選択中');
      await tester.tap(find.byKey(mediaPickerConfirmKey));
      await tester.pumpAndSettle();
      expect(
        harness.result,
        unorderedEquals([...photos.map((e) => e.path), video.path]),
      );
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

  group('絞り込みを繰り返しても溜め込まない(独立review attempt 1 の S-1・S-2)', () {
    test('サムネイルは最近使った上限件数までだけ覚え、捨てたものは頼み直す', () async {
      final library = _CountingLibrary();
      final cache = MediaThumbnailCache(library, maxEntries: 2);
      final items = [
        for (var i = 0; i < 3; i++)
          MediaItem(id: i, path: '/p$i.jpg', kind: MediaKind.photo),
      ];

      await cache.of(items[0]);
      await cache.of(items[1]);
      await cache.of(items[0]); // 0 を使い直す(1 が最も古くなる)
      await cache.of(items[2]); // 1 が捨てられる

      expect(cache.length, 2);
      expect(library.asked, [0, 1, 2]);
      await cache.of(items[0]);
      expect(library.asked, [0, 1, 2], reason: '0 は覚えている');
      await cache.of(items[1]);
      expect(library.asked, [0, 1, 2, 1], reason: '1 は捨てたので頼み直す');
    });

    testWidgets('絞り込みを変えると、前の item の位置の key を捨てる', (tester) async {
      final controller = DragSelectionController<String>(
        scrollController: ScrollController(),
        viewportKey: GlobalKey(),
        select: (_) {},
        deselect: (_) {},
        isMounted: () => true,
      );
      controller.rowGeometryKey('a');
      controller.rowGeometryKey('b');
      expect(controller.rowCount, 2);

      controller.forgetRows();

      expect(controller.rowCount, 0);
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

class _CountingLibrary extends _FakeLibrary {
  _CountingLibrary() : super(const []);

  final asked = <int>[];

  @override
  Future<Uint8List?> thumbnail(MediaItem item, {required int maxEdge}) async {
    asked.add(item.id);
    return null;
  }
}

class _NoContentDates implements MediaContentDatesPort {
  const _NoContentDates();

  @override
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items) async => const {};
}

class _FixedContentDates implements MediaContentDatesPort {
  _FixedContentDates(this.dates);

  final Map<int, DateTime> dates;

  @override
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items) async => dates;
}

class _GatedContentDates implements MediaContentDatesPort {
  _GatedContentDates(this.gate);

  final Completer<Map<int, DateTime>> gate;

  @override
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items) => gate.future;
}
