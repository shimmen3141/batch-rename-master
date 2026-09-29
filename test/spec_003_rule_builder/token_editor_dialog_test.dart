// VER-002(008:T44 分): トークンのエディタを参考デザインの中央のダイアログへ整えた。
//
// 003 spec はエディタの形を「自由とする点」にしているので、ここで守るのは
// **開発者が選んだ提示**(中央のダイアログ、入口ごとの見出しと説明、表示例)と、
// 表示例が**一覧の1件目・件数**から作られる経路である。確定手順(REQ-008〜014)は
// `token_add_confirm_test.dart`・`sequence_zero_pad_editor_test.dart` が持つ。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/token_editors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name, {DateTime? created, DateTime? modified}) =>
    FileEntry(
      name: name,
      createdAt: created,
      modifiedAt: modified ?? DateTime(2026, 5, 6),
      size: 0,
    );

Future<void> _pump(
  WidgetTester tester,
  RuleController c, {
  int count = 0,
  FileEntry? sample,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: RuleBuilderView(
          controller: c,
          itemCount: () => count,
          sampleFile: () => sample,
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

String? _example(WidgetTester tester) {
  final f = find.byKey(tokenEditorExampleKey);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

void main() {
  group('形: 中央のダイアログ(ボトムシートではない)', () {
    testWidgets('追加でも編集でもダイアログで開き、外のタップで閉じる', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 1, digits: 2)],
      );
      await _pump(tester, c);

      await _open(tester, '連番(2桁)');
      expect(find.byKey(tokenEditorKey), findsOneWidget);
      expect(tester.widget(find.byKey(tokenEditorKey)), isA<Dialog>());
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(tokenEditorKey), findsNothing);

      await _open(tester, '＋ 日時');
      expect(tester.widget(find.byKey(tokenEditorKey)), isA<Dialog>());
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('見出しと説明(参考デザイン)', () {
    for (final (add, title) in [
      ('＋ 自由テキスト', '自由テキスト'),
      ('＋ 区切り', '区切り文字'),
      ('＋ 連番', '連番'),
      ('＋ 日時', '日時'),
    ]) {
      testWidgets('$add は「$title」で開く', (tester) async {
        await _pump(tester, RuleController());
        await _open(tester, add);
        expect(
          find.descendant(
            of: find.byKey(tokenEditorKey),
            matching: find.text(title),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('既存の文字列の編集は両方を兼ねる見出しで、入力欄と記号の両方を持つ(003 REQ-011)', (
      tester,
    ) async {
      final c = RuleController(tokens: const [LiteralToken('_')]);
      await _pump(tester, c);
      await _open(tester, '_');
      expect(find.text('自由テキスト / 区切り文字'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // 今の値の記号が選ばれている。
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'アンダーバー _'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('連番の説明は一覧の上から順に振られること', (tester) async {
      await _pump(tester, RuleController());
      await _open(tester, '＋ 連番');
      expect(find.text('一覧の上から順に振られます。'), findsOneWidget);
    });
  });

  group('表示例', () {
    testWidgets('連番: 一覧の件数に振られる最初と最後を、入力中の値で出す', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 1, digits: 2)],
      );
      await _pump(tester, c, count: 3);
      await _open(tester, '連番(2桁)');
      expect(_example(tester), '01 ～ 03');
      expect(find.text('表示例（一覧の 3 件に上から順に振られます）'), findsOneWidget);

      // 開始番号を変えると追随する(確定前)。
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Row, '開始番号'),
          matching: find.byTooltip('増やす'),
        ),
      );
      await tester.pump();
      expect(_example(tester), '02 ～ 04');

      // ゼロ埋めなしでは数字そのまま。
      await tester.tap(find.byKey(sequenceZeroPadKey));
      await tester.pump();
      expect(_example(tester), '2 ～ 4');
      expect(c.tokens.single, isA<SequenceToken>());
      expect((c.tokens.single as SequenceToken).start, 1, reason: '確定前は変えない');
    });

    testWidgets('連番: 1件以下なら最初の1つだけ', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 7, digits: 3)],
      );
      await _pump(tester, c, count: 1);
      await _open(tester, '連番(3桁)');
      expect(_example(tester), '007');
    });

    testWidgets('日時: 一覧の1件目の基準の日時をフォーマットで描く', (tester) async {
      final c = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ],
      );
      await _pump(
        tester,
        c,
        count: 2,
        sample: _file(
          'a.jpg',
          created: DateTime(2026, 1, 2),
          modified: DateTime(2026, 5, 6),
        ),
      );
      await _open(tester, '日時 YYYYMMDD');
      expect(_example(tester), '20260102');
      expect(find.text('表示例（1つ目のファイルの作成日時）'), findsOneWidget);

      await tester.tap(find.text('更新日時'));
      await tester.pump();
      expect(_example(tester), '20260506');
      await tester.tap(find.text('YYYY-MM-DD'));
      await tester.pump();
      expect(_example(tester), '2026-05-06');
    });

    testWidgets('日時: 1件目の作成日時が不明なら、その旨を出す(別の日時で代えない)', (tester) async {
      final c = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ],
      );
      await _pump(tester, c, count: 1, sample: _file('a.jpg'));
      await _open(tester, '日時 YYYYMMDD');
      expect(_example(tester), '（日時が不明）');
    });

    testWidgets('日時: 一覧が空なら表示例を出さない', (tester) async {
      final c = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ],
      );
      await _pump(tester, c);
      await _open(tester, '日時 YYYYMMDD');
      expect(_example(tester), isNull);
    });

    testWidgets('文字列には表示例を出さない(参考デザインどおり)', (tester) async {
      await _pump(tester, RuleController(), count: 3);
      await _open(tester, '＋ 自由テキスト');
      expect(_example(tester), isNull);
    });
  });

  group('一覧の1件目がエディタへ届く(composition の経路)', () {
    for (final (name, size) in [
      ('広幅(2ペイン)', const Size(1000, 800)),
      ('狭幅(シート)', const Size(400, 800)),
    ]) {
      testWidgets('$name: 日時の表示例が一覧の1件目(表示順)で描かれる', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final fl = FileListController(
          files: [
            _file('b.jpg', created: DateTime(2026, 3, 4)),
            _file('a.jpg', created: DateTime(2026, 1, 2)),
          ],
        );
        final rc = RuleController(
          tokens: const [
            DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(fileList: fl, rule: rc),
            ),
          ),
        );
        await tester.pump();
        if (size.width < 840) {
          await tester.tap(find.byKey(const Key('configure-rule')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('日時 YYYYMMDD').last);
        await tester.pumpAndSettle();
        final first = fl.rows.first.source.createdAt!;
        final expected =
            '${first.year}${first.month.toString().padLeft(2, '0')}'
            '${first.day.toString().padLeft(2, '0')}';
        expect(_example(tester), expected);
      });
    }
  });
}
