// VER-005: 001 の検証警告のプレビュー上での提示(FEAT-005 / Strict)。
// 対象: REQ-009(警告 4 種すべてを提示し、対象ファイルを持つものは識別できる形にする)
//       REQ-010(警告 0 件のときは提示しない)。
//
// 判定は 001 の validate が持ち、005 は表示だけを担う(契約 terms の「警告」)ので、
// ここでは「001 が返した警告が画面上で読み取れるか」だけを見る。
//
// **revision 8.0 で、要求は場所ではなく「利用者から何が読めるか」になった。**
// (1) 各ファイルの警告の**種別**が、一覧を見た状態で(展開操作を経ずに)分かる
// (2) ファイルによって変わらない説明は、該当件数ぶん繰り返さない
// (3) 全件と説明を読める提示がある
// したがってこのfileは**どのwidgetに出ているか**ではなく、上の3つを検査する。
// 008:T16 以前は一覧上部の集約帯1か所に全件を並べており、その構造を検査していた。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 作成日時が判明しているファイル。
FileEntry _f(String name, {String? location}) => FileEntry(
  name: name,
  createdAt: DateTime(2024, 3, 4, 5, 6),
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceLocation: location,
);

/// 作成日時が不明なファイル(004 の実データは常にこちら)。
FileEntry _noCreatedAt(String name) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 8, 4, 16), size: 0);

/// 行に出ている警告(005 REQ-009 (1))。**展開操作を経ずに見えているもの。**
Finder _rowWarnings() => find.byKey(rowWarningKey);

/// ルールを直せば消える原因の説明(005 REQ-009 (2))。
Finder _ruleNotice() => find.byKey(ruleWarningNoticeKey);

Finder _inRuleNotice(Finder matching) =>
    find.descendant(of: _ruleNotice(), matching: matching);

/// 全件の詳細(005 REQ-009 (3))。
Finder _detail() => find.byKey(warningDetailDialogKey);

Finder _inDetail(Finder matching) =>
    find.descendant(of: _detail(), matching: matching);

/// 詳細dialogの中の「原因ごとの説明」節だけ(005 REQ-009 (2))。
/// **ファイルごとの全件と混ぜて数えない** — 全件側は件数ぶん並んでよい。
Finder _inCauses(Finder matching) =>
    find.descendant(of: find.byKey(warningDetailCausesKey), matching: matching);

/// 詳細dialogの中の「ファイルごとの全件」節だけ(005 REQ-009 (3))。
Finder _inFiles(Finder matching) =>
    find.descendant(of: find.byKey(warningDetailFilesKey), matching: matching);

/// 行に見えている警告の文言(順序は表示順)。
List<String> _rowWarningTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: _rowWarnings(), matching: find.byType(Text)),
    )
    .map((text) => text.data ?? '')
    .toList();

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

/// 一覧全体の件数表示から詳細を開く。
Future<void> _openDetailFromCount(WidgetTester tester) async {
  await tester.tap(find.byKey(warningCountKey));
  await tester.pumpAndSettle();
}

void main() {
  group('REQ-009 (1): 各ファイルの警告の種別が、展開操作を経ずに読める', () {
    testWidgets('重複: 対象の 2 行それぞれで「重複」と読める', (tester) async {
      // 2 件とも同じ固定文字になるので、双方が重複警告の対象になる。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<DuplicateWarning>().length, 2);
      // **タップも展開もしていない状態で**、2 行それぞれに種別が出ている。
      expect(_rowWarnings(), findsNWidgets(2));
      expect(_rowWarningTexts(tester), ['名前が重複', '名前が重複']);
    });

    testWidgets('空名: 結果を 2 つ示す(空になる / 改名されない)', (tester) async {
      // 空リテラル1個 = ベース名が空になるが、ルール自体は未設定ではない。
      final c = FileListController(
        files: [_f('only.txt')],
        rule: const RenameRule([LiteralToken('')]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<EmptyNameWarning>().length, 1);
      final text = _rowWarningTexts(tester).single;
      // (i) 名前が空になること。
      expect(text, contains('空'));
      // (ii) そのファイルが改名の対象にならないこと(REQ-021 規則1)。
      // **(ii) は (i) の言い換えではない** — (i) だけでは「空の名前へ改名される」
      // とも読める。
      expect(text, contains('改名されません'));
    });

    testWidgets('基準日時不明: 対象の行だけに出る(名前は空にならない経路)', (tester) async {
      // 1 件は作成日時が不明、1 件は判明。元名トークンがあるので名前は空にならず、
      // REQ-021 規則1 は適用されない(005 例20g の経路)。
      final c = FileListController(
        files: [_f('dated.jpg'), _noCreatedAt('nodate.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      await _pump(tester, c);

      final missing = c.warnings.whereType<MissingSourceDateWarning>().toList();
      expect(missing.single.file.name, 'nodate.jpg');
      expect(c.warnings.whereType<EmptyNameWarning>(), isEmpty);

      // **作成日時が判明している行は巻き込まない。**
      expect(_rowWarnings(), findsOneWidget);
      expect(_rowWarningTexts(tester).single, contains('作成日時'));
    });

    testWidgets('桁不足はどの行にも出ない(対象ファイルを持たない)', (tester) async {
      // 開始 100・1 桁なので、選択 1 件でも 3 桁必要になる。
      final c = FileListController(
        files: [_f('alpha.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<DigitShortageWarning>().length, 1);
      // 002 REQ-015: `DigitShortageWarning` は `file` を持たないので行に帰属しない。
      expect(_rowWarnings(), findsNothing);
      // 代わりに、ルールを直せば消える原因として出る。
      expect(_ruleNotice(), findsNothing); // 導線が無い画面では出さない
      // 件数には数える(005 REQ-009 冒頭「4 種すべてを提示する」)。
      expect(find.textContaining('1 件の問題'), findsOneWidget);
    });

    testWidgets('空名の行には重複を出さない(REQ-021 規則2)', (tester) async {
      // 空リテラルだけのルール → 2 件とも拡張子だけの同じ名前になり、
      // 001 は空名 2 件 + 重複 2 件を返す。
      final c = FileListController(
        files: [_f('a.txt'), _f('b.txt')],
        rule: const RenameRule([LiteralToken('')]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<EmptyNameWarning>().length, 2);
      expect(c.warnings.whereType<DuplicateWarning>().length, 2);
      // そのファイルは改名の対象にならない(REQ-022)ので、その重複は実際には
      // 生じない。**判定は消さない** — 詳細には出る(下の (3) の group)。
      for (final text in _rowWarningTexts(tester)) {
        expect(text, isNot(contains('重複')));
        expect(text, contains('改名されません'));
      }
    });

    testWidgets('空名 + 基準日時不明は結果へ畳む(REQ-021 規則1)', (tester) async {
      // 作成日時トークンだけのルール + 作成日時が不明なファイル。
      final c = FileListController(
        files: [_noCreatedAt('shot.png')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<EmptyNameWarning>(), hasLength(1));
      expect(c.warnings.whereType<MissingSourceDateWarning>(), hasLength(1));
      // 行に出るのは結果だけ。原因(どのトークンか)は行に出さない。
      final text = _rowWarningTexts(tester).single;
      expect(text, contains('改名されません'));
      expect(text, isNot(contains('トークン')));
      // **基準日時不明を別立てで並べない**(REQ-021 規則1: 結果へ畳む)。
      // 行の警告は1つの `Text` へ連結されるので、**widget の個数を数えても
      // 別立てを検出できない。**文言そのものを見る。
      expect(text, isNot(contains('作成日時')));
    });

    testWidgets('種別が併発しても行の警告が 2 行に収まる', (tester) async {
      // 行に同時に出るのは最大 2 種(重複 + 基準日時不明)である。空名が該当する
      // 行は REQ-021 が 1 つへ畳む。**切り詰めると併発時に種別が読めなくなる**
      // ので、いちばん狭い実機幅で全部読めることを固定する。
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

      final texts = _rowWarningTexts(tester);
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text, contains('重複'));
        expect(text, contains('作成日時'));
      }
      final paragraphs = find.descendant(
        of: _rowWarnings(),
        matching: find.byType(Text),
      );
      for (final element in paragraphs.evaluate()) {
        expect(
          (element.renderObject! as RenderParagraph).didExceedMaxLines,
          isFalse,
          reason: '併発した種別が切り詰められている',
        );
      }
    });

    testWidgets('同じ種別は行で 1 つにまとめる', (tester) async {
      // 日時トークンが 2 本とも取れないと 001 は 2 件返すが、行は種別しか
      // 出さないので同じ文言が 2 回並んでも情報が増えない。
      final c = FileListController(
        files: [_noCreatedAt('a.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          DateTimeToken(source: DateTimeSource.created, format: 'MMDD'),
        ]),
      );
      await _pump(tester, c);

      expect(c.warnings.whereType<MissingSourceDateWarning>().length, 2);
      final text = _rowWarningTexts(tester).single;
      expect(text, '作成日時が空になります');
      expect(text, isNot(contains('・')));
    });

    testWidgets('`sortMode` を名前順にしても種別が読める', (tester) async {
      // 002 REQ-013 が `sortMode` でゲートしているのは**日時表示そのものの強調**で
      // あり、ルール文脈の警告はゲートの対象外である。真似てゲートすると
      // REQ-009 (1) が破れる(008:T15 の独立reviewが挙げた N-15-2)。
      final c = FileListController(
        files: [_noCreatedAt('nodate.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      c.setSortMode(FileSortMode.name);
      await _pump(tester, c);

      expect(_rowWarnings(), findsOneWidget);
      expect(_rowWarningTexts(tester).single, contains('作成日時'));
    });
  });

  group('REQ-009 (2): 変わらない説明を件数ぶん繰り返さない', () {
    /// 原因の提示が見える画面(狭幅=下部バーのルール設定button)を出す。
    Future<void> pumpWithRuleAffordance(
      WidgetTester tester,
      FileListController c,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: FileListView(controller: c, onEditRule: () {}),
          ),
        ),
      );
    }

    // **説明そのものは詳細dialogが持ち、常設側は種別だけを出す。**
    // 常設側へ説明を並べると、原因(トークン)の数と文字倍率で伸びて一覧と
    // 下部バーを押し出した(独立review attempt 3 のP1-1)。要求は「件数ぶん
    // 繰り返さない・単位は原因ごと」なので、**説明が1つであることは
    // dialog の側で検査する。**弱めた付け替えではない。

    testWidgets('作成日時が取れない 30 件でも、トークンの説明は 1 つ', (tester) async {
      // 005 例20a / 例20g。**同じ説明が 30 回出ていたのが 008:T16 以前である。**
      final c = FileListController(
        files: [for (var i = 0; i < 30; i++) _noCreatedAt('IMG_$i.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      await pumpWithRuleAffordance(tester, c);

      expect(c.warnings.whereType<MissingSourceDateWarning>().length, 30);
      // **描画された行すべて**で種別が読める((1) は件数ぶん出てよい)。
      // `ListView.builder` は見えている行しか作らないので、30 を直に数えない。
      final renderedRows = tester.widgetList(find.byType(Checkbox)).length;
      expect(renderedRows, greaterThan(1));
      expect(_rowWarnings(), findsNWidgets(renderedRows));
      // 常設側は種別のみ。**30 件でも 1 つ。**
      expect(_ruleNotice(), findsOneWidget);
      expect(_inRuleNotice(find.text('基準日時なし')), findsOneWidget);
      expect(_inRuleNotice(find.byType(Text)), findsOneWidget);

      // 説明は 1 つ。**単位は原因(トークン)ごとである。**
      await _openDetailFromCount(tester);
      expect(_inCauses(find.textContaining('2 番目のトークン')), findsOneWidget);
      // 節の中は**見出し 1 + 説明 1** で、30 件ぶんには増えない。
      expect(_inCauses(find.byType(Text)), findsNWidgets(2));
    });

    testWidgets('取れないトークンが 2 本なら説明は 2 つ', (tester) async {
      final c = FileListController(
        files: [_noCreatedAt('a.jpg'), _noCreatedAt('b.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          DateTimeToken(source: DateTimeSource.created, format: 'MMDD'),
        ]),
      );
      await pumpWithRuleAffordance(tester, c);

      expect(c.warnings.whereType<MissingSourceDateWarning>().length, 4);
      // 常設側は**トークンが 2 本でも種別 1 つのまま**(占有が原因の数に依らない)。
      expect(_inRuleNotice(find.byType(Text)), findsOneWidget);

      await _openDetailFromCount(tester);
      expect(_inCauses(find.textContaining('2 番目のトークン')), findsOneWidget);
      expect(_inCauses(find.textContaining('3 番目のトークン')), findsOneWidget);
      // 見出し 1 + 説明 2。**ファイル 2 件ぶんには増えない。**
      expect(_inCauses(find.byType(Text)), findsNWidgets(3));
    });

    testWidgets('桁不足はトークンの位置と必要桁数が分かる', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );
      await pumpWithRuleAffordance(tester, c);

      expect(_inRuleNotice(find.text('桁不足')), findsOneWidget);

      await _openDetailFromCount(tester);
      expect(_inCauses(find.textContaining('1 番目のトークン')), findsOneWidget);
      expect(_inCauses(find.textContaining('連番 1 桁')), findsOneWidget);
      expect(_inCauses(find.textContaining('3 桁必要')), findsOneWidget);
    });

    testWidgets('種別は 2 つを超えない(常設側の占有が原因の数に依らない)', (tester) async {
      // 桁不足 1 本 + 基準日時不明 3 本 = 原因 4 つ。それでも種別は 2 つ。
      final c = FileListController(
        files: [_noCreatedAt('a.jpg'), _noCreatedAt('b.jpg')],
        rule: const RenameRule([
          SequenceToken(start: 100, digits: 1),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          DateTimeToken(source: DateTimeSource.created, format: 'MM'),
          DateTimeToken(source: DateTimeSource.created, format: 'DD'),
        ]),
      );
      await pumpWithRuleAffordance(tester, c);

      expect(_inRuleNotice(find.byType(Text)), findsNWidgets(2));
      expect(_inRuleNotice(find.text('桁不足')), findsOneWidget);
      expect(_inRuleNotice(find.text('基準日時なし')), findsOneWidget);

      // 説明の側は原因の数だけある(dialog は伸びてよい — scroll する)。
      await _openDetailFromCount(tester);
      for (final n in ['1', '2', '3', '4']) {
        expect(_inCauses(find.textContaining('$n 番目のトークン')), findsOneWidget);
      }
    });

    testWidgets('広幅でも占有が原因の数に依らず、警告が無ければ余白も出ない', (tester) async {
      // **広幅(≥840dp・2ペイン)の占有を測る。** 独立review attempt 4 が
      // 「占有testは 360×640 と 731×411 のどちらも狭幅layoutで、広幅を測る
      // testが1つも無い」を安全網の穴として挙げた(受容可能と判定されたが、
      // widget test 数行で閉じるのでここで閉じる)。
      //
      // あわせて、**警告が無い通常状態で余白だけが残らない**ことを見る。
      // `RuleWarningNotice` は種別 0 件で `SizedBox.shrink()` を返すので、
      // 呼び出し側が `Padding` で包むと死んだ余白ができる(attempt 4 のP2-1)。
      const size = Size(1200, 800);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<Rect> pumpWide(int causes) async {
        final rule = RuleController();
        addTearDown(rule.dispose);
        if (causes > 0) {
          rule.addToken(const SequenceToken(start: 100, digits: 1));
        }
        for (var i = 1; i < causes; i++) {
          rule.addToken(
            const DateTimeToken(source: DateTimeSource.created, format: 'yyyy'),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(
                key: ValueKey('wide-$causes'),
                fileList: FileListController(
                  files: [_noCreatedAt('a.jpg'), _noCreatedAt('b.jpg')],
                ),
                rule: rule,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.byType(RuleBuilderView));
      }

      // 警告なし(ルールが空)。**余白を含めて何も足されない。**
      final clean = await pumpWide(0);
      expect(_ruleNotice(), findsNothing);

      final two = await pumpWide(2);
      expect(_ruleNotice(), findsOneWidget);
      expect(
        two.height,
        lessThan(clean.height),
        reason: '警告が出たのにルールビルダーの取り分が変わっていない',
      );

      // **余白は widget 側が持つ。** 呼び出し側が `Padding` で包むと、種別が
      // 0 件のとき余白だけが残る(attempt 4 のP2-1)。上の `clean` がそれを
      // 押さえ、ここが「包むのをやめた結果、余白が消えていない」を押さえる。
      // **余白は widget 側が持つ。** 呼び出し側が `Padding` で包むと、種別が
      // 0 件のとき余白だけが残る(attempt 4 のP2-1)。上の `clean` がそれを
      // 押さえ、ここが「包むのをやめた結果、余白まで消えていない」を押さえる。
      // `getRect` が返すのは margin を含む外側の箱なので、中身との差を見る。
      final notice = tester.getRect(_ruleNotice());
      final inner = tester.getRect(
        find.descendant(of: _ruleNotice(), matching: find.byType(Wrap)),
      );
      // margin 12 + padding 10 = 22。margin を落とすと 10 になる。
      expect(inner.left - notice.left, 22, reason: '左の余白が無い');
      expect(notice.right - inner.right, 22, reason: '右の余白が無い');
      // margin 12 + padding 6 = 18。margin を落とすと 6 になる。
      expect(inner.top - notice.top, 18, reason: '上の余白が無い');

      // **原因が増えても変わらない**(種別は 2 つが上限)。
      for (final causes in [3, 5, 10]) {
        final grown = await pumpWide(causes);
        expect(
          grown.height,
          two.height,
          reason: '広幅で原因 $causes 本がルールビルダーを削っている',
        );
      }
    });

    testWidgets('狭幅と広幅のどちらでも原因が出る', (tester) async {
      // **広幅では下部バーにルール設定の導線が無い**(`_buildWide` は `onEditRule`
      // を渡さない)。ルールを変更する操作は右ペインなので、そちらへ出る。
      // **片方だけ通しても、もう片方の抜けは検出できない。**
      for (final size in [const Size(400, 800), const Size(1200, 800)]) {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // **ルールは `RuleController` 側に置く。** `RuleBuilderWorkspace` は
        // 初回フレーム後に自分のルールを `FileListController` へ流すので、
        // controller 側へ直接入れると空で上書きされる。
        final rule = RuleController()
          ..addToken(const SequenceToken(start: 100, digits: 1));
        addTearDown(rule.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(
                fileList: FileListController(files: [_f('alpha.txt')]),
                rule: rule,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _ruleNotice(),
          findsOneWidget,
          reason: '幅 ${size.width} で原因の提示が行き場を失っている',
        );
        expect(_inRuleNotice(find.text('桁不足')), findsOneWidget);
      }
    });
  });

  group('REQ-009 (3): 全件と説明を読める提示', () {
    testWidgets('件数表示から開くと、対象ファイルと衝突する生成後名が読める', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);
      await _openDetailFromCount(tester);

      expect(_detail(), findsOneWidget);
      expect(_inDetail(find.textContaining('alpha.txt')), findsOneWidget);
      expect(_inDetail(find.textContaining('bravo.txt')), findsOneWidget);
      expect(_inDetail(find.textContaining('same.txt')), findsNWidgets(2));
      // 種別ごとにまとまり、件数が見える。
      expect(_inDetail(find.textContaining('重複 2 件')), findsOneWidget);
    });

    testWidgets('行の警告からも同じ詳細が開く', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      await tester.tap(_rowWarnings().first);
      await tester.pumpAndSettle();

      expect(_detail(), findsOneWidget);
      expect(_inDetail(find.textContaining('alpha.txt')), findsOneWidget);
      expect(_inDetail(find.textContaining('bravo.txt')), findsOneWidget);
    });

    testWidgets('行に出していない重複も詳細には残る(判定を消さない)', (tester) async {
      final c = FileListController(
        files: [_f('a.txt'), _f('b.txt')],
        rule: const RenameRule([LiteralToken('')]),
      );
      await _pump(tester, c);
      await _openDetailFromCount(tester);

      expect(_inDetail(find.textContaining('重複')), findsWidgets);
      expect(_inDetail(find.textContaining('空の名前')), findsWidgets);
    });

    testWidgets('基準日時不明は、どのファイルのどのトークンかが読める', (tester) async {
      final c = FileListController(
        files: [_f('dated.jpg'), _noCreatedAt('nodate.jpg')],
        rule: const RenameRule([
          LiteralToken('img_'),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
          SequenceToken(start: 1, digits: 2),
        ]),
      );
      await _pump(tester, c);
      await _openDetailFromCount(tester);

      // **同じ 1 行が**ファイルとトークンの両方を名指す(別々の行に散らない)。
      final entry = tester
          .widgetList<Text>(_inFiles(find.textContaining('nodate.jpg')))
          .single
          .data!;
      expect(entry, contains('2 番目のトークン'));
      expect(entry, contains('作成日時「YYYYMMDD」'));
      expect(entry, contains('作成日時が不明'));
    });

    testWidgets('同名・別フォルダのときは場所も添えて見分けられる', (tester) async {
      final c = FileListController(
        files: [
          _f('photo.jpg', location: '/dcim/a'),
          _f('photo.jpg', location: '/dcim/b'),
        ],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pump(tester, c);
      await _openDetailFromCount(tester);

      expect(_inDetail(find.textContaining('/dcim/a')), findsOneWidget);
      expect(_inDetail(find.textContaining('/dcim/b')), findsOneWidget);
    });

    testWidgets('複数種が同時に出ても全件が読める', (tester) async {
      // 増分 0 の連番 + 作成日時不明の 2 件 →
      // 重複 2 件・基準日時不明 2 件・桁不足 1 件(空名は連番があるため起きない)。
      final c = FileListController(
        files: [_noCreatedAt('alpha.jpg'), _noCreatedAt('bravo.jpg')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          SequenceToken(start: 100, digits: 1, increment: 0),
        ]),
      );
      await _pump(tester, c);

      expect(c.warnings.length, 5);
      // 行では種別が読める(1 ファイルにつき重複と基準日時不明の 2 種)。
      expect(_rowWarnings(), findsNWidgets(2));
      for (final text in _rowWarningTexts(tester)) {
        expect(text, contains('重複'));
        expect(text, contains('作成日時'));
      }

      await _openDetailFromCount(tester);
      // 詳細では対象ファイルが 1 件ずつ識別できる(重複 + 基準日時不明で 2 行)。
      expect(_inDetail(find.textContaining('alpha.jpg')), findsNWidgets(2));
      expect(_inDetail(find.textContaining('bravo.jpg')), findsNWidgets(2));
      expect(_inFiles(find.textContaining('3 桁必要')), findsOneWidget);
    });
  });

  group('色は AppColors のセマンティック色を使う', () {
    testWidgets('行の警告と件数表示は danger を使う', (tester) async {
      final c = FileListController(
        files: [_f('only.txt')],
        rule: const RenameRule([LiteralToken('')]),
      );
      await _pump(tester, c);

      final texts = tester
          .widgetList<Text>(
            find.descendant(of: _rowWarnings(), matching: find.byType(Text)),
          )
          .toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.style?.color, AppColors.dark.danger);
      }
      final icons = tester
          .widgetList<Icon>(
            find.descendant(of: _rowWarnings(), matching: find.byType(Icon)),
          )
          .toList();
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(icon.color, AppColors.dark.danger);
      }
    });
  });

  group('REQ-010: 警告が 0 件なら提示しない', () {
    testWidgets('該当が無ければ行にも説明にも出ず、「問題なし」になる', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([
          LiteralToken('img_'),
          SequenceToken(start: 1, digits: 2),
        ]),
      );
      await _pump(tester, c);

      expect(c.warnings, isEmpty);
      expect(_rowWarnings(), findsNothing);
      expect(_ruleNotice(), findsNothing);
      // 「問題なし」は出してよい — **それは警告ではない。**
      expect(find.text('問題なし'), findsOneWidget);
      expect(find.textContaining('件の問題'), findsNothing);
    });

    testWidgets('件数表示を押しても、0 件のときは詳細が開かない', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pump(tester, c);

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      expect(_detail(), findsNothing);
    });

    testWidgets('選択を外して警告が消えたら提示も消える', (tester) async {
      final files = [_f('alpha.txt'), _f('bravo.txt')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);
      expect(_rowWarnings(), findsNWidgets(2));

      c.toggleSelection(files[1]);
      await tester.pump();

      expect(c.warnings, isEmpty);
      expect(_rowWarnings(), findsNothing);
      expect(find.text('問題なし'), findsOneWidget);
    });

    testWidgets('ファイルが 0 件でも警告は出ない', (tester) async {
      final c = FileListController(files: const [], rule: RenameRule.empty);
      await _pump(tester, c);

      expect(c.warnings, isEmpty);
      expect(_rowWarnings(), findsNothing);
    });
  });
}
