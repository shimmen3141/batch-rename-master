// VER-002(008:T45 分): ルール構築シートとトークンの並びを参考デザインへ整えた。
//
// 003 spec は見た目を縛らないので、ここで守るのは**開発者が選んだ提示**である:
// シートの見出し(「閉じる」は置かない)、下部のプレビュー、チップの種類名と
// 一覧の1件目での値、点線の枠の中での長押しドラッグによる並べ替え。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/ui/theme/token_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'token_chip_support.dart';

FileEntry _file(String name, {DateTime? created}) => FileEntry(
  name: name,
  createdAt: created,
  modifiedAt: DateTime(2026, 5, 6),
  size: 0,
);

void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpWorkspace(
  WidgetTester tester,
  FileListController fl,
  RuleController rc,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: RuleBuilderWorkspace(fileList: fl, rule: rc),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('configure-rule')));
  await tester.pumpAndSettle();
}

Finder _inChip(String description, String text) =>
    find.descendant(of: tokenChip(description), matching: find.text(text));

void main() {
  group('シート(狭幅)', () {
    testWidgets('取っ手と見出し「命名ルール」があり、「閉じる」ボタンは無い', (tester) async {
      _narrow(tester);
      await _pumpWorkspace(
        tester,
        FileListController(files: [_file('a.txt')]),
        RuleController(),
      );
      await _openSheet(tester);

      expect(find.byKey(ruleSheetKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ruleSheetKey),
          matching: find.text('命名ルール'),
        ),
        findsOneWidget,
      );
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.showDragHandle, isTrue);
      expect(find.text('閉じる'), findsNothing, reason: '開発者の決定: 逆に混乱を招く');
    });

    testWidgets('プレビュー: 1つ目のファイルの元の名前(取り消し線)→ 新しい名前', (tester) async {
      _narrow(tester);
      final fl = FileListController(files: [_file('b.txt'), _file('a.txt')]);
      final rc = RuleController(tokens: const [LiteralToken('X')]);
      await _pumpWorkspace(tester, fl, rc);
      await _openSheet(tester);

      final preview = find.byKey(ruleSheetPreviewKey);
      expect(preview, findsOneWidget);
      final first = fl.rows.first;
      final old = tester.widget<Text>(
        find.descendant(of: preview, matching: find.text(first.currentName)),
      );
      expect(old.style!.decoration, TextDecoration.lineThrough);
      expect(
        find.descendant(of: preview, matching: find.text(first.newName!)),
        findsOneWidget,
      );

      // ルールを変えると追随する。
      rc.replaceAt(0, const LiteralToken('Y'));
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(of: preview, matching: find.text('Y.txt')),
        findsOneWidget,
      );
    });

    testWidgets('プレビュー: 名前が変わらなければ「（変更なし）」で、取り消し線は無い', (tester) async {
      _narrow(tester);
      final fl = FileListController(files: [_file('a.txt')]);
      await _pumpWorkspace(
        tester,
        fl,
        RuleController(tokens: const [OriginalNameToken()]),
      );
      await _openSheet(tester);
      final preview = find.byKey(ruleSheetPreviewKey);
      expect(
        find.descendant(of: preview, matching: find.text('（変更なし）')),
        findsOneWidget,
      );
      final old = tester.widget<Text>(
        find.descendant(of: preview, matching: find.text('a.txt')),
      );
      expect(old.style!.decoration, isNot(TextDecoration.lineThrough));
    });

    testWidgets('1件目が未選択なら、プレビューもチップの値も選択されている最初のファイルを指す', (tester) async {
      // 008:T45 独立review attempt 1 の指摘。未選択の行は変更後名を持たない
      // (002 REQ-007)ので、1件目をそのまま使うと「（変更なし）」と取り違える。
      _narrow(tester);
      final fl = FileListController(
        files: [
          _file('a.jpg', created: DateTime(2026, 1, 2)),
          _file('b.jpg', created: DateTime(2026, 3, 4)),
        ],
      );
      final rc = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ],
      );
      await _pumpWorkspace(tester, fl, rc);
      fl.toggleSelection(fl.rows.first.source);
      await tester.pump();
      final firstSelected = fl.rows.firstWhere((r) => r.selected);
      expect(firstSelected.currentName, isNot(fl.rows.first.currentName));

      await _openSheet(tester);
      final preview = find.byKey(ruleSheetPreviewKey);
      expect(
        find.descendant(of: preview, matching: find.text('（変更なし）')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text(firstSelected.currentName),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text(firstSelected.newName!),
        ),
        findsOneWidget,
      );
      final created = firstSelected.source.createdAt!;
      final expected =
          '${created.year}${created.month.toString().padLeft(2, '0')}'
          '${created.day.toString().padLeft(2, '0')}';
      expect(_inChip('日時 YYYYMMDD', expected), findsOneWidget);
    });

    testWidgets('プレビュー: 一覧が空なら出さない', (tester) async {
      _narrow(tester);
      await _pumpWorkspace(
        tester,
        FileListController(files: const []),
        RuleController(tokens: const [LiteralToken('X')]),
      );
      await _openSheet(tester);
      expect(find.byKey(ruleSheetPreviewKey), findsNothing);
    });
  });

  group('チップ(参考デザイン: 種類ごとの色、種類名 + 一覧の1件目での値)', () {
    testWidgets('連番は1番目の値、日時は1件目の日時、区切りと文字列は値そのもの', (tester) async {
      _narrow(tester);
      final fl = FileListController(
        files: [_file('a.jpg', created: DateTime(2026, 1, 2))],
      );
      final rc = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
          LiteralToken('_'),
          LiteralToken('旅行'),
          SequenceToken(start: 1, digits: 3),
        ],
      );
      await _pumpWorkspace(tester, fl, rc);
      await _openSheet(tester);

      expect(_inChip('日時 YYYYMMDD', '作成日時'), findsOneWidget);
      expect(_inChip('日時 YYYYMMDD', '20260102'), findsOneWidget);
      expect(_inChip('_', '区切り'), findsOneWidget);
      expect(_inChip('旅行', 'テキスト'), findsOneWidget);
      expect(_inChip('連番(3桁)', '連番'), findsOneWidget);
      expect(_inChip('連番(3桁)', '001'), findsOneWidget);
    });

    testWidgets('一覧が変わると、チップの値も描き直す(広幅でも)', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fl = FileListController(
        files: [_file('a.jpg', created: DateTime(2026, 1, 2))],
      );
      final rc = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ],
      );
      await _pumpWorkspace(tester, fl, rc);
      expect(_inChip('日時 YYYYMMDD', '20260102'), findsOneWidget);

      fl.setFiles([_file('b.jpg', created: DateTime(2026, 3, 4))]);
      await tester.pump();
      expect(_inChip('日時 YYYYMMDD', '20260304'), findsOneWidget);
    });

    testWidgets('日時の基準が不明なら「不明」(別の日時で代えない)', (tester) async {
      _narrow(tester);
      await _pumpWorkspace(
        tester,
        FileListController(files: [_file('a.jpg')]),
        RuleController(
          tokens: const [
            DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
          ],
        ),
      );
      await _openSheet(tester);
      expect(_inChip('日時 YYYYMMDD', '不明'), findsOneWidget);
    });

    testWidgets('種類ごとに違う色の面と枠', (tester) async {
      final rc = RuleController(
        tokens: const [
          OriginalNameToken(),
          LiteralToken('_'),
          LiteralToken('旅行'),
          SequenceToken(digits: 2),
          DateTimeToken(source: DateTimeSource.created, format: 'YY'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(body: RuleBuilderView(controller: rc)),
        ),
      );
      final hues = <Color>{};
      for (final token in rc.tokens) {
        final chip = tester.widget<TokenChip>(
          find.byWidgetPredicate(
            (w) => w is TokenChip && identical(w.token, token),
          ),
        );
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byWidget(chip),
                matching: find.byType(Material),
              )
              .first,
        );
        // 枠の暗い面に種類の色を薄く敷いた色(manual 1回目で削除の円の中と揃えた)。
        expect(
          material.color,
          Color.alphaBlend(
            tokenHue(token).withValues(alpha: 0.10),
            AppColors.dark.background,
          ),
        );
        hues.add(tokenHue(token));
      }
      expect(hues, hasLength(5), reason: '5種がそれぞれ違う色');
    });
  });

  group('点線の枠の中の並び', () {
    testWidgets('横にスクロールする枠で、並べ替えの手掛かりを出す', (tester) async {
      final rc = RuleController(
        tokens: const [OriginalNameToken(), LiteralToken('_')],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(body: RuleBuilderView(controller: rc)),
        ),
      );
      final list = tester.widget<ReorderableListView>(
        find.descendant(
          of: find.byKey(tokenFrameKey),
          matching: find.byType(ReorderableListView),
        ),
      );
      expect(list.scrollDirection, Axis.horizontal);
    });

    testWidgets('チップを長押しして横へ動かすと並べ替わる(003 REQ-004)', (tester) async {
      final rc = RuleController(
        tokens: const [LiteralToken('AA'), LiteralToken('BB')],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(body: RuleBuilderView(controller: rc)),
        ),
      );
      final first = tester.getCenter(tokenChip('AA'));
      final second = tester.getCenter(tokenChip('BB'));
      final gesture = await tester.startGesture(first);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      // 並べ替えは少しずつ動かしたときに追随する(一度に飛ばすと位置を拾えない)。
      final distance = second.dx - first.dx + 40;
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(distance / 10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(rc.tokens.map((t) => (t as LiteralToken).value).toList(), [
        'BB',
        'AA',
      ]);
    });

    testWidgets('押してすぐ動かしても並べ替えない(枠のスクロールに使う)', (tester) async {
      final rc = RuleController(
        tokens: const [LiteralToken('AA'), LiteralToken('BB')],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(body: RuleBuilderView(controller: rc)),
        ),
      );
      final first = tester.getCenter(tokenChip('AA'));
      final second = tester.getCenter(tokenChip('BB'));
      // 長押しの時間を待たずに、長押しのtestと同じ動かし方(少しずつ)で動かす。
      final gesture = await tester.startGesture(first);
      final distance = second.dx - first.dx + 40;
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(distance / 10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(rc.tokens.map((t) => (t as LiteralToken).value).toList(), [
        'AA',
        'BB',
      ]);
    });
  });

  // manual 1回目で開発者が挙げた改善点(task.md「manual 1回目の結果と改善点」)。
  group('manual 1回目の改善点', () {
    Future<void> pumpView(WidgetTester tester, RuleController rc) =>
        tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(body: RuleBuilderView(controller: rc)),
          ),
        );

    testWidgets('並べ替えの案内は枠の外(上)に、指定の文言で出る', (tester) async {
      await pumpView(tester, RuleController(tokens: const [LiteralToken('_')]));
      expect(tokenReorderHint, 'チップを押すと各設定が開けます。チップを長押ししてドラッグすると並び替えられます。');
      final hint = find.text(tokenReorderHint);
      expect(hint, findsOneWidget);
      expect(
        find.descendant(of: find.byKey(tokenFrameKey), matching: hint),
        findsNothing,
        reason: '点線の枠の中には書かない',
      );
      expect(
        tester.getBottomLeft(hint).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(tokenFrameKey)).dy),
        reason: '枠の上',
      );
    });

    testWidgets('チップが0個なら案内を出さず、同じ高さの空きだけ残す', (tester) async {
      final rc = RuleController(tokens: const [LiteralToken('_')]);
      await pumpView(tester, rc);
      final withChip = tester.getSize(find.byKey(tokenReorderHintKey)).height;
      final frameTop = tester.getTopLeft(find.byKey(tokenFrameKey)).dy;

      rc.removeAt(0);
      await tester.pump();
      expect(find.text(tokenReorderHint), findsNothing);
      expect(tester.getSize(find.byKey(tokenReorderHintKey)).height, withChip);
      expect(tester.getTopLeft(find.byKey(tokenFrameKey)).dy, frameTop);
    });

    testWidgets('種別名は左寄せ、削除の円は右上でチップの上辺と右辺に重なり、少しはみ出す', (tester) async {
      await pumpView(
        tester,
        RuleController(tokens: const [LiteralToken('ABCDEFGHIJ')]),
      );
      // 値が長いチップで見る(値の行がチップの幅を決め、上段に余りが出る)。
      final chip = find
          .descendant(
            of: tokenChip('ABCDEFGHIJ'),
            matching: find.byType(Material),
          )
          .first;
      final circle = find.descendant(
        of: tokenChip('ABCDEFGHIJ'),
        matching: find.byKey(tokenChipDeleteKey),
      );
      final chipRect = tester.getRect(chip);
      final circleRect = tester.getRect(circle);
      // manual 2回目: チップから少しはみ出す。はみ出す量は上と右とも同じ。
      expect(
        circleRect.top,
        closeTo(chipRect.top - tokenChipDeleteOverhang, 0.5),
      );
      expect(
        circleRect.right,
        closeTo(chipRect.right + tokenChipDeleteOverhang, 0.5),
      );
      expect(tokenChipDeleteOverhang, greaterThan(0));
      expect(
        tokenChipDeleteOverhang,
        lessThan(tokenChipDeleteSize / 2),
        reason: '円の大半はチップに重なる',
      );

      final kind = tester.getRect(
        find.descendant(
          of: tokenChip('ABCDEFGHIJ'),
          matching: find.text('テキスト'),
        ),
      );
      expect(kind.left, closeTo(chipRect.left + 8, 0.5), reason: '左寄せ');
      expect(kind.right, lessThan(circleRect.left), reason: '円と重ならない');
    });

    testWidgets('削除の円: ×は今の大きさで、押せる範囲は円の大きさ。縁と×はチップの色、中は面の色', (tester) async {
      const token = SequenceToken(digits: 2);
      final rc = RuleController(tokens: const [token]);
      await pumpView(tester, rc);
      final circle = find.byKey(tokenChipDeleteKey);
      expect(tester.getSize(circle), const Size(22, 22));
      final icon = tester.widget<Icon>(
        find.descendant(of: circle, matching: find.byIcon(Icons.close)),
      );
      expect(icon.size, 12);
      expect(icon.color, tokenHue(token));
      final material = tester.widget<Material>(circle);
      expect((material.shape! as CircleBorder).side.color, tokenHue(token));
      expect(
        material.color,
        Color.alphaBlend(
          tokenHue(token).withValues(alpha: 0.10),
          AppColors.dark.background,
        ),
      );

      // チップからはみ出した部分(円の右端寄り)を押しても消える。
      final rect = tester.getRect(circle);
      await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
      await tester.pump();
      expect(rc.tokens, isEmpty);
    });

    testWidgets('プレビューの高さは、変更あり・変更なし・長い名前で変わらない(manual 2回目)', (tester) async {
      _narrow(tester);
      final rc = RuleController(tokens: const [OriginalNameToken()]);
      await _pumpWorkspace(
        tester,
        FileListController(files: [_file('a.txt')]),
        rc,
      );
      await _openSheet(tester);
      double height() => tester.getSize(find.byKey(ruleSheetPreviewKey)).height;
      double sheet() => tester.getSize(find.byKey(ruleSheetKey)).height;
      final unchanged = height();
      final sheetUnchanged = sheet();
      Finder inPreview(String text) => find.descendant(
        of: find.byKey(ruleSheetPreviewKey),
        matching: find.text(text),
      );
      expect(inPreview('（変更なし）'), findsOneWidget);

      rc.replaceAt(0, const LiteralToken('X'));
      await tester.pump();
      await tester.pump();
      expect(inPreview('X.txt'), findsOneWidget);
      expect(height(), unchanged, reason: '変更ありでも同じ高さ');
      expect(sheet(), sheetUnchanged);

      rc.replaceAt(0, LiteralToken('長い名前' * 20));
      await tester.pump();
      await tester.pump();
      expect(height(), unchanged, reason: '長い名前でも折り返さない');
      expect(sheet(), sheetUnchanged);

      // 名前はどちらも1行に収め、はみ出す分は省く(箱の高さを固定しても、折り返すと
      // 文字が箱の外へはみ出して描かれる)。
      for (final name in ['a.txt', '${'長い名前' * 20}.txt']) {
        final text = tester.widget<Text>(inPreview(name));
        expect(text.maxLines, 1, reason: name);
        expect(text.overflow, TextOverflow.ellipsis, reason: name);
      }
    });

    testWidgets('並べ替えの案内の置き場と枠は、チップの有無で高さが変わらない', (tester) async {
      _narrow(tester);
      final rc = RuleController();
      await _pumpWorkspace(
        tester,
        FileListController(files: [_file('a.txt')]),
        rc,
      );
      await _openSheet(tester);
      final empty = tester.getSize(find.byKey(ruleSheetKey)).height;
      rc.addToken(const SequenceToken(digits: 2));
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byKey(ruleSheetKey)).height, empty);
    });

    testWidgets('プレビューの矢印は濃い文字色で、下に余白がある', (tester) async {
      _narrow(tester);
      await _pumpWorkspace(
        tester,
        FileListController(files: [_file('a.txt')]),
        RuleController(tokens: const [LiteralToken('X')]),
      );
      await _openSheet(tester);
      final arrow = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ruleSheetPreviewKey),
          matching: find.text('→ '),
        ),
      );
      expect(arrow.style!.color, AppColors.dark.textPrimary);
      // プレビューの最後の行(新しい名前)の下端からシートの下端まで。
      final last = tester.getRect(
        find.descendant(
          of: find.byKey(ruleSheetPreviewKey),
          matching: find.text('X.txt'),
        ),
      );
      final sheet = tester.getRect(find.byKey(ruleSheetKey));
      expect(sheet.bottom - last.bottom, greaterThanOrEqualTo(32));
    });
  });

  // 独立review attempt 4 の指摘(P2): 高さを固定した箱は、端末の文字の拡大に
  // 合わせる。大きな文字でも文字が箱に収まり、変更あり/なしで高さが変わらない。
  group('文字を2倍に拡大したとき', () {
    Future<void> pumpScaled(
      WidgetTester tester,
      FileListController fl,
      RuleController rc,
    ) async {
      _narrow(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: RuleBuilderWorkspace(fileList: fl, rule: rc),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('configure-rule')));
      await tester.pumpAndSettle();
    }

    // 文字が本来要る高さ(折り返しを含む)で、箱に収まるかを見る。描かれる大きさは
    // 箱に切り詰められるので、描かれた位置だけでは切れていることが分からない。
    bool fits(WidgetTester tester, Finder text, Rect box) {
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final top = tester.getTopLeft(text).dy;
      final needed = paragraph.getMinIntrinsicHeight(paragraph.size.width);
      return top >= box.top - 0.5 && top + needed <= box.bottom + 0.5;
    }

    testWidgets('案内・チップ・プレビューの文字が箱に収まり、高さは変わらない', (tester) async {
      final fl = FileListController(files: [_file('a.txt')]);
      final rc = RuleController(
        tokens: const [SequenceToken(digits: 2), LiteralToken('X')],
      );
      await pumpScaled(tester, fl, rc);
      expect(tester.takeException(), isNull, reason: 'はみ出し(overflow)が無い');

      final hintBox = tester.getRect(find.byKey(tokenReorderHintKey));
      expect(fits(tester, find.text(tokenReorderHint), hintBox), isTrue);

      final frame = tester.getRect(find.byKey(tokenFrameKey));
      final value = find.descendant(
        of: tokenChip('連番(2桁)'),
        matching: find.text('01'),
      );
      expect(fits(tester, value, frame), isTrue);

      final result = find.byKey(ruleSheetPreviewResultKey);
      final resultBox = tester.getRect(result);
      final newName = find.descendant(
        of: result,
        matching: find.text('01X.txt'),
      );
      expect(fits(tester, newName, resultBox), isTrue);
      final sheet = tester.getSize(find.byKey(ruleSheetKey)).height;

      // 変更なしへ切り替えても高さは変わらず、文字は箱に収まる。
      rc
        ..removeAt(1)
        ..removeAt(0)
        ..addToken(const OriginalNameToken());
      await tester.pump();
      await tester.pump();
      final same = find.descendant(of: result, matching: find.text('（変更なし）'));
      expect(same, findsOneWidget);
      expect(fits(tester, same, tester.getRect(result)), isTrue);
      expect(tester.getSize(find.byKey(ruleSheetKey)).height, sheet);
      expect(tester.takeException(), isNull);
    });
  });
}
