// 004 REQ-010 の①: ファイルの中身に記録された作成日時を読む(`010:T02`)。
//
// fixture は `support/content_fixtures.dart` が組み立てる(第三者の画像を置かない)。

import 'dart:io';
import 'dart:typed_data';

import 'package:batch_rename_master/data/file_source/content_created_at.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/content_fixtures.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-010-content-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  DateTime? read(String name, List<int> bytes) {
    final file = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return readContentCreatedAt(file.path);
  }

  group('JPEG の EXIF', () {
    test('DateTimeOriginal を書かれた時刻そのままで読む(代表例 44)', () {
      final value = read(
        'a.jpg',
        jpeg(tiff(dateTimeOriginal: '2026:07:01 10:00:00')),
      );

      expect(value, DateTime(2026, 7, 1, 10));
      expect(value!.isUtc, isFalse);
    });

    test('OffsetTimeOriginal があっても撮影地の時刻のまま(代表例 45)', () {
      final value = read(
        'a.jpg',
        jpeg(
          tiff(
            dateTimeOriginal: '2026:07:01 10:00:00',
            offsetTimeOriginal: '-10:00',
          ),
        ),
      );

      expect(value, DateTime(2026, 7, 1, 10));
    });

    test('big endian(MM)でも読む', () {
      final value = read(
        'a.jpg',
        jpeg(tiff(dateTimeOriginal: '2021:04:11 15:47:53', endian: Endian.big)),
      );

      expect(value, DateTime(2021, 4, 11, 15, 47, 53));
    });

    test('APP1 が先頭の segment でも読む', () {
      final value = read(
        'a.jpg',
        jpeg(tiff(dateTimeOriginal: '2020:02:29 23:59:59'), exifFirst: true),
      );

      expect(value, DateTime(2020, 2, 29, 23, 59, 59));
    });

    test('更新の DateTime(0x0132)は使わない — DateTimeOriginal が無ければ null', () {
      // DateTimeOriginal の値を空(未設定)にした EXIF。
      final value = read(
        'a.jpg',
        jpeg(
          tiff(
            dateTimeOriginal: '0000:00:00 00:00:00',
            modifyDateTime: '2026:01:01 00:00:00',
          ),
        ),
      );

      expect(value, isNull);
    });

    test('実在しない日付(2月30日)は null', () {
      expect(
        read('a.jpg', jpeg(tiff(dateTimeOriginal: '2026:02:30 10:00:00'))),
        isNull,
      );
    });

    test('時刻が範囲外は null', () {
      expect(
        read('a.jpg', jpeg(tiff(dateTimeOriginal: '2026:07:01 24:00:00'))),
        isNull,
      );
    });

    test('EXIF の無い JPEG は null', () {
      final b = FixtureBytes()
        ..bytes([0xFF, 0xD8, 0xFF, 0xE0])
        ..u16(4)
        ..bytes([0, 0])
        ..bytes([0xFF, 0xDA, 0, 2, 0xFF, 0xD9]);
      expect(read('a.jpg', b.take()), isNull);
    });
  });

  group('HEIF の Exif item', () {
    test('iloc v0・infe v2 の Exif item から DateTimeOriginal を読む', () {
      final value = read(
        'a.heic',
        heif(tiff(dateTimeOriginal: '2021:04:11 15:47:53', endian: Endian.big)),
      );

      expect(value, DateTime(2021, 4, 11, 15, 47, 53));
    });

    test('iloc v1・infe v3 でも読む', () {
      final value = read(
        'a.heic',
        heif(
          tiff(dateTimeOriginal: '2022:01:12 07:30:14'),
          ilocVersion: 1,
          infeVersion: 3,
          exifId: 70000 & 0xFFFF,
        ),
      );

      expect(value, DateTime(2022, 1, 12, 7, 30, 14));
    });
  });

  group('動画の記録日時(mvhd)', () {
    test('UTC の記録日時を端末の時刻帯で返す(代表例 46)', () {
      final utc = DateTime.utc(2026, 7, 1, 1);
      final value = read(
        'a.mp4',
        mp4(creationSeconds1904: utcSeconds1904(utc)),
      );

      expect(value, utc.toLocal());
      expect(value!.isUtc, isFalse);
    });

    test('version 1(64 bit)でも読む', () {
      final utc = DateTime.utc(2030, 12, 31, 23, 59, 59);
      expect(
        read(
          'a.mp4',
          mp4(creationSeconds1904: utcSeconds1904(utc), version: 1),
        ),
        utc.toLocal(),
      );
    });

    test('moov が mdat の後ろにあっても読む', () {
      final utc = DateTime.utc(2025, 3, 4, 5, 6, 7);
      expect(
        read(
          'a.mov',
          mp4(
            creationSeconds1904: utcSeconds1904(utc),
            moovLast: true,
            brand: 'qt  ',
          ),
        ),
        utc.toLocal(),
      );
    });

    test('記録日時が 0(記録していない)なら null', () {
      expect(read('a.mp4', mp4(creationSeconds1904: 0)), isNull);
    });
  });

  group('読めないもの', () {
    test('壊れた・短い・別の形式は null で、例外を投げない(代表例 52)', () {
      final valid = jpeg(tiff(dateTimeOriginal: '2026:07:01 10:00:00'));
      expect(read('cut.jpg', valid.sublist(0, 40)), isNull);
      expect(read('empty.jpg', const []), isNull);
      expect(read('a.txt', 'hello world, not an image'.codeUnits), isNull);
      // box の長さが file より長い。
      expect(
        read('bad.mp4', [
          ...ftyp('isom'),
          0x7F,
          0xFF,
          0xFF,
          0xFF,
          ...'moov'.codeUnits,
        ]),
        isNull,
      );
    });

    test('無い path は null', () {
      expect(readContentCreatedAt(p.join(dir.path, 'missing.jpg')), isNull);
    });
  });
}
