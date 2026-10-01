// VER-005(続き): 行の結果表示(FEAT-005 / Strict)。008:T18。
// 対象: REQ-029(変更が生じないファイルは「名前は変わらない」ことが読める)と、
//       REQ-009 (1) を色でも読めるようにした部分。
//
// **判定は 001 のまま。** ここが検査するのは提示だけである。
//
// 検査の主眼は次の4つ。いずれも**両方向**(そうである / そうでない)を固定する。
//
// 1. 変更が生じない行は、生成後名の代わりに「変更なし」が読める(REQ-029)
// 2. 空のルールの生成後名(`.jpg` のような拡張子だけの名前)を出さない(REQ-029)
// 3. 変更後名の色が、警告のある行と無い行で分かれる(2026-09-02 の要望7)
// 4. 行の警告が**現在名の上**にあり、切り詰められない(2026-09-02 の要望8)
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/file_list/row_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2024, 3, 4, 5, 6),
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
);

FileEntry _noCreatedAt(String name) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 8, 4, 16), size: 0);

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

/// 変更後名の色を読む。**その行の色そのものを見る** — 「赤くない」ではなく
/// 「success である / danger である」を固定する。
Color _newNameColor(WidgetTester tester, {int at = 0}) => tester
    .widgetList<Text>(find.byKey(rowNewNameKey))
    .elementAt(at)
    .style!
    .color!;

AppColors _colors(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(FileListView))).extension<AppColors>()!;

void main() {
  group('REQ-029: 変更が生じない行は「名前は変わらない」ことが読める', () {
    testWidgets('空のルールでは、拡張子だけの名前ではなく「変更なし」が出る', (tester) async {
      // 空のルールの `generatePreview` は `.jpg` を返すが、REQ-019 により
      // その名前が実体に付くことはない。**そのまま出す実装を排除する。**
      final c = FileListController(files: [_f('photo.jpg')]);
      await _pump(tester, c);

      expect(c.rows.single.newName, '.jpg', reason: '行データ側は 001 のまま');
      expect(find.byKey(rowUnchangedKey), findsOneWidget);
      expect(find.text(unchangedLabel), findsOneWidget);
      expect(find.byKey(rowNewNameKey), findsNothing);
      expect(find.text('.jpg'), findsNothing);
    });

    testWidgets('元の名前だけのルールでも「変更なし」が出る', (tester) async {
      final c = FileListController(
        files: [_f('photo.jpg')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pump(tester, c);

      expect(c.rows.single.newName, 'photo.jpg');
      expect(find.byKey(rowUnchangedKey), findsOneWidget);
    });

    testWidgets('名前が変わる行では「変更なし」を出さない(逆方向)', (tester) async {
      final c = FileListController(
        files: [_f('photo.jpg')],
        rule: const RenameRule([LiteralToken('renamed')]),
      );
      await _pump(tester, c);

      expect(find.byKey(rowUnchangedKey), findsNothing);
      expect(find.text('renamed.jpg'), findsOneWidget);
    });

    testWidgets('変わる行と変わらない行が混ざっても、行ごとに読める', (tester) async {
      // `keep.txt` は元名のまま、`other.txt` は `keep.txt` へは変わらない。
      // 固定文字 + 元名では両方変わるので、**元名だけ**のルールで片方の名前を
      // 一致させる形にはできない。代わりに、片方だけ選択を外して混在を作る。
      final files = [_f('a.jpg'), _f('b.jpg')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([OriginalNameToken(), LiteralToken('!')]),
      );
      await _pump(tester, c);

      // どちらも変わるので「変更なし」は出ない。
      expect(find.byKey(rowUnchangedKey), findsNothing);
      expect(find.byKey(rowNewNameKey), findsNWidgets(2));

      // ルールを元名だけへ替えると、両方とも変わらなくなる。
      c.setRule(const RenameRule([OriginalNameToken()]));
      await tester.pump();
      expect(find.byKey(rowUnchangedKey), findsNWidgets(2));
      expect(find.byKey(rowNewNameKey), findsNothing);
    });

    testWidgets('空名で改名されない行も「変更なし」になる(REQ-022 の除外)', (tester) async {
      final c = FileListController(
        files: [_f('only.txt')],
        rule: const RenameRule([LiteralToken('')]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<EmptyNameWarning>().length, 1);
      expect(find.byKey(rowUnchangedKey), findsOneWidget);
      // 行の警告は残る(なぜ変わらないかは警告が言う)。
      expect(find.byKey(rowWarningKey), findsOneWidget);
    });

    test('未選択行は `rowHasNoChange` が偽である(プレビュー対象外)', () {
      // widget 側は `newName == null` を先に見て「—」を出すので、この分岐は
      // widget test では踏めない。**判定そのものをここで押さえる**
      // (M212 がこの空振りを殺す)。
      final c = FileListController(
        files: [_f('a.jpg')],
        rule: const RenameRule([LiteralToken('renamed')]),
      );
      c.clearAll();
      final row = c.rows.single;

      expect(row.newName, isNull);
      expect(rowHasNoChange(row, ruleIsEmpty: false), isFalse);
      expect(
        rowHasNoChange(row, ruleIsEmpty: true),
        isFalse,
        reason: 'ルールが空でも、未選択行は「変わらない」ではない',
      );
    });

    testWidgets('未選択行は「変更なし」ではない(プレビュー対象外)', (tester) async {
      // 選べば変わりうるので、「変わらない」と読ませない(002 REQ-007)。
      final files = [_f('a.jpg')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([LiteralToken('renamed')]),
      );
      c.clearAll();
      await _pump(tester, c);

      expect(find.byKey(rowUnchangedKey), findsNothing);
      expect(find.byKey(rowNewNameKey), findsNothing);
    });

    testWidgets('「変更なし」は強調色を使わない', (tester) async {
      final c = FileListController(files: [_f('photo.jpg')]);
      await _pump(tester, c);
      final colors = _colors(tester);
      final style = tester.widget<Text>(find.byKey(rowUnchangedKey)).style!;

      expect(style.color, colors.textMuted);
      // 参考designも `（変更なし）` を弱い色で置いている。
      expect(style.color, isNot(colors.primary));
      expect(style.color, isNot(colors.success));
      expect(style.color, isNot(colors.danger));
    });
  });

  group('要望7: 変更後名の色が、警告のある行と無い行で分かれる', () {
    testWidgets('警告の無い行の変更後名は success', (tester) async {
      final c = FileListController(
        files: [_f('a.jpg')],
        rule: const RenameRule([LiteralToken('renamed')]),
      );
      await _pump(tester, c);

      expect(c.warnings, isEmpty);
      expect(_newNameColor(tester), _colors(tester).success);
    });

    testWidgets('警告のある行の変更後名は danger', (tester) async {
      final c = FileListController(
        files: [_f('a.jpg'), _f('b.jpg')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<DuplicateWarning>().length, 2);
      final colors = _colors(tester);
      expect(_newNameColor(tester, at: 0), colors.danger);
      expect(_newNameColor(tester, at: 1), colors.danger);
    });

    testWidgets('同じ一覧の中で、警告のある行と無い行の色が分かれる', (tester) async {
      // 拡張子が同じ 2 件だけが重複する。**3 件とも名前は変わる**ので、
      // どの行も「変更なし」ではなく変更後名を出す。
      final c = FileListController(
        files: [_f('a.txt'), _f('b.txt'), _f('c.jpg')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);
      final colors = _colors(tester);

      expect(c.warnings.whereType<DuplicateWarning>().length, 2);
      expect(find.byKey(rowNewNameKey), findsNWidgets(3));
      expect(_newNameColor(tester, at: 0), colors.danger);
      expect(_newNameColor(tester, at: 1), colors.danger);
      expect(
        _newNameColor(tester, at: 2),
        colors.success,
        reason: '拡張子が違う 1 件は重複しないので正常色のままである',
      );
    });

    testWidgets('作成日時が不明で名前が変わらない行は「変更なし」側へ回る', (tester) async {
      // `[元の名前][作成日時]` で作成日時が取れないと、生成後名は元名と同じに
      // なる。**警告は出るが名前は変わらない**ので、色ではなく REQ-029 の
      // 提示が担当する。**危険色の変更後名を出さない。**
      final c = FileListController(
        files: [_f('dated.jpg'), _noCreatedAt('nodate.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        ]),
      );
      await _pump(tester, c);

      expect(c.rows[1].newName, 'nodate.jpg');
      expect(_newNameColor(tester), _colors(tester).success);
      expect(find.byKey(rowUnchangedKey), findsOneWidget);
      // 警告そのものは残る(なぜ変わらないかは警告が言う)。
      expect(find.byKey(rowWarningKey), findsOneWidget);
    });

    testWidgets('桁不足で警告が出た行も danger になる', (tester) async {
      // 008:T17 の改訂で桁不足が行へ来るので、色にも効く。
      final c = FileListController(
        files: [_f('a.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );
      await _pump(tester, c);

      expect(_newNameColor(tester), _colors(tester).danger);
    });
  });

  group('008:T50 行の警告は現在名と同じ行の右端にある(以前は 要望8: 現在名の上の行)', () {
    testWidgets('警告は現在名と同じ行にあり、現在名の右に置かれる', (tester) async {
      // 2026-10-01 の開発者の決定(`008:T50`): 「わざわざ1行を警告に使ううえに、
      // 警告が見づらい」→ 変更前の名前の行の右端(つまみの左)に置く。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      final warning = tester.getRect(find.byKey(rowWarningKey).first);
      final current = tester.getRect(find.byKey(rowCurrentNameKey).first);
      // 同じ行: 縦の範囲が重なる(上の行にも下の行にも無い)。
      expect(warning.top, lessThan(current.bottom), reason: '警告が現在名より下の行にある');
      expect(
        warning.bottom,
        greaterThan(current.top),
        reason: '警告が現在名より上の行にある',
      );
      // 現在名の右: 現在名は残りの幅を取り、警告はその右に置かれる。
      expect(
        warning.left,
        greaterThanOrEqualTo(current.right),
        reason: '警告が現在名の右に無い',
      );
      // 変更後名(矢印の行)の右端より右へはみ出さない = 行の右端に揃う。
      final arrowRow = tester.getRect(
        find
            .ancestor(
              of: find.byKey(rowNewNameKey).first,
              matching: find.byType(Row),
            )
            .first,
      );
      expect(warning.right, closeTo(arrowRow.right, 0.5), reason: '警告が行の右端に無い');
    });

    testWidgets('警告のある行も、増えるのは1行より少ない(専用の行を取らない)', (tester) async {
      // 以前は警告のある行だけ1行ぶん高かった。**同じ行へ載せたので、差は警告の
      // 押せる範囲(上下の余白 4)が現在名の行より高いぶんだけ**である。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt'), _f('charlie.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pump(tester, c);
      double rowOf(String name) {
        final row = find
            .ancestor(of: find.text(name), matching: find.byType(Container))
            .evaluate()
            .firstWhere((e) {
              final decoration = (e.widget as Container).decoration;
              return decoration is BoxDecoration &&
                  decoration.border is Border &&
                  (decoration.border! as Border).bottom.color ==
                      AppColors.dark.rowDivider;
            });
        return tester.getSize(find.byWidget(row.widget)).height;
      }

      final plain = rowOf('alpha.txt');
      expect(find.byKey(rowWarningKey), findsNothing);
      // 2 行だけ同じ名前にして警告を出す。
      c.setRule(const RenameRule([LiteralToken('same')]));
      await tester.pump();
      expect(find.byKey(rowWarningKey), findsWidgets);
      final warned = rowOf('alpha.txt');
      final nameLine = tester
          .getSize(find.byKey(rowCurrentNameKey).first)
          .height;
      expect(warned - plain, lessThan(nameLine), reason: '警告が専用の1行を取っている');
    });

    testWidgets('警告のアイコンが文字のbaselineへ揃っている', (tester) async {
      // 2026-09-03 のmanual確認: 「！マークが警告文に対して少し上にずれている」。
      // `CrossAxisAlignment.start` だと箱の上端が揃い、字面の中心が下にある
      // 文字に対してアイコンが浮く。**アイコンの縦中心が、文字の1行目の縦の
      // 範囲の中に入っていること**を固定する。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      final icon = tester.getRect(
        find
            .descendant(
              of: find.byKey(rowWarningKey).first,
              matching: find.byType(Icon),
            )
            .first,
      );
      final text = tester.getRect(
        find
            .descendant(
              of: find.byKey(rowWarningKey).first,
              matching: find.byType(Text),
            )
            .first,
      );
      // **アイコンは、文字の box の中心より少し下**にある。box を揃えると
      // **字面(ink)がずれる**ためで、2026-09-04 のmanual確認で「まだわずかに
      // ！が上にずれて見える」と観測された(005 REQ-009 (1) の可読性ではなく
      // 見た目の揃いの問題)。
      //
      // - Material icons は baseline の上 1em を占める → ink 中心は baseline − 0.5em
      // - CJKの字面は baseline の上 0.88em 〜 下 0.12em → ink 中心は baseline − 0.38em
      //
      // 差 0.12em ぶん下げているので、**box の中心は文字より下**になる。
      // **上端揃え(M222)では逆に上へ浮く**ので、向きごと固定する。
      final gap = icon.center.dy - text.center.dy;
      expect(gap, greaterThan(0.5), reason: 'アイコンが文字の字面より上へ浮いている');
      expect(gap, lessThan(2.5), reason: 'アイコンを下げすぎている');
    });

    testWidgets('警告は押せると分かる形(太字・下線)で、変更後名より薄い', (tester) async {
      // 2026-09-03 のmanual確認: 「ぱっと見だと押せることが分からず、ただの
      // 警告文に見える」「変更後名の表示の赤と同じ濃さなので、目が散る」。
      // `008:T50` で枠と塗りの箱をやめ、**太字・下線**で押せることを示す
      // (2026-10-01 の開発者の案「警告マークと『詳細』(太字・下線)」)。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);
      final colors = _colors(tester);

      final style = tester
          .widget<Text>(find.byKey(rowWarningBadgeTextKey).first)
          .style!;
      expect(style.fontWeight, FontWeight.w700, reason: '太字でない');
      // **下線は文字の装飾ではなく、文字の枠の下に引いた線**(2026-10-01 の実機確認
      // 1回目「下線が見えづらい。ヘッダー付近の『詳細』の下線の引き方を参考に」)。
      // 件数表示の「詳細」と同じ太さ。文字の装飾の下線は重ねない(二重になる)。
      expect(style.decoration, isNot(TextDecoration.underline));
      final underline = tester.widget<Container>(
        find.byKey(rowWarningUnderlineKey).first,
      );
      final bottom =
          ((underline.decoration! as BoxDecoration).border! as Border).bottom;
      expect(bottom.width, warningLinkUnderlineWidth, reason: '下線が細い');
      expect(warningLinkUnderlineWidth, greaterThanOrEqualTo(1.5));
      expect(bottom.color, style.color, reason: '下線が文字と違う色');
      // 線は文字の下にある(文字の枠の下端に接して引く)。
      final lineBox = tester.getRect(find.byKey(rowWarningUnderlineKey).first);
      final textBox = tester.getRect(find.byKey(rowWarningBadgeTextKey).first);
      expect(lineBox.bottom, greaterThanOrEqualTo(textBox.bottom));

      // 文字は danger と同じ色相で、**変更後名より薄い**。
      final label = style.color!;
      expect(
        (label.r, label.g, label.b),
        (colors.danger.r, colors.danger.g, colors.danger.b),
      );
      expect(
        label.a,
        lessThan(_newNameColor(tester).a),
        reason: '警告が変更後名と同じ濃さで、目が散る',
      );
    });

    testWidgets('種別が 3 つ併発しても、狭幅で切り詰められない', (tester) async {
      // 008:T17 の改訂で、行に出る種別は最大 3 つになった
      // (重複・作成日時不明・連番の桁不足)。**切り詰めると種別が読めなくなる。**
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = FileListController(
        files: [_noCreatedAt('alpha.jpg'), _noCreatedAt('bravo.jpg')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          SequenceToken(start: 100, digits: 1, increment: 0),
        ]),
      );
      await _pump(tester, c);

      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(rowWarningKey),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text, contains(duplicateKindLabel));
        expect(text, contains(digitShortageKindLabel));
        // 作成日時不明は右端に書かず、補足情報の赤字で読む(`008:T50`)。
        expect(text, isNot(contains('作成日時')));
      }
      final createdAt = tester.widgetList<Text>(find.byKey(rowCreatedAtKey));
      expect(createdAt, hasLength(2));
      for (final t in createdAt) {
        expect(t.style?.color, AppColors.dark.danger);
      }
      for (final element
          in find
              .descendant(
                of: find.byKey(rowWarningKey),
                matching: find.byType(Text),
              )
              .evaluate()) {
        expect(
          (element.renderObject! as RenderParagraph).didExceedMaxLines,
          isFalse,
          reason: '併発した種別が切り詰められている',
        );
      }
    });

    testWidgets('狭幅でも広幅でも、行の結果と警告が読める', (tester) async {
      // **片方だけ通しても、もう片方の抜けは検出できない**(008:T07 の M166/M167、
      // 008:T16 の M177 と同じ型)。広幅は 2 ペインで、行は左ペインにある。
      for (final size in [const Size(400, 800), const Size(1200, 800)]) {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final rule = RuleController()..addToken(const LiteralToken('same'));
        addTearDown(rule.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(
                fileList: FileListController(
                  files: [_f('alpha.txt'), _f('bravo.txt')],
                ),
                rule: rule,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(rowWarningKey),
          findsNWidgets(2),
          reason: '幅 ${size.width} で行の警告が出ていない',
        );
        final colors = Theme.of(
          tester.element(find.byType(RuleBuilderWorkspace)),
        ).extension<AppColors>()!;
        expect(
          tester.widgetList<Text>(find.byKey(rowNewNameKey)).first.style!.color,
          colors.danger,
          reason: '幅 ${size.width} で警告のある行が danger になっていない',
        );
        // 切り詰めも両方の幅で見る(狭幅だけでは広幅の抜けを検出できない)。
        for (final element
            in find
                .descendant(
                  of: find.byKey(rowWarningKey),
                  matching: find.byType(Text),
                )
                .evaluate()) {
          expect(
            (element.renderObject! as RenderParagraph).didExceedMaxLines,
            isFalse,
            reason: '幅 ${size.width} で行の警告が切り詰められている',
          );
        }
      }
    });

    testWidgets('狭幅でも広幅でも「変更なし」が出る', (tester) async {
      // REQ-029 も両方の幅で見る。広幅は 2 ペインで、行は左ペインにある。
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
                fileList: FileListController(files: [_f('photo.jpg')]),
                rule: rule,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(rowUnchangedKey),
          findsOneWidget,
          reason: '幅 ${size.width} で「変更なし」が出ていない',
        );
        expect(find.byKey(rowNewNameKey), findsNothing);
      }
    });
  });
  group('008:T10 行の警告の文字倍率・高さ・濃さ(`008:T18` から引き受けた残余risk)', () {
    /// 種別が 3 つ併発する行(重複・作成日時不明・連番の桁不足)。
    FileListController threeKinds({String first = 'alpha.jpg'}) =>
        FileListController(
          files: [_noCreatedAt(first), _noCreatedAt('bravo.jpg')],
          rule: const RenameRule([
            DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
            SequenceToken(start: 100, digits: 1, increment: 0),
          ]),
        );

    Future<void> pumpScaled(
      WidgetTester tester,
      FileListController c,
      double width,
      double scale,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('$width-$scale-${c.hashCode}'),
          theme: appDarkTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(body: FileListView(controller: c)),
          ),
        ),
      );
    }

    Finder warningText() => find
        .descendant(
          of: find.byKey(rowWarningKey).first,
          matching: find.byType(Text),
        )
        .first;

    testWidgets('文字を大きくしても、併発した種別が切り詰められない', (tester) async {
      // `008:T18` の確認C(フォントサイズ最大)が未回答のまま引き受けた。2 行までだと
      // 倍率 2.0 の 320・360dp で切り詰められた(2026-10-01 の測定)。
      for (final width in [320.0, 360.0, 411.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          await pumpScaled(tester, threeKinds(), width, scale);
          expect(tester.takeException(), isNull);
          expect(
            tester
                .renderObject<RenderParagraph>(warningText())
                .didExceedMaxLines,
            isFalse,
            reason: '幅 $width / 文字 $scale で種別が切り詰められている',
          );
        }
      }
    });

    testWidgets('警告のアイコンは文字の倍率に合わせて拡大し、文字との位置関係を保つ', (tester) async {
      // 以前は [Icon] が倍率で拡大せず、補正量も定数だったので、倍率を上げるほど
      // アイコンが上へずれた(実測 gap = 1.18 / 2.37 / 4.30 / 6.91px)。test の字体は
      // 実機の CJK と字面が違うので、**ずれが文字の大きさに比例していること**を見る
      // (実機の揃いは manual 確認で見る)。
      double? baseRatio;
      for (final scale in [1.0, 1.3, 2.0]) {
        await pumpScaled(tester, threeKinds(), 411, scale);
        final fontSize = scale * rowWarningFontSize;
        final icon = tester.getRect(
          find.descendant(
            of: find.byKey(rowWarningKey).first,
            matching: find.byType(Icon),
          ),
        );
        expect(icon.height, closeTo(fontSize, 0.01), reason: '文字 $scale');
        final text = tester.getRect(warningText());
        final paragraph = tester.renderObject<RenderParagraph>(warningText());
        final baseline =
            text.top +
            paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        final ratio = (icon.center.dy - baseline) / fontSize;
        baseRatio ??= ratio;
        expect(ratio, closeTo(baseRatio, 0.03), reason: '文字 $scale');
      }
    });

    testWidgets('行の高さは、現在名の長さでも警告の余白でも伸びない', (tester) async {
      // `008:T18` の残余risk(M220 / M221): 行の高さを縛る assertion が無かった。
      // 現在名は 1 行で切り、警告は「文字 + 上下の余白 4 + 下線」の高さである。
      /// 行そのもの(下に行の区切り線を持つ箱)の高さ。
      double rowOf(String name) {
        final row = find
            .ancestor(of: find.text(name), matching: find.byType(Container))
            .evaluate()
            .firstWhere((e) {
              final decoration = (e.widget as Container).decoration;
              return decoration is BoxDecoration &&
                  decoration.border is Border &&
                  (decoration.border! as Border).bottom.color ==
                      AppColors.dark.rowDivider;
            });
        return tester.getSize(find.byWidget(row.widget)).height;
      }

      await pumpScaled(tester, threeKinds(), 411, 1);
      final short = rowOf('alpha.jpg');
      final box = tester.getSize(find.byKey(rowWarningKey).first).height;
      final text = tester.getSize(warningText()).height;
      // `008:T50` で枠線をやめたので、上下の余白 4 と、文字の下に引いた下線の太さ
      // (2026-10-01 の実機確認1回目で、件数表示の「詳細」と同じ引き方へ変えた)。
      expect(box, closeTo(text + 2 * 4 + warningLinkUnderlineWidth, 0.01));

      final longName = '${'とても長い現在の名前' * 6}.jpg';
      await pumpScaled(tester, threeKinds(first: longName), 411, 1);
      expect(rowOf(longName), short, reason: '長い現在名で行が伸びている');
    });

    test('警告の文字の濃さには下限がある', () {
      // `008:T18` の穴A(M225): 相対条件(変更後名より薄い)だけでは、読めないほど
      // 薄くしても通った。下限は 2026-09-03 の manual 確認で開発者が見た値(0.78)と
      // 参考design(.7)から置いた。**枠と塗りの下限(穴B・M226)は `008:T50` で箱を
      // やめたので外した**(押せる形は太字・下線の test が見る)。
      expect(rowWarningLabelOpacity, greaterThanOrEqualTo(0.6));
    });
  });
}
