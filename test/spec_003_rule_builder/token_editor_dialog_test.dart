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
import 'token_chip_support.dart';

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

/// 追加ボタン(`＋ 連番`)か、説明が [label] のチップを押す(008:T45 でチップの
/// 文字が種類名 + 値になった)。
Future<void> _open(WidgetTester tester, String label) async {
  final chip = tokenChip(label);
  await tester.tap(chip.evaluate().isNotEmpty ? chip : find.text(label));
  await tester.pumpAndSettle();
}

/// ダイアログのカード(中身の高さ)。`Dialog`そのものは画面いっぱいの大きさを持つ。
Finder get _card => find.descendant(
  of: find.byKey(tokenEditorKey),
  matching: find.byType(AnimatedSize),
);

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

    testWidgets('日時の説明(開発者の指定)', (tester) async {
      await _pump(tester, RuleController());
      await _open(tester, '＋ 日時');
      expect(find.text('基準となる日時とフォーマットを選んでください。'), findsOneWidget);
    });

    testWidgets('連番の説明(manual 1回目の開発者の指定)', (tester) async {
      await _pump(tester, RuleController());
      await _open(tester, '＋ 連番');
      expect(find.text('リネームリスト一覧の上から順に番号を振ります。'), findsOneWidget);
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
        await tester.tap(tokenChip('日時 YYYYMMDD').last);
        await tester.pumpAndSettle();
        final first = fl.rows.first.source.createdAt!;
        final expected =
            '${first.year}${first.month.toString().padLeft(2, '0')}'
            '${first.day.toString().padLeft(2, '0')}';
        expect(_example(tester), expected);
      });
    }
  });

  // manual 1回目で開発者が挙げた改善点(task.md「3.3の結果とUIの改善点」)。
  group('manual 1回目の改善点', () {
    testWidgets('連番のゼロ埋めのスイッチは開始番号の上にある', (tester) async {
      await _pump(tester, RuleController());
      await _open(tester, '＋ 連番');
      final zeroPad = tester.getTopLeft(find.byKey(sequenceZeroPadKey)).dy;
      final start = tester.getTopLeft(find.text('開始番号')).dy;
      expect(zeroPad, lessThan(start));
    });

    testWidgets('日時の入力欄は「詳細に記述」を選んだときだけ出て、直前のフォーマットが入っている', (tester) async {
      final c = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ],
      );
      await _pump(tester, c);
      await _open(tester, '日時 YYYYMMDD');
      expect(find.byKey(dateTimeFormatFieldKey), findsNothing);

      // プリセットを選んでから「詳細に記述」 → そのプリセットが入っている。
      await tester.tap(find.text('YYYY-MM-DD'));
      await tester.pump();
      await tester.tap(find.text(dateTimeCustomFormatLabel));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(dateTimeFormatFieldKey),
      );
      expect(field.controller!.text, 'YYYY-MM-DD');
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, dateTimeCustomFormatLabel),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'YYYY-MM-DD'))
            .selected,
        isFalse,
        reason: '詳細に記述を選んでいる間はプリセットを選ばれた扱いにしない',
      );

      // 書き足して確定すると、書いたフォーマットになる。
      await tester.enterText(find.byKey(dateTimeFormatFieldKey), 'YYYY年MM月');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '確定'));
      await tester.pumpAndSettle();
      expect((c.tokens.single as DateTimeToken).format, 'YYYY年MM月');
    });

    testWidgets('プリセットを選び直すと入力欄は消える', (tester) async {
      await _pump(tester, RuleController());
      await _open(tester, '＋ 日時');
      await tester.tap(find.text(dateTimeCustomFormatLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(dateTimeFormatFieldKey), findsOneWidget);
      await tester.tap(find.text('YYMMDD'));
      await tester.pumpAndSettle();
      expect(find.byKey(dateTimeFormatFieldKey), findsNothing);
    });

    testWidgets('プリセットに無いフォーマットの日時は「詳細に記述」を選んだ状態で開く', (tester) async {
      final c = RuleController(
        tokens: const [
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY年MM月DD日'),
        ],
      );
      await _pump(tester, c);
      await _open(tester, '日時 YYYY年MM月DD日');
      final field = tester.widget<TextField>(
        find.byKey(dateTimeFormatFieldKey),
      );
      expect(field.controller!.text, 'YYYY年MM月DD日');
    });

    for (final (name, open, toggle) in [
      (
        '連番のゼロ埋めを切り替えたとき',
        '＋ 連番',
        (WidgetTester t) => t.tap(find.byKey(sequenceZeroPadKey)),
      ),
      (
        '日時の「詳細に記述」を選んだとき',
        '＋ 日時',
        (WidgetTester t) => t.tap(find.text(dateTimeCustomFormatLabel)),
      ),
    ]) {
      testWidgets('$name、ダイアログの高さは途中の値を通って滑らかに変わる', (tester) async {
        await _pump(tester, RuleController(), count: 3);
        await _open(tester, open);
        final before = tester.getSize(_card).height;

        await toggle(tester);
        await tester.pump(); // 切り替えたフレーム
        await tester.pump(tokenEditorResizeDuration ~/ 2);
        final middle = tester.getSize(_card).height;
        await tester.pumpAndSettle();
        final after = tester.getSize(_card).height;

        expect(after, isNot(closeTo(before, 1)), reason: '高さは変わる');
        final lo = before < after ? before : after;
        final hi = before < after ? after : before;
        expect(middle, greaterThan(lo + 1), reason: '急に変わらない');
        expect(middle, lessThan(hi - 1), reason: '急に変わらない');
      });
    }
  });
}
