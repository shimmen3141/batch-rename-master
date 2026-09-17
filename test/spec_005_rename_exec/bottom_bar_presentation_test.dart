// VER-005(続き): 下部バーの2つのbuttonの提示(FEAT-005 / Strict)。008:T20。
// 対象: REQ-019(実行可否)/ REQ-020(未設定の案内)を利用者が読める形にした部分と、
//       2026-09-02 に受領した要望9(押せると分かる形・トークン表示)・要望14(文言)。
//
// **判定は 001 と 005 のまま。** ここが検査するのは提示だけである。
//
// 検査の主眼は次の3つ。いずれも**両方向**(そうである / そうでない)を固定する。
//
// 1. ルール設定buttonが**一つの押下対象**である(`編集` は飾りで、押下対象ではない)
// 2. 設定中のルールが**トークンを並べた形**で読める(説明文になっていない)
// 3. 実行buttonのlabelが4状態で切り替わり、`N 件をリネーム` の N が
//    「変更が生じるファイル」の件数に一致する
//
// **狭幅と広幅の両方で見る。** 広幅(`RuleBuilderWorkspace._buildWide`)は
// `onEditRule` を渡さないのでルール設定buttonが生成されない。渡さないまま測ると
// 何を検査しても通る(`008:T16` が2回この空振りを作った)ので、**広幅では
// 「生成されないこと」を、狭幅では「一つの押下対象であること」を**見る。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'occupied_support.dart';

FileEntry _f(String name, {DateTime? createdAt}) => FileEntry(
  name: name,
  createdAt: createdAt,
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 1,
  sourceHandle: '/files/$name',
  sourceFolder: '/files',
);

const Key _ruleButtonKey = Key('configure-rule');

/// 狭幅(下部バーにルール設定の導線がある形)。
Future<void> _pumpNarrow(
  WidgetTester tester,
  FileListController c, {
  VoidCallback? onEditRule,
  RenameExecutionController? execution,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(
          controller: c,
          onEditRule: onEditRule ?? () {},
          renameExecution: execution,
        ),
      ),
    ),
  );
}

/// 実行の門つきの一式。
({
  FileListController files,
  FakeRenameExecutor executor,
  RenameExecutionController execution,
})
_wire(List<FileEntry> entries, RenameRule rule) {
  final files = FileListController(files: entries, rule: rule);
  final executor = FakeRenameExecutor(
    files: {for (final e in entries) e.sourceHandle!: e.name},
  );
  return (
    files: files,
    executor: executor,
    execution: RenameExecutionController(
      permission: const UnrestrictedStoragePermission(),
      files: files,
      executor: executor,
      listNames: listNamesOf(executor, folder: '/files'),
    ),
  );
}

String _execLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(executeLabelKey)).data!;

void main() {
  group('要望9: ルール設定buttonは一つの押下対象である', () {
    testWidgets('`編集` を押しても、buttonの左端を押しても同じ導線が開く', (tester) async {
      var opened = 0;
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pumpNarrow(tester, c, onEditRule: () => opened += 1);

      // **飾りの `編集` を押す。** ここに独立した button があると、以前の形では
      // 「編集を押す必要がある」と錯覚させた(開発者の原文)。
      expect(find.byKey(ruleEditChipKey), findsOneWidget);
      await tester.tap(find.byKey(ruleEditChipKey));
      await tester.pumpAndSettle();
      expect(opened, 1, reason: '`編集` の上で押しても外側の button が受ける');

      // **見出し側(左端)を押しても同じ。** 押下対象が一つであることは、
      // 離れた2点がどちらも同じ導線を開くことで観測できる。
      final rect = tester.getRect(find.byKey(_ruleButtonKey));
      await tester.tapAt(Offset(rect.left + 6, rect.center.dy));
      await tester.pumpAndSettle();
      expect(opened, 2, reason: 'buttonの左端が反応しない');
    });

    testWidgets('押下対象は入れ子になっていない(button の中に button を置かない)', (tester) async {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pumpNarrow(tester, c);

      // **`編集` が押下対象だと、この数が増える。** 数で押さえるのは、
      // 「見た目が一つに見える」を構造で言い換えたものである。
      expect(
        find.descendant(
          of: find.byKey(_ruleButtonKey),
          matching: find.byType(InkWell),
        ),
        findsNothing,
        reason: 'ルール設定buttonの中に別の押下対象がある',
      );
      expect(
        find.descendant(
          of: find.byKey(_ruleButtonKey),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
        reason: 'ルール設定buttonの中に別の button がある',
      );
    });

    testWidgets('押せると分かる形をしている(枠と塗りが在る)', (tester) async {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pumpNarrow(tester, c);

      // **値そのものは固定しない**(余白・字体・色は `008:T10` が持つ)。
      // 固定するのは「枠が在る」「塗りが透明でも不透明でもない」ことである。
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(_ruleButtonKey),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull, reason: '枠が無い');
      expect(decoration.borderRadius, isNotNull, reason: '角が丸くない');

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(_ruleButtonKey),
              matching: find.byType(Material),
            )
            .first,
      );
      final alpha = material.color!.a;
      expect(alpha, greaterThan(0), reason: '塗りが完全に透明');
      expect(alpha, lessThan(1), reason: '塗りが不透明で、下地から浮いて見えない');
    });

    testWidgets('広幅では下部バーにルール設定の導線が無い', (tester) async {
      // **空振り防止。** 広幅で「一つの押下対象である」を測ると、button が
      // そもそも生成されないので何を書いても通る。ここで不在を明示しておく。
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rule = RuleController()..addToken(const OriginalNameToken());
      addTearDown(rule.dispose);
      final w = _wire([_f('a.txt')], const RenameRule([OriginalNameToken()]));
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: RuleBuilderWorkspace(
              fileList: w.files,
              rule: rule,
              renameExecution: w.execution,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_ruleButtonKey), findsNothing);
      // **実行buttonは広幅にも在る。** 「画面ごと出ていない」で通る空振りを防ぐ。
      expect(find.byKey(const Key('rename-action')), findsOneWidget);
    });
  });

  group('要望9: 設定中のルールはトークンを並べた形で読める', () {
    test('トークンの字面が参考designの形になる', () {
      expect(
        describeRuleSummary(
          const RenameRule([
            OriginalNameToken(),
            LiteralToken('-'),
            SequenceToken(start: 1, digits: 2),
            DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
          ]),
        ),
        '[元の名前]-[01…][作成日時 YYYYMMDD]',
      );
    });

    test('説明文になっていない(両方向)', () {
      const rule = RenameRule([
        SequenceToken(start: 1, digits: 1),
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]);
      final summary = describeRuleSummary(rule);
      // **そうである**: トークンの字面が並ぶ。
      expect(summary, '[1…][作成日時 YYYYMMDD]');
      // **そうでない**: `describeToken` の説明的な字面は使わない
      //(開発者の原文「『連番1桁+作成日時』のような説明的な表示になってしまっている」)。
      expect(summary, isNot(contains('連番')));
      expect(summary, isNot(contains(' + ')));
      // 対照として、説明側は変わっていない(説明は警告と詳細dialogが使う)。
      expect(describeToken(rule.tokens.first), '連番 1 桁');
    });

    test('基準日時の種別を落とさない', () {
      // 参考designの日時トークンは1種類だが、003 は3つ持つ。書式だけにすると
      // どの基準か読めなくなる。
      String summaryOf(DateTimeSource source) => describeRuleSummary(
        RenameRule([DateTimeToken(source: source, format: 'YYYY')]),
      );
      expect(summaryOf(DateTimeSource.created), '[作成日時 YYYY]');
      expect(summaryOf(DateTimeSource.modified), '[更新日時 YYYY]');
      expect(summaryOf(DateTimeSource.current), '[現在日時 YYYY]');
    });

    test('空の固定文字は、何も出ないことが読める形にする', () {
      expect(
        describeRuleSummary(
          const RenameRule([OriginalNameToken(), LiteralToken('')]),
        ),
        '[元の名前]""',
      );
    });

    testWidgets('ルールが長くてもbuttonが伸びない(1行 + 省略記号)', (tester) async {
      // **ルールの長さは占有を変える第三の変数である**(`008:T16` の独立review
      // attempt 4 が挙げた)。長いルールで折り返すと、button が伸びて一覧を削る。
      //
      // **相対比較では押さえられない。** 「長いほうが高い」だけだと折り返し量に
      // 依存する。**短いルールとの高さの一致を絶対値で固定する。**
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<Rect> pumpRule(RenameRule rule) async {
        await _pumpNarrow(
          tester,
          FileListController(files: [_f('a.txt')], rule: rule),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.byKey(_ruleButtonKey));
      }

      final short = await pumpRule(const RenameRule([OriginalNameToken()]));
      final long = await pumpRule(
        const RenameRule([
          OriginalNameToken(),
          LiteralToken('-とても長い固定文字-とても長い固定文字-とても長い固定文字'),
          SequenceToken(start: 1, digits: 4),
          DateTimeToken(
            source: DateTimeSource.created,
            format: 'YYYYMMDDHHmmss',
          ),
          LiteralToken('-さらに長い固定文字-さらに長い固定文字'),
        ]),
      );

      // **前提**: この幅では実際にあふれている。あふれていなければ、
      // 高さが同じでも何も押さえたことにならない(空振り)。
      final paragraph =
          tester.renderObject(find.byKey(ruleSummaryKey)) as RenderParagraph;
      expect(
        paragraph.didExceedMaxLines,
        isTrue,
        reason: 'ルールが短すぎて、あふれる経路を通っていない',
      );

      expect(
        long.height,
        short.height,
        reason: 'ルールが長いとルール設定buttonが伸びて一覧を削っている',
      );
    });

    testWidgets('buttonに出るのもトークンの形である', (tester) async {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([
          OriginalNameToken(),
          SequenceToken(start: 1, digits: 2),
        ]),
      );
      await _pumpNarrow(tester, c);

      expect(
        tester.widget<Text>(find.byKey(ruleSummaryKey)).data,
        '[元の名前][01…]',
      );
    });
  });

  group('要望14: 実行buttonのlabelは4状態', () {
    test('分岐は「対象0件 / 変更あり / ルールが空 / 変更0件」である', () {
      expect(
        executeLabel(selectedCount: 0, changedCount: 0, ruleIsEmpty: false),
        '対象を選択してください',
      );
      expect(
        executeLabel(selectedCount: 3, changedCount: 3, ruleIsEmpty: false),
        '3 件をリネーム',
      );
      expect(
        executeLabel(selectedCount: 3, changedCount: 0, ruleIsEmpty: true),
        'ルールを設定してください',
      );
      // **参考designはここを「ルールを設定してください」へ畳んでいる。**
      // 005 例22a が「ルールは設定されているので未設定の旨は出さない」と定めて
      // いるので、畳まずに分けた。
      expect(
        executeLabel(selectedCount: 3, changedCount: 0, ruleIsEmpty: false),
        '変更されるファイルがありません',
      );
    });

    testWidgets('N 件をリネーム の N は変更が生じるファイルの件数に一致する', (tester) async {
      // 5件中3件だけ改名される(作成日時が無い2件は REQ-022 の除外)。
      final w = _wire(
        [
          _f('keep1.txt'),
          _f('keep2.txt'),
          _f('c1.txt', createdAt: DateTime(2026, 3, 4)),
          _f('c2.txt', createdAt: DateTime(2026, 3, 5)),
          _f('c3.txt', createdAt: DateTime(2026, 3, 6)),
        ],
        const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      await _pumpNarrow(tester, w.files, execution: w.execution);

      expect(w.files.changedFileCount, 3);
      expect(_execLabel(tester), '3 件をリネーム');

      // **選択を1件外すと件数が動く。** 定数を書いただけの実装を排除する。
      w.files.toggleSelection(w.files.items[2]);
      await tester.pump();
      expect(_execLabel(tester), '2 件をリネーム');
    });

    testWidgets('[元の名前] だけのルールでは「未設定」と言わない(例22a)', (tester) async {
      final w = _wire([_f('a.txt')], const RenameRule([OriginalNameToken()]));
      await _pumpNarrow(tester, w.files, execution: w.execution);

      expect(_execLabel(tester), '変更されるファイルがありません');
      // REQ-020 の案内も出さない — ルールは設定されている。
      expect(find.byKey(ruleNotConfiguredKey), findsNothing);
      expect(find.textContaining('命名ルールが未設定'), findsNothing);
    });

    testWidgets('空のルールでは「未設定」と言う(REQ-020)', (tester) async {
      final w = _wire([_f('a.txt')], RenameRule.empty);
      await _pumpNarrow(tester, w.files, execution: w.execution);

      expect(_execLabel(tester), 'ルールを設定してください');
      expect(find.byKey(ruleNotConfiguredKey), findsOneWidget);
    });

    testWidgets('選択が0件なら、ルールがあっても「対象を選択してください」', (tester) async {
      final w = _wire([
        _f('a.txt'),
      ], const RenameRule([OriginalNameToken(), LiteralToken('-x')]));
      w.files.clearAll();
      await _pumpNarrow(tester, w.files, execution: w.execution);

      expect(_execLabel(tester), '対象を選択してください');
    });

    testWidgets('狭幅と広幅のどちらでも同じlabelが出る', (tester) async {
      for (final size in [const Size(400, 800), const Size(1200, 800)]) {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final rule = RuleController()..addToken(const OriginalNameToken());
        addTearDown(rule.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(
                key: ValueKey('bar-${size.width}'),
                fileList: FileListController(files: [_f('a.txt')]),
                rule: rule,
                renameExecution: _wire([
                  _f('a.txt'),
                ], const RenameRule([OriginalNameToken()])).execution,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _execLabel(tester),
          '変更されるファイルがありません',
          reason: '幅 ${size.width} でlabelが違う',
        );
      }
    });
  });
}
