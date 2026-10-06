// 004 VER-003(010:T10): desktop の種類と、システムのファイル選択画面へ渡す絞り込み
// (REQ-011。代表例 13・14・28)。
//
// 観点: desktop の種類は「写真・動画」「文書」「すべて」の3つ。「写真・動画」と「文書」は
// 選択画面を絞り込み、**Windows でも絞り込める形**(拡張子を持つ)で渡す — `file_selector`
// の Windows 実装は拡張子の無い絞り込みを `ArgumentError` で断る
// (`file_selector_windows` 0.9.3+5 の `_typeGroupsFromXTypeGroups`)。
// 実際の Windows の選択画面での絞り込みは、開発者の Windows での確認が引き受ける。
import 'package:batch_rename_master/data/file_source/desktop_file_source.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

/// `file_selector_windows` が絞り込みを受け付けるか(同じ条件を写したもの)。
bool _windowsAccepts(XTypeGroup group) =>
    group.allowsAny || (group.extensions?.isNotEmpty ?? false);

void main() {
  test('例28: desktop の種類は「写真・動画」「文書」「すべて」の3つ', () {
    expect(fileKindsFor(isAndroid: false), [
      FileKind.media,
      FileKind.document,
      FileKind.all,
    ]);
    expect(fileKindsFor(isAndroid: false).map((k) => k.label), [
      '写真・動画',
      '文書',
      'すべて',
    ]);
  });

  test('種類が渡す MIME 型は、どれも拡張子を知っている(拡張子でしか絞れない OS でも効く)', () {
    for (final kind in FileKind.values) {
      for (final mimeType in kind.mimeTypes) {
        expect(
          DesktopFileSource.extensionsByMimeType[mimeType],
          isNotEmpty,
          reason: '${kind.name} の $mimeType',
        );
      }
    }
  });

  group('例13: 「写真・動画」', () {
    final groups = DesktopFileSource.typeGroupsFor(FileKind.media.mimeTypes);

    test('写真と動画の MIME 型で絞る', () {
      expect(groups.single.mimeTypes, ['image/*', 'video/*']);
    });

    test('写真と動画の拡張子を持ち、Windows が受け付ける', () {
      final group = groups.single;
      expect(_windowsAccepts(group), isTrue);
      expect(
        group.extensions,
        containsAll(['jpg', 'jpeg', 'png', 'heic', 'mp4', 'mov']),
      );
    });

    test('文書の拡張子は含まない', () {
      expect(groups.single.extensions, isNot(contains('pdf')));
      expect(groups.single.extensions, isNot(contains('txt')));
    });
  });

  group('例14: 「文書」', () {
    final groups = DesktopFileSource.typeGroupsFor(FileKind.document.mimeTypes);

    test('文書系の MIME 型で絞り、Windows が受け付ける拡張子も持つ', () {
      final group = groups.single;
      expect(group.mimeTypes, contains('application/pdf'));
      expect(_windowsAccepts(group), isTrue);
      expect(
        group.extensions,
        containsAll(['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt']),
      );
      expect(group.extensions, isNot(contains('jpg')));
    });
  });

  test('「すべて」は絞り込まない', () {
    expect(DesktopFileSource.typeGroupsFor(FileKind.all.mimeTypes), isEmpty);
  });

  test('「写真・動画」の説明は、選択画面を持つかどうかで変わる', () {
    expect(
      FileKind.media.descriptionFor(mediaPicker: true),
      '撮影日の新しい順に写真・動画から選ぶ',
    );
    expect(FileKind.media.descriptionFor(mediaPicker: false), '写真・動画のファイルから選ぶ');
  });
}
