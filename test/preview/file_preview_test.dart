// 008:T07 preview port の契約。仕様IDは持たない — `plan.md` の方針どおり 008 は
// 仕様を変えないため、ここが検査するのは task.md の受け入れ証拠である。
//
// 要点は「preview が無い」と「読めなかった」を**潰していない**こと。潰すと、
// 読めない file が「preview の無い普通の file」に見える。
import 'package:batch_rename_master/core/file_entry.dart';
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:batch_rename_master/data/preview/image_file_preview.dart';
import 'package:batch_rename_master/data/preview/video_file_preview.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {String? handle}) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceHandle: handle ?? '/storage/emulated/0/DCIM/$name',
);

void main() {
  group('previewKindOf: 拡張子から表示専用の種別を決める', () {
    test('画像と動画を見分ける', () {
      expect(previewKindOf('a.jpg'), PreviewKind.image);
      expect(previewKindOf('a.png'), PreviewKind.image);
      expect(previewKindOf('a.webp'), PreviewKind.image);
      expect(previewKindOf('a.mp4'), PreviewKind.video);
      expect(previewKindOf('a.mov'), PreviewKind.video);
    });

    test('大文字small文字を区別しない', () {
      expect(previewKindOf('IMG_0001.JPG'), PreviewKind.image);
      expect(previewKindOf('VID_0001.MP4'), PreviewKind.video);
    });

    test('preview を出さない種別は other', () {
      expect(previewKindOf('a.pdf'), PreviewKind.other);
      expect(previewKindOf('a.txt'), PreviewKind.other);
      expect(previewKindOf('a.zip'), PreviewKind.other);
    });

    test('拡張子が無い・末尾が点だけなら other', () {
      // 迷ったら preview を出さない側へ倒す。
      expect(previewKindOf('README'), PreviewKind.other);
      expect(previewKindOf('a.'), PreviewKind.other);
      expect(previewKindOf(''), PreviewKind.other);
    });

    test('点で始まる隠しfileの拡張子も読む', () {
      expect(previewKindOf('.hidden.jpg'), PreviewKind.image);
      // 拡張子ではなく名前の一部なので画像ではない。
      expect(previewKindOf('.jpg'), PreviewKind.image);
    });
  });

  group('filesystemPathOf: 013 ADR-002 の退避経路を壊さない境界', () {
    test('実 path はそのまま返る', () {
      expect(filesystemPathOf('/storage/emulated/0/DCIM/a.jpg'), isNotNull);
      expect(filesystemPathOf(r'C:\Users\me\a.jpg'), isNotNull);
    });

    test('SAF の document URI は path ではない', () {
      // 退避して SafFileSource へ戻したとき、URI を path として開こうとしない。
      expect(
        filesystemPathOf('content://com.android.externalstorage.documents/1'),
        isNull,
      );
    });

    test('ハンドルを持たない行は path が無い', () {
      expect(filesystemPathOf(null), isNull);
      expect(filesystemPathOf(''), isNull);
    });
  });

  group('KindRoutingFilePreview: 種別で実装を振り分ける', () {
    test('画像は image 実装へ、動画は video 実装へ渡す', () async {
      final image = FakeFilePreview(fallback: const PreviewFailed('image側'));
      final video = FakeFilePreview(fallback: const PreviewFailed('video側'));
      final port = KindRoutingFilePreview(image: image, video: video);

      expect(
        await port.thumbnail(_entry('a.jpg'), maxEdge: 128),
        isA<PreviewFailed>().having((r) => r.message, 'message', 'image側'),
      );
      expect(
        await port.thumbnail(_entry('a.mp4'), maxEdge: 128),
        isA<PreviewFailed>().having((r) => r.message, 'message', 'video側'),
      );
    });

    test('preview を出さない種別はどちらの実装も呼ばない', () async {
      // 件数の多い folder で無駄に file を開かないための性質である。
      final image = FakeFilePreview();
      final video = FakeFilePreview();
      final port = KindRoutingFilePreview(image: image, video: video);

      final result = await port.thumbnail(_entry('a.pdf'), maxEdge: 128);

      expect(result, isA<PreviewUnsupported>());
      expect(image.requested, isEmpty);
      expect(video.requested, isEmpty);
    });
  });

  group('SAF の document URI を持つ行(退避経路)', () {
    const safHandle = 'content://com.android.externalstorage.documents/doc/1';

    test('画像でも読みに行かず、失敗ではなく対象外を返す', () async {
      final result = await const ImageFilePreview().thumbnail(
        _entry('a.jpg', handle: safHandle),
        maxEdge: 128,
      );

      // **PreviewFailed ではない。** 退避したとき、行に「読めなかった」が並んで
      // 壊れて見えるのを避ける(013 ADR-002)。
      expect(result, isA<PreviewUnsupported>());
    });

    test('動画でも channel を叩かない', () async {
      final result = await const MethodChannelVideoPreview().thumbnail(
        _entry('a.mp4', handle: safHandle),
        maxEdge: 128,
      );

      expect(result, isA<PreviewUnsupported>());
    });
  });
}
