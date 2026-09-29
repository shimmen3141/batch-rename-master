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
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/ui/theme/token_colors.dart';
import 'package:flutter/gestures.dart';
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
        expect(material.color, tokenHue(token).withValues(alpha: 0.10));
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
      expect(find.text(tokenReorderHint), findsOneWidget);
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
      await tester.dragFrom(first, Offset(second.dx - first.dx + 40, 0));
      await tester.pumpAndSettle();
      expect(rc.tokens.map((t) => (t as LiteralToken).value).toList(), [
        'AA',
        'BB',
      ]);
    });
  });
}
