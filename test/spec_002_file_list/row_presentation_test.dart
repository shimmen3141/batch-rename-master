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

  group('008:T16 (i) 件数が多くても一覧を覆わない', () {
    /// 重複警告を [count] 件出す一覧を、指定した画面サイズで描く。
    ///
    /// 全ファイルが同じ名前になるルールを与えると、001 は重複警告を件数ぶん返す。
    Future<Rect> pumpList(WidgetTester tester, Size size, int count) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: FileListView(
              key: ValueKey('list-$count'),
              controller: FileListController(
                files: [
                  for (var i = 0; i < count; i++)
                    FileEntry(
                      name: 'IMG_${i.toString().padLeft(4, '0')}.jpg',
                      modifiedAt: DateTime(2026, 8, 4),
                      size: 0,
                      sourceLocation: 'DCIM/Camera',
                    ),
                ],
                rule: const RenameRule([LiteralToken('photo')]),
              ),
            ),
          ),
        ),
      );
      return tester.getRect(find.byType(ReorderableListView));
    }

    testWidgets('警告の件数が増えても一覧の取り分が変わらない', (tester) async {
      // **`T07` の残余risk N-9 がここで閉じる。** 集約帯は件数に応じて縦を食い、
      // 2026-08-29 の実機確認では開いた帯が一覧の見える範囲の半分以上を覆った。
      // 置換先(常時 1 行の件数表示 + modal)は**件数に依存しない**。
      const size = Size(360, 640);
      final few = await pumpList(tester, size, 2);
      final many = await pumpList(tester, size, 30);

      expect(many.height, few.height, reason: '警告の件数が一覧の高さを削っている');
    });

    testWidgets('警告が 1 件も無いときと比べても一覧の取り分が変わらない', (tester) async {
      // 件数表示は 0 件でも「問題なし」を出す(005 REQ-010: それは警告ではない)。
      // **常時 1 行**なので、警告の有無で一覧が伸び縮みしない。
      const size = Size(360, 640);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: FileListView(
              controller: FileListController(
                files: [_unknownCreatedAt()],
                // 元名だけのルールなら警告は出ない。
                rule: const RenameRule([OriginalNameToken()]),
              ),
            ),
          ),
        ),
      );
      final clean = tester.getRect(find.byType(ReorderableListView));

      final warned = await pumpList(tester, size, 30);
      expect(warned.height, clean.height);
    });

    testWidgets('狭幅でも文字を大きくしても、ヘッダの数字が消えない', (tester) async {
      // **overflow を見るだけでは足りない。** `Flexible` + ellipsis は
      // **内容を切ることで overflow を出さない**ので、はみ出しの検査では
      // 「文字が消えた」を検出できない(独立reviewが2回続けて見つけた)。
      // 実際に `200 / 2…`(総数が読めない)や `1000 / 1…`(総数を1と誤読)に
      // なっていた。**情報が減るのではなく誤りになる**ので切り詰め自体を見る。
      //
      // ヘッダは `Wrap` なので、入らないときは切らずに次の行へ落ちる。
      for (final width in [320.0, 360.0, 411.0]) {
        // 2.0 は端末の「フォントサイズ最大」に近い。ここで初めて選択件数が
        // 2 行を必要とするので、折り返しの下限がここで効く。
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final count in [30, 200, 1000]) {
            await tester.binding.setSurfaceSize(Size(width, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                theme: appDarkTheme(),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: FileListView(
                      key: ValueKey('count-$width-$scale-$count'),
                      controller: FileListController(
                        files: [
                          for (var i = 0; i < count; i++)
                            FileEntry(
                              name: 'IMG_${i.toString().padLeft(4, '0')}.jpg',
                              modifiedAt: DateTime(2026, 8, 4),
                              size: 0,
                              sourceLocation: 'DCIM/Camera',
                            ),
                        ],
                        rule: const RenameRule([LiteralToken('photo')]),
                      ),
                    ),
                  ),
                ),
              ),
            );

            final where = '幅 $width / 文字 $scale / $count 件';
            // 何件の問題か。
            expect(
              tester
                  .renderObject<RenderParagraph>(
                    find.descendant(
                      of: find.byKey(warningCountKey),
                      matching: find.byType(Text),
                    ),
                  )
                  .didExceedMaxLines,
              isFalse,
              reason: '$where で警告の件数が切り詰められている',
            );
            // **総数が切れると `1000 / 1…` が「総数 1」と読める。**
            expect(
              tester
                  .renderObject<RenderParagraph>(
                    find.byKey(const Key('selection-count')),
                  )
                  .didExceedMaxLines,
              isFalse,
              reason: '$where で選択件数が切り詰められている',
            );
          }
        }
      }
    });

    testWidgets('狭幅でヘッダに件数を足してもはみ出さない', (tester) async {
      // 件数表示は `_HeaderBar` へ足した。**既存の選択件数と同じ行**なので、
      // 狭幅で押し出さないことを確かめる(`_HeaderBar` は文字サイズ最大では
      // 別途 overflow するが、それは `008:T10` が引き受けた N-8b である)。
      for (final width in [320.0, 360.0]) {
        final errors = <String>[];
        final previous = FlutterError.onError;
        await tester.binding.setSurfaceSize(Size(width, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        FlutterError.onError = (details) =>
            errors.add(details.exception.toString());
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: FileListView(
                key: ValueKey('header-$width'),
                controller: FileListController(
                  files: [
                    for (var i = 0; i < 30; i++)
                      FileEntry(
                        name: 'IMG_${i.toString().padLeft(4, '0')}.jpg',
                        modifiedAt: DateTime(2026, 8, 4),
                        size: 0,
                        sourceLocation: 'DCIM/Camera',
                      ),
                  ],
                  rule: const RenameRule([LiteralToken('photo')]),
                ),
              ),
            ),
          ),
        );
        FlutterError.onError = previous;
        expect(errors, isEmpty, reason: '幅 $width ではみ出している');
        expect(find.byKey(warningCountKey), findsOneWidget);
      }
    });

    testWidgets('詳細を開いても一覧の取り分が変わらない', (tester) async {
      // 帯は**その場で展開して**一覧を押し下げていた。modal は覆いかぶさるだけで
      // 一覧の layout を動かさない。
      const size = Size(360, 640);
      final before = await pumpList(tester, size, 30);

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      expect(find.byKey(warningDetailDialogKey), findsOneWidget);
      expect(tester.getRect(find.byType(ReorderableListView)), before);
    });
  });
}
