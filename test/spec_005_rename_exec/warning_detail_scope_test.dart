// VER-005(008:T19 分): 警告の詳細のスコープ・数え方・語彙・tap範囲。
// 対象: 005 REQ-009 (2)(説明を件数ぶん繰り返さない)/ (3)(全件と説明)/
//       (4)(行からはその行だけ・全件からは全件。混ざらない)/ REQ-021。
//
// このfileは `008:T19` が引き受けた残余riskを閉じるために置いた。
// - **R-A(`008:T16` から)**: 件数の数え方を固定する assertion が無かった。
// - **出ない方向(`008:T18` から)**: 導線の無い `FileListView` 単体で原因の説明が
//   出ないことの assertion が消えていた。
// - **穴C(`008:T18` から)**: 行の警告の tap範囲が**縮む**方向を縛る assertion が
//   無かった(`tool/mutations.json` の M227)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _dated(String name, {String? location}) => FileEntry(
  name: name,
  createdAt: DateTime(2024, 3, 4),
  modifiedAt: DateTime(2026, 8, 4),
  size: 0,
  sourceLocation: location,
);

FileEntry _noCreatedAt(String name) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 8, 4), size: 0);

Future<void> _pump(
  WidgetTester tester,
  FileListController c, {
  VoidCallback? onEditRule,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(controller: c, onEditRule: onEditRule),
      ),
    ),
  );
}

List<String> _explanationTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.byWidgetPredicate((w) {
        final key = w.key;
        return w is Text &&
            key is ValueKey<String> &&
            key.value.startsWith('warning-detail-explanation-');
      }),
    )
    .map((text) => text.data ?? '')
    .toList();

List<String> _targetTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('warning-detail-targets-');
        }),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '')
    .toList();

void main() {
  group('REQ-009 (4): スコープが混ざらない', () {
    // **別の理由で警告になるファイルを混ぜる。**
    // - `nodate.jpg`: 作成日時が取れない → 作成日時不明(名前は空にならない)
    // - `dup1.jpg` / `dup2.jpg`: 作成日時が同じなので同じ名前になる(重複)
    FileListController controller() => FileListController(
      files: [
        _noCreatedAt('nodate.jpg'),
        _dated('dup1.jpg'),
        _dated('dup2.jpg'),
      ],
      rule: const RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        LiteralToken('_x'),
      ]),
    );

    testWidgets('行から開くと、他の行のファイルが混ざらない', (tester) async {
      final c = controller();
      await _pump(tester, c);

      await tester.tap(find.byKey(rowWarningKey).first);
      await tester.pumpAndSettle();

      final targets = _targetTexts(tester);
      expect(targets, isNotEmpty);
      // 先頭行のファイルだけ。**もう一方は出ない。**
      expect(targets.where((t) => t.contains('nodate.jpg')), isNotEmpty);
      expect(targets.every((t) => !t.contains('dup1.jpg')), isTrue);
      expect(targets.every((t) => !t.contains('dup2.jpg')), isTrue);
    });

    testWidgets('件数から開くと全件が出て、1ファイルに絞られない', (tester) async {
      final c = controller();
      await _pump(tester, c);

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      final targets = _targetTexts(tester);
      expect(targets.where((t) => t.contains('nodate.jpg')), isNotEmpty);
      expect(targets.where((t) => t.contains('dup1.jpg')), isNotEmpty);
      expect(targets.where((t) => t.contains('dup2.jpg')), isNotEmpty);
    });

    testWidgets('行から開いた詳細でも、その行について全件と同じ内容が読める', (tester) async {
      // 重複の変更後名は行の常設表示には出ない((1) は種別だけ)。
      final c = FileListController(
        files: [_dated('alpha.txt'), _dated('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      await tester.tap(find.byKey(rowWarningKey).first);
      await tester.pumpAndSettle();

      expect(
        _targetTexts(tester).single,
        allOf(contains('alpha.txt'), contains('same.txt')),
      );
    });
  });

  group('REQ-009 (2): 説明は原因ごとに1つで、件数に比例しない', () {
    // 開発者が確認を求めた形(2026-09-02): 27 件 × 日時トークン 3 本 + 桁不足 1。
    FileListController many() => FileListController(
      files: [for (var i = 0; i < 27; i++) _noCreatedAt('IMG_$i.jpg')],
      rule: const RenameRule([
        SequenceToken(start: 100, digits: 1),
        DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        DateTimeToken(source: DateTimeSource.created, format: 'MM'),
        DateTimeToken(source: DateTimeSource.created, format: 'DD'),
      ]),
    );

    testWidgets('27件 × 日時3本 + 桁不足でも、説明は原因の数(4)だけ', (tester) async {
      final c = many();
      await _pump(tester, c);
      expect(c.warnings.whereType<MissingSourceDateWarning>().length, 81);
      expect(c.warnings.whereType<DigitShortageWarning>().length, 1);

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      // **節は原因ごと**(日時トークン3本 + 連番1本)。
      expect(_explanationTexts(tester), hasLength(4));
      // 対象の列挙は件数ぶん並ぶ(27 × 3 本。桁不足は対象を列挙しない)。
      expect(_targetTexts(tester), hasLength(81));
    });

    testWidgets('件数は提示単位の数である(R-A の数え方を固定する)', (tester) async {
      // **`⚠ N 件の問題` の N は 001 の警告のうち REQ-021 規則1 で畳んだぶんを
      // 1 件に数えたもの。** 開発者が確認を求めた「82 件」がこの数え方である。
      final c = many();
      await _pump(tester, c);

      expect(c.warnings, hasLength(82));
      expect(presentWarnings(c.warnings), hasLength(82));
      expect(warningCountLabel(c.warnings), '82 件の問題');
      expect(find.text('82 件の問題'), findsOneWidget);
    });

    testWidgets('空名と基準日時不明が同時に該当するファイルは1件に畳む', (tester) async {
      // 日時トークン 2 本がどちらも取れない → 001 は空名1 + 基準日時不明2 = 3 件。
      // 提示は空名へ畳んで 1 件(REQ-021 規則1)。
      final c = FileListController(
        files: [_noCreatedAt('shot.png')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          DateTimeToken(source: DateTimeSource.created, format: 'MM'),
        ]),
      );
      await _pump(tester, c);

      expect(c.warnings, hasLength(3));
      expect(presentWarnings(c.warnings), hasLength(1));
      expect(warningCountLabel(c.warnings), '1 件の問題');
    });
  });

  group('行と詳細が同じ語彙を使う(008:T19 が文言の正本)', () {
    testWidgets('作成日時が取れない: 行も詳細も「作成日時不明」', (tester) async {
      final c = FileListController(
        files: [_noCreatedAt('a.jpg')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        ]),
      );
      await _pump(tester, c);

      final rowText = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(rowWarningKey),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(rowText, '作成日時不明');

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      // 節の見出しが行と同じ語彙。**改修前は詳細だけ「基準日時なし」だった。**
      expect(find.textContaining('作成日時不明'), findsWidgets);
      expect(find.textContaining('基準日時なし'), findsNothing);
      // **基準を取り違えない**(作成日時トークンで「更新日時不明」と出ない)。
      expect(find.textContaining('更新日時不明'), findsNothing);
    });

    test('基準ごとに語彙が変わる(更新日時トークンなら「更新日時不明」)', () {
      // 004 の実データは常に更新日時を持つので(001 INV-006)、validate 経由では
      // この経路を作れない。**語彙が基準から導かれていること**を警告オブジェクト
      // から直に確かめる — 「作成日時不明」と決め打ちする実装を排除する。
      final file = FileEntry(
        name: 'b.jpg',
        modifiedAt: DateTime(2026, 8, 4),
        size: 0,
      );
      final warning = MissingSourceDateWarning(
        file: file,
        tokenIndex: 1,
        token: DateTimeToken(source: DateTimeSource.modified, format: 'YYYY'),
      );
      expect(warningKindLabel(warning), '更新日時不明');
      expect(rowWarningLabel(warning), '更新日時不明');
      final section = warningDetailSections([
        warning,
      ], ruleIsEmpty: false).single;
      expect(section.title, '更新日時不明 1 件');
      expect(section.explanation, contains('更新日時が取れない'));
      expect(section.targets.single, '「b.jpg」');
    });

    testWidgets('桁不足: 行も詳細も「連番の桁不足」', (tester) async {
      final c = FileListController(
        files: [_dated('a.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );
      await _pump(tester, c);

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(rowWarningKey),
                matching: find.byType(Text),
              ),
            )
            .data,
        '連番の桁不足',
      );

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('連番の桁不足'), findsWidgets);
      expect(find.textContaining('桁不足 1 件'), findsNothing);
    });
  });

  group('原因の説明は詳細の外へ出さない(008:T18 から引き受けた「出ない方向」)', () {
    FileListController c() => FileListController(
      files: [_noCreatedAt('a.jpg')],
      rule: const RenameRule([
        OriginalNameToken(),
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]),
    );

    testWidgets('導線の無い FileListView 単体では、トークンの名指しが画面に出ない', (tester) async {
      await _pump(tester, c());

      // 行は種別だけを出す。**「何番目のトークン」は詳細を開くまで出ない。**
      expect(find.byKey(rowWarningKey), findsOneWidget);
      expect(find.textContaining('番目のトークン'), findsNothing);
      expect(find.byKey(warningDetailDialogKey), findsNothing);
    });

    testWidgets('ルール設定の導線がある狭幅でも、開くまでは名指しが出ない', (tester) async {
      await _pump(tester, c(), onEditRule: () {});

      expect(find.byKey(const Key('configure-rule')), findsOneWidget);
      expect(find.textContaining('番目のトークン'), findsNothing);

      // 開くと出る(出る方向も同じtestで押さえる)。
      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('番目のトークン'), findsWidgets);
    });
  });

  group('行の警告のtap範囲(008:T18 の穴C: 縮む方向)', () {
    testWidgets('当たり判定は中身より上下左右に広い', (tester) async {
      final c = FileListController(
        files: [_dated('a.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );
      await _pump(tester, c);

      final hit = tester.getRect(find.byKey(rowWarningKey));
      // 中身(アイコン + 文字を並べた `Row`)の外側に padding があることを測る。
      final content = tester.getRect(
        find.descendant(
          of: find.byKey(rowWarningKey),
          matching: find.byType(Row),
        ),
      );

      // **絶対値で固定する。** 「中身より広い」だけだと padding を 0 にしても
      // 枠線ぶんで通ってしまう。値は `padding` の実装値に一致する。
      expect(
        hit.height - content.height,
        closeTo(10, 0.01),
        reason: 'padding vertical 4 の上下 + 枠線 1 の上下',
      );
      expect(
        hit.width - content.width,
        closeTo(14, 0.01),
        reason: 'padding horizontal 6 の左右 + 枠線 1 の左右',
      );
      // 指で押せる大きさであること(縮める変更を止める)。
      expect(hit.height, greaterThanOrEqualTo(20));
    });
  });
}
