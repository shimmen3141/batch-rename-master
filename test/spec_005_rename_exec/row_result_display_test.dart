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

  group('要望8: 行の警告は現在名の上にある', () {
    testWidgets('警告の縦位置が現在名より上で、右へ寄っている', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      // 警告の箱は**中身の幅しか取らない**(2026-09-03 にボタンらしい形へ変えた)。
      // したがって箱の位置そのものが右寄せの有無を表す。
      final warning = tester.getRect(find.byKey(rowWarningKey).first);
      final current = tester.getRect(find.text('alpha.txt'));
      expect(
        warning.bottom,
        lessThanOrEqualTo(current.top),
        reason: '警告が現在名の上に無い',
      );
      // 右寄せ: 箱の右端が、現在名の右端と同じかそれより右にある。
      expect(
        warning.right,
        greaterThanOrEqualTo(current.right - 1),
        reason: '警告が右へ寄っていない',
      );
      // **行幅いっぱいに広がっていない**ことも固定する。広がっていると、
      // 左寄せへ変えても右端が動かず、右寄せの検査が空振りになる。
      expect(
        warning.left,
        greaterThan(current.left + 1),
        reason: '警告の箱が左端から始まっている',
      );
      // 文字は箱の中に収まっている。
      final warningText = tester.getRect(
        find
            .descendant(
              of: find.byKey(rowWarningKey).first,
              matching: find.byType(Text),
            )
            .first,
      );
      expect(warning.contains(warningText.topLeft), isTrue);
      expect(
        warning.contains(warningText.bottomRight - const Offset(1, 1)),
        isTrue,
      );
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
      // **縦中心どうしが一致すること**を見る。`text.top`〜`text.bottom` の間に
      // 入っているだけでは弱い — 箱の上端で揃える実装(浮いて見える形)でも
      // その範囲には収まるので、検査が空振りする(M222 がこれを殺す)。
      //
      // 実測: baseline 揃えでは差が 0.14px、`CrossAxisAlignment.start` では
      // 2.5px ずれる(アイコン 11px に対して文字の行は 16px)。
      expect(
        (icon.center.dy - text.center.dy).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'アイコンの縦中心が文字の縦中心とずれている',
      );
    });

    testWidgets('警告は押せると分かる形で、変更後名より薄い', (tester) async {
      // 2026-09-03 のmanual確認: 「ぱっと見だと押せることが分からず、ただの
      // 警告文に見える」「変更後名の表示の赤と同じ濃さなので、目が散る」。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);
      final colors = _colors(tester);

      // 枠と塗りが在る(ただの文字ではない)。
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(rowWarningKey).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull, reason: '枠が無い');
      expect(decoration.borderRadius, isNotNull, reason: '角が丸くない');
      expect(decoration.color!.a, greaterThan(0), reason: '塗りが無い');
      expect(decoration.color!.a, lessThan(1), reason: '塗りが濃すぎる');

      // 文字は danger と同じ色相で、**変更後名より薄い**。
      final label = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(rowWarningKey).first,
              matching: find.byType(Text),
            ),
          )
          .first
          .style!
          .color!;
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
        expect(text, contains('重複'));
        expect(text, contains('作成日時不明'));
        expect(text, contains('連番の桁不足'));
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
}
