// VER-002(008:T06 分): token の追加・編集は確定したときだけ列を変える。
// 対象: 003 REQ-008(開くだけでは変わらず、通知も起きない)/ REQ-009(確定以外の
// すべての閉じ方)/ REQ-010(元の名前は即追加)/ REQ-011(編集。LiteralToken は
// 共通エディタ)/ REQ-012(確定できない入力を追加と編集の両方で)。
//
// 「変わらない」の主張は tokens の値だけでなく**変更通知の回数**で見る。値が一度
// 入って戻る実装は終状態では区別できないが、通知を受けた 007 の保存が途中の値を
// 書くので排除する(003 spec の VER 注記)。閉じる前にエディタの値を変えるのは、
// 入力値を捨てる経路を通すため。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/token_editors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 変更通知を数える [RuleController]。
({RuleController controller, int Function() notified}) _counted([
  List<Token> tokens = const [],
]) {
  final c = RuleController(tokens: tokens);
  var n = 0;
  c.addListener(() => n++);
  return (controller: c, notified: () => n);
}

Future<void> _pumpView(WidgetTester tester, RuleController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: RuleBuilderView(controller: c)),
    ),
  );
}

Finder get _editor => find.byKey(tokenEditorKey);
Finder get _addConfirm => find.widgetWithText(FilledButton, '追加');
Finder get _editConfirm => find.widgetWithText(FilledButton, '確定');

FilledButton _button(WidgetTester tester, Finder f) =>
    tester.widget<FilledButton>(f);

Future<void> _tapAdd(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// 確定以外の閉じ方(REQ-009)。
enum _Close { cancel, back, barrier, drag }

Future<void> _close(WidgetTester tester, _Close how) async {
  switch (how) {
    case _Close.cancel:
      await tester.tap(
        find.descendant(of: _editor, matching: find.text('キャンセル')),
      );
    case _Close.back:
      await tester.binding.handlePopRoute();
    case _Close.barrier:
      await tester.tapAt(const Offset(4, 4));
    case _Close.drag:
      await tester.fling(_editor, const Offset(0, 600), 2000);
  }
  await tester.pumpAndSettle();
}

/// エディタの中で値を変える(既定値のまま閉じるだけにしない)。
Future<void> _edit(WidgetTester tester, String addLabel) async {
  switch (addLabel) {
    case '＋ 自由テキスト' || '＋ 区切り':
      await tester.enterText(
        find.descendant(of: _editor, matching: find.byType(TextField)),
        'changed',
      );
    case '＋ 連番':
      await tester.tap(find.byTooltip('増やす').at(1));
    case '＋ 日時':
      await tester.tap(find.text('更新日時'));
  }
  await tester.pump();
}

const _withSettings = ['＋ 自由テキスト', '＋ 区切り', '＋ 連番', '＋ 日時'];

void main() {
  group('REQ-008: 開くだけでは列も通知も変わらず、確定で1件入る', () {
    for (final label in _withSettings) {
      testWidgets('$label: 開いているあいだ tokens は空・通知0', (tester) async {
        final (:controller, :notified) = _counted();
        await _pumpView(tester, controller);

        await _tapAdd(tester, label);

        expect(_editor, findsOneWidget, reason: 'エディタが開く');
        expect(controller.tokens, isEmpty);
        expect(notified(), 0);

        await _edit(tester, label);
        expect(controller.tokens, isEmpty, reason: 'エディタ内の入力でも列は変わらない');
        expect(notified(), 0);
      });
    }

    testWidgets('自由テキスト: 初期値は空で、入力して追加すると その値で1件', (tester) async {
      final (:controller, :notified) = _counted(const [OriginalNameToken()]);
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 自由テキスト');

      final field = tester.widget<TextField>(
        find.descendant(of: _editor, matching: find.byType(TextField)),
      );
      expect(field.controller!.text, '');

      await tester.enterText(
        find.descendant(of: _editor, matching: find.byType(TextField)),
        'abc',
      );
      await tester.pump();
      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();

      expect(_editor, findsNothing);
      expect(controller.tokens, hasLength(2));
      expect(controller.tokens.first, isA<OriginalNameToken>());
      expect((controller.tokens.last as LiteralToken).value, 'abc');
      expect(notified(), 1, reason: '確定の1回だけ通知する');
    });

    testWidgets('区切り: 初期値 `_` のまま追加すると `_` で1件', (tester) async {
      final (:controller, :notified) = _counted();
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 区切り');

      final field = tester.widget<TextField>(
        find.descendant(of: _editor, matching: find.byType(TextField)),
      );
      expect(field.controller!.text, '_');

      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();

      expect(controller.tokens, hasLength(1));
      expect((controller.tokens.single as LiteralToken).value, '_');
      expect(notified(), 1);
    });

    testWidgets('連番: 桁数を3にして追加すると その値で1件(例7)', (tester) async {
      final (:controller, :notified) = _counted(const [OriginalNameToken()]);
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 連番');

      await tester.tap(find.byTooltip('増やす').at(1)); // 桁数 2 → 3
      await tester.pump();
      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();

      expect(controller.tokens, hasLength(2));
      final t = controller.tokens.last as SequenceToken;
      expect((t.start, t.digits, t.increment), (1, 3, 1));
      expect(notified(), 1);
    });

    testWidgets('連番: 既定値のまま追加すると start1・digits2・increment1', (tester) async {
      final (:controller, notified: _) = _counted();
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 連番');
      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();

      final t = controller.tokens.single as SequenceToken;
      expect((t.start, t.digits, t.increment), (1, 2, 1));
    });

    testWidgets('日時: 既定値は作成日時・YYYYMMDD。基準を変えて追加すると その値で1件', (tester) async {
      final (:controller, :notified) = _counted();
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 日時');

      final field = tester.widget<TextField>(
        find.descendant(of: _editor, matching: find.byType(TextField)),
      );
      expect(field.controller!.text, 'YYYYMMDD');
      final created = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '作成日時'),
      );
      expect(created.selected, isTrue);

      await tester.tap(find.text('更新日時'));
      await tester.pump();
      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();

      final t = controller.tokens.single as DateTimeToken;
      expect((t.source, t.format), (DateTimeSource.modified, 'YYYYMMDD'));
      expect(notified(), 1);
    });
  });

  group('REQ-009: 確定以外の閉じ方では何も変わらない(例8)', () {
    for (final label in _withSettings) {
      for (final how in _Close.values) {
        testWidgets('$label を値を変えてから ${how.name} で閉じる', (tester) async {
          final (:controller, :notified) = _counted(const [
            OriginalNameToken(),
          ]);
          await _pumpView(tester, controller);
          await _tapAdd(tester, label);
          await _edit(tester, label);

          await _close(tester, how);

          expect(_editor, findsNothing, reason: '閉じ方が実際に効いている');
          expect(controller.tokens, hasLength(1));
          expect(controller.tokens.single, isA<OriginalNameToken>());
          expect(notified(), 0);
        });
      }
    }
  });

  testWidgets('REQ-010: 元の名前はエディタを開かずに1件入る(例10)', (tester) async {
    final (:controller, :notified) = _counted();
    await _pumpView(tester, controller);

    await _tapAdd(tester, '＋ 元の名前');

    expect(_editor, findsNothing);
    expect(controller.tokens, hasLength(1));
    expect(controller.tokens.single, isA<OriginalNameToken>());
    expect(notified(), 1);
  });

  group('REQ-011: 既存tokenの編集は確定したときだけ差し替える', () {
    for (final how in _Close.values) {
      testWidgets('連番を桁数4にしてから ${how.name} で閉じると変わらない(例11)', (tester) async {
        final (:controller, :notified) = _counted(const [
          OriginalNameToken(),
          SequenceToken(start: 1, digits: 2),
        ]);
        await _pumpView(tester, controller);
        await tester.tap(find.text('連番(2桁)'));
        await tester.pumpAndSettle();
        expect(_editor, findsOneWidget);

        await tester.tap(find.byTooltip('増やす').at(1));
        await tester.tap(find.byTooltip('増やす').at(1));
        await tester.pump();
        await _close(tester, how);

        expect(_editor, findsNothing);
        expect((controller.tokens.last as SequenceToken).digits, 2);
        expect(notified(), 0);
      });
    }

    testWidgets('編集の確定は1回だけ通知して差し替える', (tester) async {
      final (:controller, :notified) = _counted(const [
        SequenceToken(start: 1, digits: 2),
      ]);
      await _pumpView(tester, controller);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('増やす').at(1));
      await tester.pump();
      await tester.tap(_editConfirm);
      await tester.pumpAndSettle();

      expect((controller.tokens.single as SequenceToken).digits, 3);
      expect(notified(), 1);
    });

    testWidgets('区切りとして入れた文字列tokenも、文字列入力と区切りプリセットの両方を持つ共通エディタで開く', (
      tester,
    ) async {
      final (:controller, notified: _) = _counted();
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 区切り');
      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();
      expect(_editor, findsNothing);

      await tester.tap(find.text('_'));
      await tester.pumpAndSettle();

      expect(_editor, findsOneWidget);
      expect(
        find.descendant(of: _editor, matching: find.byType(TextField)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _editor, matching: find.text('-（ハイフン）')),
        findsOneWidget,
      );
      expect(_editConfirm, findsOneWidget, reason: '編集として開いている');
    });
  });

  group('REQ-012: 確定できない入力(追加と編集の両方)', () {
    for (final label in ['＋ 自由テキスト', '＋ 区切り']) {
      testWidgets('追加 $label: 文字列が空のあいだ追加できない', (tester) async {
        final (:controller, :notified) = _counted();
        await _pumpView(tester, controller);
        await _tapAdd(tester, label);

        await tester.enterText(
          find.descendant(of: _editor, matching: find.byType(TextField)),
          '',
        );
        await tester.pump();
        expect(_button(tester, _addConfirm).onPressed, isNull);

        await tester.tap(_addConfirm);
        await tester.pumpAndSettle();
        expect(controller.tokens, isEmpty);
        expect(notified(), 0);

        await tester.enterText(
          find.descendant(of: _editor, matching: find.byType(TextField)),
          'x',
        );
        await tester.pump();
        expect(_button(tester, _addConfirm).onPressed, isNotNull);
      });
    }

    testWidgets('追加 日時: フォーマットが空のあいだ追加できない', (tester) async {
      final (:controller, notified: _) = _counted();
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 日時');

      await tester.enterText(
        find.descendant(of: _editor, matching: find.byType(TextField)),
        '',
      );
      await tester.pump();
      expect(_button(tester, _addConfirm).onPressed, isNull);
    });

    testWidgets('追加 連番: 開始番号は0未満にできない', (tester) async {
      final (:controller, notified: _) = _counted();
      await _pumpView(tester, controller);
      await _tapAdd(tester, '＋ 連番');

      final dec = find.byTooltip('減らす').at(0);
      await tester.tap(dec); // 1 → 0
      await tester.pump();
      final button = tester.widget<IconButton>(
        find.ancestor(of: dec, matching: find.byType(IconButton)).first,
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('編集 日時: フォーマットを消すと確定できない(例12)', (tester) async {
      final (:controller, notified: _) = _counted(const [
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]);
      await _pumpView(tester, controller);
      await tester.tap(find.text('日時 YYYYMMDD'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: _editor, matching: find.byType(TextField)),
        '',
      );
      await tester.pump();
      expect(_button(tester, _editConfirm).onPressed, isNull);
    });
  });

  group('REQ-008: 一覧のプレビューも確定まで変わらない(狭幅・広幅)', () {
    FileEntry file(String name) => FileEntry(
      name: name,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
      size: 0,
    );

    Future<void> pumpWorkspace(
      WidgetTester tester,
      Size size,
      FileListController fl,
      RuleController rc,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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

    testWidgets('広幅: 右ペインから連番を開いているあいだ fileList.rule は変わらず、追加で反映', (
      tester,
    ) async {
      final fl = FileListController(files: [file('a.txt')]);
      final rc = RuleController(tokens: const [OriginalNameToken()]);
      await pumpWorkspace(tester, const Size(1000, 800), fl, rc);
      expect(find.byType(RuleBuilderView), findsOneWidget);
      expect(fl.rule.tokens, hasLength(1));

      await _tapAdd(tester, '＋ 連番');
      expect(_editor, findsOneWidget);
      expect(fl.rule.tokens, hasLength(1));

      await tester.tap(_addConfirm);
      await tester.pumpAndSettle();
      expect(fl.rule.tokens, hasLength(2));
      expect(fl.rule.tokens.last, isA<SequenceToken>());
    });

    // 狭幅ではエディタがルール設定シートの上へ重なる。確定以外の閉じ方も確定も、
    // **エディタだけ**を閉じてルール設定シートを残す(008:T06 独立review attempt 1 の
    // 指摘2・3で、確定後と戻る操作・スワイプの経路を足した)。
    for (final how in _Close.values) {
      testWidgets(
        '狭幅: ルール設定シートの上で連番を開き ${how.name} で閉じても fileList.rule は変わらず、シートは残る。追加してもシートは残る',
        (tester) async {
          final fl = FileListController(files: [file('a.txt')]);
          final rc = RuleController(tokens: const [OriginalNameToken()]);
          await pumpWorkspace(tester, const Size(500, 800), fl, rc);
          expect(find.byType(RuleBuilderView), findsNothing, reason: '狭幅である');

          await tester.tap(find.byKey(const Key('configure-rule')));
          await tester.pumpAndSettle();
          expect(find.byType(RuleBuilderView), findsOneWidget);

          await _tapAdd(tester, '＋ 連番');
          expect(_editor, findsOneWidget);
          await _edit(tester, '＋ 連番');
          expect(fl.rule.tokens, hasLength(1));

          await _close(tester, how);
          expect(_editor, findsNothing);
          expect(
            find.byType(RuleBuilderView),
            findsOneWidget,
            reason: 'ルール設定シートは閉じない',
          );
          expect(fl.rule.tokens, hasLength(1));
          expect(rc.tokens, hasLength(1));

          await _tapAdd(tester, '＋ 連番');
          await tester.tap(_addConfirm);
          await tester.pumpAndSettle();
          expect(fl.rule.tokens, hasLength(2));
          expect(_editor, findsNothing);
          expect(
            find.byType(RuleBuilderView),
            findsOneWidget,
            reason: '追加を確定してもルール設定シートは閉じない',
          );
        },
      );
    }
  });
}
