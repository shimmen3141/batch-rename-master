// 008:T07 行と警告の情報階層。002 の行widgetを対象にするが**002 specは変えない** —
// 検査するのは「どの行の作成日時が不明かが狭幅でも読み取れる」ことで、REQ-013 が
// 求める識別そのものは現行でも警告アイコンで成立している。
//
// (h): `004:T10` のAndroid実機確認で「狭幅で `作成日時: 不明` が読めない」を観測した。
// 原因は場所・作成日時・更新日時を1つの `Text` へ入れて `maxLines: 1` で省略している
// ことで、**場所が先頭にあるため後ろの日時から消える**。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
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

/// 作成日時が**取れている**行。
///
/// 独立review attempt 1 の P1-1。日時が入ると文字列が「作成日時: 不明」より
/// ずっと長くなるが、当初のtestは`null`(=最短)しか通しておらず、**この経路を
/// 一度も踏んでいなかった。**
FileEntry _knownCreatedAt() => FileEntry(
  name: 'IMG_20261231_235959.jpg',
  createdAt: DateTime(2026, 12, 31, 23, 59),
  modifiedAt: DateTime(2026, 12, 31, 23, 59),
  size: 0,
  sourceLocation: 'DCIM/Camera',
  sourceHandle: '/storage/emulated/0/DCIM/Camera/IMG_20261231_235959.jpg',
);

/// pump 中に起きた layout error(overflow を含む)。
Future<List<String>> _errorsWhilePumping(
  WidgetTester tester,
  Size size,
  List<FileEntry> files,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception.toString());
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(controller: FileListController(files: files)),
      ),
    ),
  );
  FlutterError.onError = previous;
  return errors;
}

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

    testWidgets('作成日時が取れている行が、狭幅ではみ出さない', (tester) async {
      // **省略ではなく overflow になっていた。** 「縮まない側へ置く」だけでは
      // 下限が無く、幅が足りなくなった瞬間に文字が枠外へ描かれる。
      for (final width in [320.0, 360.0]) {
        final errors = await _errorsWhilePumping(tester, Size(width, 640), [
          _knownCreatedAt(),
        ]);
        expect(errors, isEmpty, reason: '幅 $width ではみ出している');
      }
    });

    testWidgets('狭いときは更新日時が次の行へ落ちる(作成日時から幅を奪わない)', (tester) async {
      // **font に依存しない形で主張する。** 「実日時が360dpに収まるか」は font
      // 次第だが、「収まらないとき更新日時が下へ行く」は構造で決まる。
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: FileListView(
              controller: FileListController(files: [_knownCreatedAt()]),
            ),
          ),
        ),
      );

      final createdAt = tester.getRect(find.byKey(rowCreatedAtKey));
      final modifiedAt = tester.getRect(find.byKey(rowModifiedAtKey));
      expect(
        modifiedAt.top,
        greaterThan(createdAt.top),
        reason: '更新日時が同じ行に残って作成日時の幅を削っている',
      );
    });

    testWidgets('作成日時が不明な行も、狭幅ではみ出さない', (tester) async {
      for (final width in [320.0, 360.0]) {
        final errors = await _errorsWhilePumping(tester, Size(width, 640), [
          _unknownCreatedAt(),
        ]);
        expect(errors, isEmpty, reason: '幅 $width ではみ出している');
      }
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

  group('008:T07 (i) 件数の多い警告帯', () {
    /// 重複警告だけを [count] 件持つ帯を、指定した画面サイズで開いた状態にする。
    Future<Rect> pumpExpandedPanel(
      WidgetTester tester,
      Size size, {
      int count = 30,
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final warnings = <Warning>[
        for (var i = 0; i < count; i++)
          DuplicateWarning(
            file: FileEntry(
              name: 'IMG_2026080$i.jpg',
              modifiedAt: DateTime(2026, 8, 4),
              size: 0,
              sourceLocation: 'DCIM/Camera',
            ),
            resultName: 'photo_001.jpg',
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: Column(
              children: [
                // 同じ test 内で2回 pump するとき、State(開閉)を引き継がせない。
                RenameWarningPanel(key: ValueKey(size), warnings: warnings),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(renameWarningToggleKey));
      await tester.pump();
      return tester.getRect(find.byKey(renameWarningsKey));
    }

    test('内訳の高さは画面に応じて決まる(固定値ではない)', () {
      // 固定 132px をやめたことそのものを固定する。狭幅では1件が4行へ折り返す
      // ため、132px には2件しか入らなかった。
      final short = RenameWarningPanel.detailMaxHeightFor(640);
      final tall = RenameWarningPanel.detailMaxHeightFor(1000);

      expect(short, greaterThan(RenameWarningPanel.detailMaxHeight));
      expect(tall, greaterThan(short));
    });

    test('画面が小さくても従来の高さを下回らない', () {
      // 小さな画面で今より狭くなると、直すつもりが悪化する。
      expect(
        RenameWarningPanel.detailMaxHeightFor(320),
        RenameWarningPanel.detailMaxHeight,
      );
    });

    testWidgets('帯は画面から決めた高さを実際に使う', (tester) async {
      await pumpExpandedPanel(tester, const Size(360, 640));

      // 固定 132px ではなく、画面から決めた値がそのまま効いている。
      // **恣意的な「何件見えるか」ではなく、配線そのものを固定する。**
      //
      // 期待値は **widget が実際に見ている** 画面の高さから作る。test harness の
      // surface と `MediaQuery` はずれることがあるが、ここで確かめたいのは
      // 「画面の高さから決めた値を使っているか」であって harness の一致ではない。
      final panelContext = tester.element(find.byKey(renameWarningsKey));
      final screenHeight = MediaQuery.sizeOf(panelContext).height;
      expect(
        tester.getSize(find.byKey(renameWarningDetailKey)).height,
        RenameWarningPanel.detailMaxHeightFor(screenHeight),
      );
      // 固定値のままなら、この主張は成り立たない。
      expect(
        RenameWarningPanel.detailMaxHeightFor(screenHeight),
        greaterThan(RenameWarningPanel.detailMaxHeight),
      );
    });

    testWidgets('帯の高さは画面の半分を超えない', (tester) async {
      const size = Size(360, 1000);
      final panel = await pumpExpandedPanel(tester, size);

      // **これは「画面」に対する上限であって、「一覧の取り分」ではない。** 帯は
      // header や bar と同じ Column に載るので、一覧の見える範囲に対する割合は
      // これより大きくなる。2026-08-29 の実機確認で、開いた帯が一覧の半分以上を
      // 覆うことを観測した(残余risk N-9。帯そのものを置き換える `T16` が引き取る)。
      // ここで固定するのは、**画面に対して青天井にはしていない**ことだけである。
      expect(panel.height, lessThan(size.height * 0.5));
    });
  });
}
