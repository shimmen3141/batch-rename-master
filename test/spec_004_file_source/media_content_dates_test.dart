// 004 REQ-022: 選択画面の並びと日付を、`DATE_TAKEN` が無い item について読み込んだ
// 後の作成日時(REQ-010)に揃える(`010:T11`)。
//
// 中身は実ファイルで読む(`T02` の fixture)。MediaStore の照会そのものは端末の
// manual が引き受ける。

import 'dart:io';

import 'package:batch_rename_master/data/file_source/media_content_dates.dart';
import 'package:batch_rename_master/data/file_source/media_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/content_fixtures.dart';

class _FakeContentDates implements MediaContentDatesPort {
  _FakeContentDates(this.dates);

  final Map<int, DateTime> dates;
  final asked = <List<int>>[];
  bool fails = false;

  @override
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items) async {
    asked.add([for (final item in items) item.id]);
    if (fails) throw StateError('読めない');
    // 尋ねられていない id も返す(`withDisplayDates` が余計な値を使わないことを見る)。
    return dates;
  }
}

MediaItem _item(
  int id, {
  DateTime? taken,
  DateTime? added,
  DateTime? modified,
  String? path,
}) => MediaItem(
  id: id,
  path: path ?? '/p$id.jpg',
  kind: MediaKind.photo,
  taken: taken,
  added: added,
  modified: modified,
);

void main() {
  final today = DateTime(2026, 10, 5, 14, 54);
  final shot2008 = DateTime(2008, 5, 30, 15, 56);

  group('withDisplayDates: DATE_TAKEN が無い item だけ中身を読み、並べる', () {
    test('例67: DATE_TAKEN が無く中身に日時があれば、その日時で並ぶ(DATE_ADDED ではない)', () async {
      final camera = _item(1, taken: DateTime(2026, 10, 4, 9));
      final download = _item(2, added: today);
      final port = _FakeContentDates({2: shot2008});

      final items = await withDisplayDates([download, camera], port);

      expect(items.map((e) => e.id), [1, 2]);
      expect(items[1].content, shot2008);
      expect(items[1].date, shot2008);
    });

    test('例68: 中身にも日時が無ければ DATE_ADDED', () async {
      final screenshot = _item(3, added: DateTime(2026, 10, 4, 21));

      final items = await withDisplayDates([screenshot], _FakeContentDates({}));

      expect(items.single.content, isNull);
      expect(items.single.date, DateTime(2026, 10, 4, 21));
    });

    test('DATE_TAKEN がある item の中身は読まない・返ってきても使わない', () async {
      final taken = DateTime(2026, 10, 4, 9);
      final camera = _item(1, taken: taken);
      final download = _item(2, added: today);
      final port = _FakeContentDates({1: shot2008, 2: shot2008});

      final items = await withDisplayDates([camera, download], port);

      expect(port.asked, [
        [2],
      ]);
      final first = items.firstWhere((e) => e.id == 1);
      expect(first.content, isNull);
      expect(first.date, taken);
    });

    test('読めなくても(port が投げても)並べる。中身の日時が無いものとして', () async {
      final port = _FakeContentDates({})..fails = true;

      final items = await withDisplayDates([
        _item(1, added: DateTime(2026, 10, 3)),
        _item(2, added: today),
      ], port);

      expect(items.map((e) => e.id), [2, 1]);
    });
  });

  group('CachedMediaContentDates: 覚えておき、中身が変われば読み直す', () {
    test('同じ path と DATE_MODIFIED なら読み直さない(取れなかったことも覚える)', () async {
      final source = _FakeContentDates({1: shot2008});
      final cache = CachedMediaContentDates(source);
      final modified = DateTime(2026, 10, 5);
      final a = _item(1, modified: modified);
      final b = _item(2, modified: modified);

      expect(await cache.datesOf([a, b]), {1: shot2008});
      expect(await cache.datesOf([a, b]), {1: shot2008});

      expect(source.asked, [
        [1, 2],
      ]);
    });

    test('DATE_MODIFIED が変わる・path が変わる(改名)と読み直す', () async {
      final source = _FakeContentDates({1: shot2008});
      final cache = CachedMediaContentDates(source);
      await cache.datesOf([_item(1, modified: DateTime(2026, 10, 5))]);

      await cache.datesOf([_item(1, modified: DateTime(2026, 10, 6))]);
      await cache.datesOf([
        _item(1, modified: DateTime(2026, 10, 6), path: '/renamed.jpg'),
      ]);

      expect(source.asked, [
        [1],
        [1],
        [1],
      ]);
    });
  });

  group('IsolateMediaContentDates: 実ファイルの中身を読む', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brm-media-content-');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('EXIF の撮影日時を読み、読めないファイルは結果に含めない', () async {
      final photo = p.join(dir.path, 'Canon_40D.jpg');
      File(
        photo,
      ).writeAsBytesSync(jpeg(tiff(dateTimeOriginal: '2008:05:30 15:56:01')));
      final png = p.join(dir.path, 'shot.png');
      File(
        png,
      ).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0]);

      final dates = await const IsolateMediaContentDates().datesOf([
        _item(1, path: photo),
        _item(2, path: png),
        _item(3, path: p.join(dir.path, 'missing.jpg')),
      ]);

      expect(dates, {1: DateTime(2008, 5, 30, 15, 56, 1)});
    });

    test('何も頼まれなければ読まない', () async {
      expect(await const IsolateMediaContentDates().datesOf(const []), isEmpty);
    });
  });
}
