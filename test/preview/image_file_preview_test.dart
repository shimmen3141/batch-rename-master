// 008:T07 画像 thumbnail の生成。**実 file を読む** — 一時 folder に本物の PNG を
// 書いてから読ませる。Dart の decoder で完結するので Android にも Windows にも
// 実機を要さず、CI で回る(task.md の宣言表の「画像thumbnail」の行)。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:batch_rename_master/core/file_entry.dart';
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:batch_rename_master/data/preview/image_file_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [width]×[height] の単色 PNG を作る。
Future<Uint8List> _pngBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// PNG バイト列の実寸を読む(縮小されたかの確認用)。
Future<ui.Size> _sizeOf(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final size = ui.Size(
    frame.image.width.toDouble(),
    frame.image.height.toDouble(),
  );
  frame.image.dispose();
  codec.dispose();
  return size;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('t07-preview');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<FileEntry> writeImage(
    String name,
    int width,
    int height, {
    Uint8List? content,
  }) async {
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(content ?? await _pngBytes(width, height));
    return FileEntry(
      name: name,
      modifiedAt: DateTime(2026, 8, 4, 16),
      size: await file.length(),
      sourceHandle: file.path,
    );
  }

  test('画像から thumbnail を作り、長辺を上限まで縮める', () async {
    final entry = await writeImage('photo.png', 400, 300);

    final result = await const ImageFilePreview().thumbnail(
      entry,
      maxEdge: 128,
    );

    expect(result, isA<PreviewReady>());
    final size = await _sizeOf((result as PreviewReady).thumbnail);
    // 長辺が上限に収まり、縦横比が保たれている。
    expect(size.width, 128);
    expect(size.height, 96);
  });

  test('元が上限より小さい画像は拡大しない', () async {
    final entry = await writeImage('small.png', 40, 20);

    final result = await const ImageFilePreview().thumbnail(
      entry,
      maxEdge: 128,
    );

    final size = await _sizeOf((result as PreviewReady).thumbnail);
    expect(size.width, 40);
    expect(size.height, 20);
  });

  test('file が無ければ「読めなかった」を返す', () async {
    final entry = FileEntry(
      name: 'missing.png',
      modifiedAt: DateTime(2026, 8, 4, 16),
      size: 0,
      sourceHandle: '${dir.path}/missing.png',
    );

    final result = await const ImageFilePreview().thumbnail(
      entry,
      maxEdge: 128,
    );

    // **PreviewUnsupported ではない。** 画像のはずなのに読めなかったのだから、
    // 「preview の無い file」と同じ扱いにはしない。
    expect(result, isA<PreviewFailed>());
  });

  test('中身が画像でなければ「読めなかった」を返す', () async {
    // 拡張子は画像だが中身が壊れている。例外を投げずに結果値で返す。
    final entry = await writeImage(
      'broken.png',
      0,
      0,
      content: Uint8List.fromList([1, 2, 3, 4, 5]),
    );

    final result = await const ImageFilePreview().thumbnail(
      entry,
      maxEdge: 128,
    );

    expect(result, isA<PreviewFailed>());
  });

  test('画像でない拡張子は読みに行かない', () async {
    final entry = await writeImage('doc.pdf', 40, 20);

    final result = await const ImageFilePreview().thumbnail(
      entry,
      maxEdge: 128,
    );

    expect(result, isA<PreviewUnsupported>());
  });
}
