// 008:T07 行の種別アイコン。**preview を出せるかとは別の判断**である
// (独立review attempt 1 の P2-4)。
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:batch_rename_master/ui/file_list/file_type_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview を出せない画像・動画も、画像・動画として見える', () {
    // heic は Windows で decode できないので preview の対象から外している。
    // だからといって「何の file か分からない」にはしない。
    for (final name in ['a.heic', 'a.heif', 'a.avif', 'a.tiff', 'a.svg']) {
      expect(previewKindOf(name), PreviewKind.other, reason: name);
      expect(fileTypeIconOf(name), Icons.image_outlined, reason: name);
    }
    for (final name in ['a.wmv', 'a.flv', 'a.ts', 'a.mpeg']) {
      expect(previewKindOf(name), PreviewKind.other, reason: name);
      expect(fileTypeIconOf(name), Icons.movie_outlined, reason: name);
    }
  });

  test('preview を出せる画像・動画も同じアイコンになる', () {
    expect(fileTypeIconOf('a.jpg'), Icons.image_outlined);
    expect(fileTypeIconOf('a.mp4'), Icons.movie_outlined);
  });

  test('種別ごとのアイコンを出し分ける', () {
    expect(fileTypeIconOf('a.pdf'), Icons.description_outlined);
    expect(fileTypeIconOf('a.zip'), Icons.folder_zip_outlined);
    expect(fileTypeIconOf('a.mp3'), Icons.audiotrack_outlined);
  });

  test('判定できないものは何も主張しないアイコンにする', () {
    // 間違ったアイコンより、何も主張しないアイコンの方がまし。
    expect(fileTypeIconOf('README'), Icons.insert_drive_file_outlined);
    expect(fileTypeIconOf('a.'), Icons.insert_drive_file_outlined);
    expect(fileTypeIconOf('a.xyz'), Icons.insert_drive_file_outlined);
  });
}
