// 008:T07 行と警告の情報階層。002 の行widgetを対象にするが**002 specは変えない** —
// 検査するのは「どの行の作成日時が不明かが狭幅でも読み取れる」ことで、REQ-013 が
// 求める識別そのものは現行でも警告アイコンで成立している。
//
// (h): `004:T10` のAndroid実機確認で「狭幅で `作成日時: 不明` が読めない」を観測した。
// 原因は場所・作成日時・更新日時を1つの `Text` へ入れて `maxLines: 1` で省略している
// ことで、**場所が先頭にあるため後ろの日時から消える**。
import 'package:batch_rename_master/core/file_entry.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 作成日時が取れなかった行(REQ-013 の「不明」)。
///
/// 場所を長めに持たせるのは実機の再現条件に合わせるためである。実際の
/// `sourceLocation` は `Download` や `DCIM/Camera` のような folder 名で、
/// 狭幅ではこれだけで行の幅を使い切る。
FileEntry _unknownCreatedAt() => FileEntry(
  name: 'IMG_20260804_160000.jpg',
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceLocation: 'DCIM/Camera',
  sourceHandle: '/storage/emulated/0/DCIM/Camera/IMG_20260804_160000.jpg',
);

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = FileListController(files: [_unknownCreatedAt()]);
  controller.setSortMode(FileSortMode.createdAt);
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: controller)),
    ),
  );
}

/// [finder] が指すTextの段落が、省略されずに収まっているか。
///
/// `didExceedMaxLines` は `maxLines` を超えて**省略が起きた**ことを示す。文字列が
/// 見つかること(`findsOneWidget`)だけでは足りない — widget が持つ文字列は省略前の
/// 全文であり、**画面に出ていなくても finder は当たる**。
bool _isTruncated(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).didExceedMaxLines;

void main() {
  group('008:T07 (h) 狭幅の行サブ情報', () {
    testWidgets('狭幅でも `作成日時: 不明` が省略されない', (tester) async {
      // 360dp は実機確認で見切れを観測した幅の側にある一般的な携帯の論理幅。
      await _pumpAt(tester, const Size(360, 640));

      final createdAt = find.byKey(rowCreatedAtKey);
      expect(createdAt, findsOneWidget);
      expect(
        _isTruncated(tester, createdAt),
        isFalse,
        reason: '狭幅で `作成日時: 不明` が省略されている((h)の見切れ)',
      );
    });

    testWidgets('広い幅でも `作成日時: 不明` が省略されない', (tester) async {
      await _pumpAt(tester, const Size(1200, 800));

      final createdAt = find.byKey(rowCreatedAtKey);
      expect(createdAt, findsOneWidget);
      expect(_isTruncated(tester, createdAt), isFalse);
    });

    testWidgets('さらに狭くしても `作成日時: 不明` は省略されない', (tester) async {
      // 幅を変えるたびに調整し直さずに済むことを、実機より狭い幅で確かめる。
      // 省略の優先順位を調整して解いた場合、ここで再発する。
      await _pumpAt(tester, const Size(320, 640));

      final createdAt = find.byKey(rowCreatedAtKey);
      expect(createdAt, findsOneWidget);
      expect(_isTruncated(tester, createdAt), isFalse);
    });

    testWidgets('場所は日時と別の行に出る', (tester) async {
      await _pumpAt(tester, const Size(360, 640));

      // 同じ `Text` に同居していれば、場所だけの完全一致では見つからない。
      // 見つかること自体が「別の行にある」ことを示す。
      expect(find.text('DCIM/Camera'), findsOneWidget);
    });

    testWidgets('狭幅で削られるのは更新日時の側である', (tester) async {
      await _pumpAt(tester, const Size(360, 640));

      final modifiedAt = find.byKey(rowModifiedAtKey);
      expect(modifiedAt, findsOneWidget);
      // 作成日時が残るために更新日時が犠牲になっている、が意図した優先順位。
      // 両方収まる幅では省略されないので、狭幅でだけ成立する主張である。
      expect(
        _isTruncated(tester, modifiedAt),
        isTrue,
        reason: '狭幅では更新日時が先に削られる想定',
      );
    });
  });
}
