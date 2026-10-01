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
import 'package:batch_rename_master/ui/rule_builder/rule_chip_strip.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/ui/theme/token_colors.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:flutter/material.dart';
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

    testWidgets('ルールが長くてもbuttonが伸びない(1段 + 最後のチップのフェード)', (tester) async {
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

      // **前提**: この幅では実際にあふれている(最後に見えるチップがフェードして
      // いる)。あふれていなければ、高さが同じでも何も押さえたことにならない
      // (空振り)。`008:T47` でチップにした。
      expect(
        find.byKey(ruleChipFadeKey),
        findsOneWidget,
        reason: 'ルールが短すぎて、あふれる経路を通っていない',
      );
      expect(tester.takeException(), isNull);

      expect(
        long.height,
        short.height,
        reason: 'ルールが長いとルール設定buttonが伸びて一覧を削っている',
      );
    });

    testWidgets('buttonには設定画面と同じ2段のチップが並ぶ(008:T47)', (tester) async {
      // 2026-09-30 の開発者の決定: 上段に種類名、下段に1件目で描いた値。×は無い。
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([
          OriginalNameToken(),
          SequenceToken(start: 1, digits: 2),
        ]),
      );
      await _pumpNarrow(tester, c);

      final strip = find.byKey(ruleSummaryKey);
      expect(
        find.descendant(of: strip, matching: find.byType(RuleSummaryChip)),
        findsNWidgets(2),
      );
      for (final (kind, value) in [('元の名前', 'ファイル名'), ('連番', '01')]) {
        final kindText = find.descendant(of: strip, matching: find.text(kind));
        final valueText = find.descendant(
          of: strip,
          matching: find.text(value),
        );
        expect(kindText, findsOneWidget, reason: kind);
        expect(valueText, findsOneWidget, reason: value);
        // 種類名が上段、値が下段。
        expect(
          tester.getRect(kindText).bottom,
          lessThanOrEqualTo(tester.getRect(valueText).top),
        );
      }
      // 設定画面と同じ色(種類ごと)。
      final chip = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RuleSummaryChip).at(1),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (chip.decoration! as BoxDecoration).border! as Border;
      expect(
        border.top.color,
        tokenHue(
          const SequenceToken(start: 1, digits: 2),
        ).withValues(alpha: 0.35),
      );
      // 削除の×は無い(押せない表示である)。
      expect(
        find.descendant(of: strip, matching: find.byIcon(Icons.close)),
        findsNothing,
      );
      // 読み上げは字面の要約(buttonの読み上げへ合わさる)。
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: strip, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, '[元の名前][01…]');
    });

    testWidgets('種類名のほうが長いチップでも、値はチップの中央にある(008:T47 実機確認)', (tester) async {
      // 区切り `_` は種類名「区切り」のほうが値より長い。
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_')]),
      );
      await _pumpNarrow(tester, c);

      final chip = find.byType(RuleSummaryChip).at(1);
      final chipRect = tester.getRect(chip);
      final kind = tester.getRect(
        find.descendant(of: chip, matching: find.text('区切り')),
      );
      final valueFinder = find.descendant(of: chip, matching: find.text('_'));
      final value = tester.getRect(valueFinder);
      // 値の枠はチップの幅いっぱい(種類名の幅)まで広がり、文字はその中央に置く。
      // 左寄せなら枠は値の文字の幅だけになり、中央から外れる。
      expect(value.width, closeTo(kind.width, 1));
      expect(value.center.dx, closeTo(chipRect.center.dx, 1));
      expect(tester.widget<Text>(valueFinder).textAlign, TextAlign.center);
    });

    testWidgets('入りきらないときは最後に見えるチップをフェードし、数は出さない(008:T47)', (tester) async {
      // 2026-09-30 の開発者の決定。以前は右端の「+N」にまとめていたが、ちょうど
      // 収まっていたところへ1つ足すと「+1」が入らず「+2」へ飛んだ。幅を少しずつ
      // 変え、チップを1つずつ足して、どの幅・数でも次が成り立つことを見る:
      // 全部入るならフェードは無い。入らなければ**フェードがちょうど1つ**で、
      // その前は前から順に全体が見え、数(「+」)は出ない。
      var sawCut = false;
      var sawFadeRightAfterFit = false;
      var sawNextPeek = false;
      for (var width = 320.0; width <= 440; width += 8) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        var previousFit = false;
        for (var n = 1; n <= 7; n++) {
          final rule = RenameRule([
            for (var i = 0; i < n; i++) LiteralToken('abcdef$i'),
          ]);
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$width-$n'),
              theme: appDarkTheme(),
              home: MediaQuery(
                data: MediaQueryData(size: Size(width, 800)),
                child: Scaffold(
                  body: FileListView(
                    controller: FileListController(
                      files: [_f('a.txt')],
                      rule: rule,
                    ),
                    onEditRule: () {},
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: 'width=$width n=$n');
          final strip = find.byKey(ruleSummaryKey);
          final chips = find
              .descendant(of: strip, matching: find.byType(RuleSummaryChip))
              .evaluate()
              .length;
          final fades = find
              .descendant(of: strip, matching: find.byKey(ruleChipFadeKey))
              .evaluate()
              .length;
          // 数は出さない。
          expect(
            find.descendant(of: strip, matching: find.textContaining('+')),
            findsNothing,
            reason: 'width=$width n=$n',
          );
          if (fades == 0) {
            // 全部入る。
            expect(chips, n, reason: 'width=$width n=$n');
            previousFit = true;
          } else {
            sawCut = true;
            expect(fades, 1, reason: 'width=$width n=$n');
            expect(chips, lessThanOrEqualTo(n), reason: 'width=$width n=$n');
            final fade = find.byKey(ruleChipFadeKey);
            final inFade = find
                .descendant(of: fade, matching: find.byType(RuleSummaryChip))
                .evaluate()
                .length;
            final full = chips - inFade;
            // フェードしているのは、全体が見えているチップの次(`abcdef{full}`)。
            expect(
              find.descendant(of: fade, matching: find.text('abcdef$full')),
              findsOneWidget,
              reason: 'width=$width n=$n',
            );
            // **フェードは列の右端まで届き、空きを残さない**(2026-10-01 の開発者の
            // 指定。1つ手前をフェードにしたときに右へ空きが残り、消えるのが早く見えた)。
            expect(
              tester.getRect(fade).right,
              closeTo(tester.getRect(strip).right, 0.01),
              reason: 'width=$width n=$n',
            );
            // **フェードは下限より狭くならない**(狭いと途切れたチップだと読めない。
            // `008:T47` から引き受けた残余risk。`008:T10`)。
            expect(
              tester.getSize(fade).width,
              greaterThanOrEqualTo(ruleChipFadeMinWidth),
              reason: 'width=$width n=$n',
            );
            if (inFade == 2) sawNextPeek = true;
            if (previousFit) sawFadeRightAfterFit = true;
            previousFit = false;
          }
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // 前提: 入りきらなくなる経路を通っている。ちょうど収まっていたところへ
      // 1つ足したときにフェードが出ている(開発者が挙げた場面)。
      expect(sawCut, isTrue);
      expect(sawFadeRightAfterFit, isTrue);
      // 前提: 残りが下限に満たず1つ手前をフェードにした経路(次のチップの端が覗く)も
      // 通っている。
      expect(sawNextPeek, isTrue);
    });

    testWidgets('1つ目からフェードするときも、フェードは列の右端まで届く(008:T47 実機確認4回目)', (
      tester,
    ) async {
      // 1つ目のチップは入るが、その後ろの残りが下限に満たない幅。1つ目のチップの
      // 幅でフェードを止めると、右に空きが残って消えるのが早く見える。値は 132 で
      // 切れるのでチップの幅には上限があり、画面の幅を変えてその場面を通る。
      var sawFirstWithNext = false;
      for (var width = 240.0; width <= 360; width += 2) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(width),
            theme: appDarkTheme(),
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 800)),
              child: Scaffold(
                body: FileListView(
                  controller: FileListController(
                    files: [_f('a.txt')],
                    rule: RenameRule([
                      LiteralToken('a' * 40),
                      LiteralToken('b' * 20),
                    ]),
                  ),
                  onEditRule: () {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
        final strip = find.byKey(ruleSummaryKey);
        final fade = find.byKey(ruleChipFadeKey);
        if (fade.evaluate().isEmpty) continue;
        expect(
          tester.getRect(fade).right,
          closeTo(tester.getRect(strip).right, 0.01),
          reason: 'width=$width',
        );
        final inFade = find
            .descendant(of: fade, matching: find.byType(RuleSummaryChip))
            .evaluate()
            .length;
        final all = find
            .descendant(of: strip, matching: find.byType(RuleSummaryChip))
            .evaluate()
            .length;
        if (inFade == 2 && all == 2) sawFirstWithNext = true;
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
      expect(sawFirstWithNext, isTrue, reason: '1つ目からフェードする経路を通っていない');
    });

    test('フェードで薄くするのは右端の決まった長さだけ(008:T47 実機確認4回目)', () {
      // 2026-10-01 の開発者の指定: 薄くし始めるのが早い。以前は幅の 35% からだった。
      for (final width in [24.0, 60.0, 140.0]) {
        expect(
          width * (1 - ruleChipFadeStart(width)),
          closeTo(ruleChipFadeLength, 0.001),
          reason: 'width=$width',
        );
      }
      // 長さより狭いフェードは全体を薄くする。
      expect(ruleChipFadeStart(10), 0);
    });

    testWidgets('チップの列の高さは、1つ目のチップからフェードしても変わらない(008:T47)', (tester) async {
      // 列が中身の高さのままだと、狭幅・文字の拡大で button の高さが変わり、一覧の
      // 高さが変わる(以前の「+N」だけの形で実際に起きた)。
      Future<double> stripHeight(RenameRule rule, double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('${rule.tokens.length}-$scale'),
            theme: appDarkTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: FileListView(
                  controller: FileListController(
                    files: [_f('a.txt')],
                    rule: rule,
                  ),
                  onEditRule: () {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        return tester.getSize(find.byKey(ruleSummaryKey)).height;
      }

      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scale in [1.0, 2.0]) {
        const one = RenameRule([SequenceToken(start: 100, digits: 1)]);
        final withChip = await stripHeight(one, scale);
        // チップ自体の高さと一致する(高さの計算がずれていない)。
        expect(
          withChip,
          tester.getSize(find.byType(RuleSummaryChip)).height,
          reason: 'scale=$scale',
        );
        final onlyFade = await stripHeight(
          RenameRule([
            for (var i = 0; i < 6; i++) LiteralToken('とても長い固定文字とても長い固定文字$i'),
          ]),
          scale,
        );
        expect(find.byKey(ruleChipFadeKey), findsOneWidget);
        expect(onlyFade, withChip, reason: 'scale=$scale');
      }
    });

    testWidgets('「命名ルール」とチップの間を空け、上下の余白を詰める(008:T47 実機確認)', (tester) async {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pumpNarrow(tester, c);

      final frame = tester.getRect(find.byKey(ruleButtonFrameKey));
      final heading = tester.getRect(find.text('命名ルール'));
      final strip = tester.getRect(find.byKey(ruleSummaryKey));
      // 見出しとチップの間は、上の余白(枠 1 + 内側の余白)より広くはないが 7 ある。
      expect(strip.top - heading.bottom, ruleButtonHeadingGap);
      expect(heading.top - frame.top, 1 + ruleButtonVerticalPadding);
      expect(ruleButtonHeadingGap, greaterThan(4), reason: '以前の間(4)より広い');
      expect(ruleButtonVerticalPadding, lessThan(11), reason: '以前の上下(11)より詰める');
      // 左右は変えない(12)。
      expect(
        tester.getRect(find.byType(RuleSummaryChip)).left,
        greaterThan(frame.left + 12),
      );
    });

    testWidgets('未設定のbuttonは設定済みよりひとまわり小さいくらいの高さ(008:T47 実機確認5回目)', (
      tester,
    ) async {
      // 2026-10-01 の開発者の指定: 未設定は文字の高さだけで、設定済みの半分以下に
      // 見えていた。小さすぎず、設定済みを超えない(文字の拡大でも同じ関係)。
      Future<double> height(RenameRule rule, double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('${rule.tokens.length}-$scale'),
            theme: appDarkTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: FileListView(
                  controller: FileListController(
                    files: [_f('a.txt')],
                    rule: rule,
                  ),
                  onEditRule: () {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        return tester.getSize(find.byKey(_ruleButtonKey)).height;
      }

      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scale in [1.0, 2.0]) {
        final empty = await height(const RenameRule([]), scale);
        final set = await height(
          const RenameRule([OriginalNameToken()]),
          scale,
        );
        expect(empty, lessThan(set), reason: 'scale=$scale');
        expect(empty, greaterThanOrEqualTo(set * 0.8), reason: 'scale=$scale');
      }
    });

    testWidgets('未設定と設定済みでbuttonの外形が同じ。未設定は＋と文言だけを白で出す(008:T47)', (
      tester,
    ) async {
      BoxDecoration frameOf() =>
          tester.widget<Container>(find.byKey(ruleButtonFrameKey)).decoration!
              as BoxDecoration;
      final c = FileListController(files: [_f('a.txt')]);
      await _pumpNarrow(tester, c);

      final emptyFrame = frameOf();
      final emptyMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(_ruleButtonKey),
              matching: find.byType(Material),
            )
            .first,
      );
      final label = tester.widget<Text>(find.text('命名ルールを設定する'));
      expect(label.style!.color, Colors.white);
      final plus = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(_ruleButtonKey),
          matching: find.byIcon(Icons.add),
        ),
      );
      expect(plus.color, Colors.white);
      // ✎・見出し・`編集` は出さない。
      expect(find.byKey(ruleEditChipKey), findsNothing);
      expect(find.text('命名ルール'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(_ruleButtonKey),
          matching: find.byIcon(Icons.edit),
        ),
        findsNothing,
      );
      // 塗りの button ではない。
      expect(find.byType(FilledButton), findsNothing);

      c.setRule(const RenameRule([OriginalNameToken()]));
      await tester.pump();
      final setFrame = frameOf();
      final setMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(_ruleButtonKey),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(emptyFrame.border, setFrame.border);
      expect(emptyFrame.borderRadius, setFrame.borderRadius);
      expect(emptyMaterial.color, setMaterial.color);
      expect(emptyMaterial.borderRadius, setMaterial.borderRadius);
    });

    testWidgets('リネームbuttonの角丸はルール設定buttonと同じ(008:T47)', (tester) async {
      final w = _wire([_f('a.txt')], const RenameRule([LiteralToken('b')]));
      await _pumpNarrow(tester, w.files, execution: w.execution);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('rename-action')),
      );
      final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(ruleButtonRadius));
      final frame =
          tester.widget<Container>(find.byKey(ruleButtonFrameKey)).decoration!
              as BoxDecoration;
      expect(frame.borderRadius, BorderRadius.circular(ruleButtonRadius));
      w.execution.dispose();
    });

    testWidgets('狭幅・文字 2.0 でもはみ出さない(008:T47)', (tester) async {
      for (final width in [320.0, 360.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final rule in [
          RenameRule.empty,
          const RenameRule([
            OriginalNameToken(),
            LiteralToken('_'),
            SequenceToken(start: 1, digits: 3),
            DateTimeToken(source: DateTimeSource.modified, format: 'YYYYMMDD'),
          ]),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$width-${rule.tokens.length}'),
              theme: appDarkTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: FileListView(
                    controller: FileListController(
                      files: [_f('a.txt')],
                      rule: rule,
                    ),
                    onEditRule: () {},
                  ),
                ),
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '幅 $width・トークン ${rule.tokens.length}',
          );
        }
      }
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
