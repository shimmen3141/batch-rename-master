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
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
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
      // 初期は名前の昇順(002 REQ-001)で dup1 が先頭になる。`nodate.jpg` を先頭の
      // 行にするため名前の降順へ並べる(dup1 の重複警告は dup2 を含むので使わない)。
      c.setSortMode(FileSortMode.name, direction: SortDirection.descending);
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

      // **相手も同じ組に並ぶ**(revision 10.0、代表例 20e″。`008:T53`)。
      final group = find.byKey(warningDetailGroupKey(0, 0));
      List<String> groupTexts() => tester
          .widgetList<Text>(
            find.descendant(of: group, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .toList();
      expect(groupTexts(), hasLength(3));
      expect(groupTexts()[0], contains('same.txt'));
      expect(groupTexts().sublist(1), ['「alpha.txt」', '「bravo.txt」']);
    });
  });

  group('重複の相手(005 revision 10.0。`008:T53`)', () {
    testWidgets('狭い幅・大きな文字・多くの組でも、見出しと「閉じる」が画面に残る', (tester) async {
      const screenSize = Size(320, 640);
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // 30 folder × 2 件。どの folder でも2件が `same.txt` になる → 30 組。
      FileEntry f(String name, int folder) => FileEntry(
        name: name,
        createdAt: DateTime(2024, 3, 4),
        modifiedAt: DateTime(2026, 8, 4),
        size: 0,
        sourceFolder: 'F$folder',
        sourceLocation: 'DCIM/F$folder',
      );
      final c = FileListController(
        files: [
          for (var i = 0; i < 30; i++) ...[f('a_$i.txt', i), f('b_$i.txt', i)],
        ],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(1.6),
          ),
          child: MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(body: FileListView(controller: c)),
          ),
        ),
      );

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final screen = Offset.zero & screenSize;
      final close = tester.getRect(find.byKey(warningDetailCloseKey));
      expect(screen.contains(close.topLeft), isTrue);
      expect(screen.contains(close.bottomRight), isTrue);
      final dialog = tester.getRect(find.byKey(warningDetailDialogKey));
      expect(screen.contains(dialog.topLeft), isTrue);
      // 組は folder ごとに分かれている(最初の組が見えていればよい)。
      expect(find.byKey(warningDetailGroupKey(0, 0)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(warningDetailGroupKey(0, 0)),
          matching: find.textContaining('DCIM/F0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('行から開くと相手が読め、相手の他の警告は出ない(代表例 20e″)', (tester) async {
      // どちらも作成日時が取れない → 生成後名はともに `same.jpg`(重複)で、
      // 2件とも作成日時不明も持つ。
      final c = FileListController(
        files: [_noCreatedAt('a.jpg'), _noCreatedAt('b.jpg')],
        rule: const RenameRule([
          LiteralToken('same'),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        ]),
      );
      await _pump(tester, c);
      expect(c.warnings.whereType<DuplicateWarning>(), hasLength(2));
      expect(c.warnings.whereType<MissingSourceDateWarning>(), hasLength(2));

      await tester.tap(find.byKey(rowWarningKey).first);
      await tester.pumpAndSettle();

      final sections = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('warning-detail-section-');
      });
      expect(sections, findsNWidgets(2));
      // 重複の組には相手(b.jpg)が並ぶ。
      final group = find.byKey(warningDetailGroupKey(0, 0));
      expect(
        find.descendant(of: group, matching: find.text('「b.jpg」')),
        findsOneWidget,
      );
      // **作成日時不明の節は、その行のファイルだけ**(相手の分は出さない)。
      final dateTargets = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(warningDetailTargetsKey(1)),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(dateTargets, ['「a.jpg」']);
      expect(find.textContaining('作成日時不明 1 件'), findsOneWidget);
    });

    test('相手として足すのは、同じ folder・同じ変更後名の重複だけ', () {
      FileEntry f(String name, String folder) => FileEntry(
        name: name,
        modifiedAt: DateTime(2026, 8, 4),
        size: 0,
        sourceFolder: folder,
      );
      final a = f('a.txt', 'A');
      final b = f('b.txt', 'A');
      final otherFolder = f('c.txt', 'B');
      final otherName = f('d.txt', 'A');
      final own = DuplicateWarning(file: a, resultName: 'same.txt');
      final ownDate = MissingSourceDateWarning(
        file: a,
        tokenIndex: 1,
        token: const DateTimeToken(
          source: DateTimeSource.created,
          format: 'YYYY',
        ),
      );
      final partner = DuplicateWarning(file: b, resultName: 'same.txt');
      final partnerDate = MissingSourceDateWarning(
        file: b,
        tokenIndex: 1,
        token: const DateTimeToken(
          source: DateTimeSource.created,
          format: 'YYYY',
        ),
      );
      final all = <Warning>[
        own,
        ownDate,
        partner,
        partnerDate,
        DuplicateWarning(file: otherFolder, resultName: 'same.txt'),
        DuplicateWarning(file: otherName, resultName: 'other.txt'),
      ];

      expect(rowDetailWarnings([own, ownDate], all), [own, ownDate, partner]);
      // 重複を持たない行には何も足さない。
      expect(rowDetailWarnings([ownDate], all), [ownDate]);
    });

    testWidgets('読み込んでいない同名とぶつかると「フォルダにある既存のファイル」', (tester) async {
      final c = FileListController(
        files: [
          FileEntry(
            name: 'alpha.txt',
            createdAt: DateTime(2024, 3, 4),
            modifiedAt: DateTime(2026, 8, 4),
            size: 0,
            sourceFolder: 'F',
          ),
        ],
        rule: const RenameRule([LiteralToken('same')]),
      );
      c.setOccupiedNames({
        'F': {'same.txt'},
      });
      await _pump(tester, c);
      expect(c.warnings.whereType<DuplicateWarning>(), hasLength(1));

      for (final entry in [rowWarningKey, warningCountKey]) {
        await tester.tap(find.byKey(entry));
        await tester.pumpAndSettle();
        final group = find.byKey(warningDetailGroupKey(0, 0));
        expect(
          find.descendant(of: group, matching: find.text('「alpha.txt」')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: group, matching: find.text(existingFileLabel)),
          findsOneWidget,
          reason: '$entry から開いた詳細',
        );
        await tester.tap(find.byKey(warningDetailCloseKey));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('同じ変更後名でも folder が違えば別の組(場所を見出しに添える)', (tester) async {
      FileEntry f(String name, String folder) => FileEntry(
        name: name,
        createdAt: DateTime(2024, 3, 4),
        modifiedAt: DateTime(2026, 8, 4),
        size: 0,
        sourceFolder: folder,
        sourceLocation: 'DCIM/$folder',
      );
      final c = FileListController(
        files: [
          f('a1.txt', 'A'),
          f('b1.txt', 'B'),
          f('a2.txt', 'A'),
          f('b2.txt', 'B'),
        ],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pump(tester, c);

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      List<String> groupTexts(int g) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(warningDetailGroupKey(0, g)),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();
      final groups = [groupTexts(0), groupTexts(1)];
      expect(find.byKey(warningDetailGroupKey(0, 2)), findsNothing);
      // 組ごとに、同じ folder のファイルだけが並ぶ。
      final byHeading = {for (final g in groups) g.first: g.sublist(1).toSet()};
      expect(byHeading.keys, everyElement(contains('same.txt')));
      expect(byHeading.keys.toSet(), hasLength(2), reason: '見出しで2つの組を見分けられる');
      expect(
        byHeading.values,
        containsAll([
          {'「a1.txt」', '「a2.txt」'},
          {'「b1.txt」', '「b2.txt」'},
        ]),
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
      // バナーでは何についての状態かを先頭に付ける(2026-09-30 の開発者の指定)。
      expect(find.text('リネーム: 82 件の問題'), findsOneWidget);
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

  group('場所の括弧は見分けが必要なときだけ(独立review attempt 1 の P1-1 / P1-2)', () {
    testWidgets('1ファイルに警告が2件あっても、場所は添えない', (tester) async {
      // **同じファイルが警告の件数ぶん数えられると、同名が1件も無いのに
      // 「同名が並ぶ」と誤判定する**(P1-1)。日時トークン2本で1ファイルに
      // 基準日時不明が2件出る状態にする。
      final c = FileListController(
        files: [
          FileEntry(
            name: 'photo.jpg',
            modifiedAt: DateTime(2026, 8, 4),
            size: 0,
            sourceLocation: 'DCIM/Camera',
          ),
        ],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          DateTimeToken(source: DateTimeSource.created, format: 'MM'),
        ]),
      );
      await _pump(tester, c);
      expect(c.warnings, hasLength(2));

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      expect(_targetTexts(tester), hasLength(2));
      expect(
        _targetTexts(tester).every((t) => !t.contains('DCIM/Camera')),
        isTrue,
        reason: '同名のファイルは並んでいない',
      );
    });

    test('同名判定は相異なるファイルで数える(同じファイルが2回来ても同名ではない)', () {
      // `amongFiles` を渡さない経路(既定値)では警告のリストから数えるので、
      // **identity で畳まないと 1 ファイル × 警告2件が「同名」になる**。
      final photo = FileEntry(
        name: 'photo.jpg',
        modifiedAt: DateTime(2026, 8, 4),
        size: 0,
        sourceLocation: 'DCIM/A',
      );
      final other = FileEntry(
        name: 'photo.jpg',
        modifiedAt: DateTime(2026, 8, 4),
        size: 0,
        sourceLocation: 'DCIM/B',
      );
      expect(ambiguousFileNames([photo, photo]), isEmpty);
      expect(ambiguousFileNames([photo, other]), {'photo.jpg'});

      // 既定値の経路(呼び出し側が一覧を渡さない場合)も同じ扱いになる。
      final sections = warningDetailSections([
        MissingSourceDateWarning(
          file: photo,
          tokenIndex: 1,
          token: const DateTimeToken(
            source: DateTimeSource.created,
            format: 'YYYY',
          ),
        ),
        MissingSourceDateWarning(
          file: photo,
          tokenIndex: 2,
          token: const DateTimeToken(
            source: DateTimeSource.created,
            format: 'MM',
          ),
        ),
      ], ruleIsEmpty: false);
      expect(
        sections.expand((section) => section.targets),
        everyElement(isNot(contains('DCIM/A'))),
      );
    });

    testWidgets('同名2件のうち片方だけが警告されても、場所を添える', (tester) async {
      // **母集合が「警告を持つファイル」だと、もう1件の同名が見えず場所が
      // 付かない**(P1-2)。作成日時を持つ方は警告にならない。
      final c = FileListController(
        files: [
          FileEntry(
            name: 'photo.jpg',
            modifiedAt: DateTime(2026, 8, 4),
            size: 0,
            sourceLocation: 'DCIM/A',
          ),
          FileEntry(
            name: 'photo.jpg',
            createdAt: DateTime(2024, 3, 4),
            modifiedAt: DateTime(2026, 8, 4),
            size: 0,
            sourceLocation: 'DCIM/B',
          ),
        ],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        ]),
      );
      await _pump(tester, c);
      expect(c.warnings, hasLength(1));

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();

      expect(_targetTexts(tester).single, contains('DCIM/A'));
    });
  });

  group('行から開く詳細の被覆(独立review attempt 1 の P3-5)', () {
    testWidgets('空名の行から開くと、行に出していない重複も読める(REQ-021 規則2)', (tester) async {
      // 行は空名だけを出す(規則2 で重複を出さない)。**詳細には残る** —
      // 規則2 の「ただし REQ-009 (3) の提示には含める」。
      final c = FileListController(
        files: [_dated('a.txt'), _dated('b.txt')],
        rule: const RenameRule([LiteralToken('')]),
      );
      await _pump(tester, c);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(rowWarningKey).first,
                matching: find.byType(Text),
              ),
            )
            .data,
        isNot(contains('重複')),
      );

      await tester.tap(find.byKey(rowWarningKey).first);
      await tester.pumpAndSettle();

      expect(find.textContaining(duplicateKindLabel), findsWidgets);
      // 空名の節は**その行のファイルだけ**(混ざらない)。b.txt は重複の相手としてだけ
      // 読める(revision 10.0。`008:T53`)。
      final sectionCount = find
          .byWidgetPredicate((w) {
            final key = w.key;
            return key is ValueKey<String> &&
                key.value.startsWith('warning-detail-section-');
          })
          .evaluate()
          .length;
      for (var i = 0; i < sectionCount; i++) {
        final inGroups = find.descendant(
          of: find.byKey(warningDetailTargetsKey(i)),
          matching: find.byWidgetPredicate((w) {
            final key = w.key;
            return key is ValueKey<String> &&
                key.value.startsWith('warning-detail-group-');
          }),
        );
        final texts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(warningDetailTargetsKey(i)),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data ?? '');
        if (inGroups.evaluate().isEmpty) {
          expect(texts, everyElement(isNot(contains('b.txt'))));
        } else {
          expect(texts.where((t) => t.contains('b.txt')), hasLength(1));
        }
      }
    });

    testWidgets('桁不足に該当しない行の詳細には、桁不足の節が出ない', (tester) async {
      // 連番1桁・12件 → 10件目以降だけが桁を超える(002 REQ-015 の導出)。
      final c = FileListController(
        files: [for (var i = 0; i < 12; i++) _noCreatedAt('f$i.jpg')],
        rule: const RenameRule([
          SequenceToken(start: 1, digits: 1),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        ]),
      );
      await _pump(tester, c);

      // 先頭行(1番目)は桁に収まる。
      await tester.tap(find.byKey(rowWarningKey).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('作成日時不明'), findsWidgets);
      expect(find.textContaining(digitShortageKindLabel), findsNothing);
      await tester.tap(find.byKey(const Key('warning-detail-close')));
      await tester.pumpAndSettle();

      // 全件の入口には出る(桁不足そのものは起きている)。
      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      expect(find.textContaining(digitShortageKindLabel), findsWidgets);
    });
  });

  group('行と詳細が同じ語彙を使う(008:T19 が文言の正本)', () {
    testWidgets('作成日時が取れない: 行は補足情報の赤字、詳細は「作成日時不明」', (tester) async {
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
      // `008:T50`: 右端には書かず、補足情報の `作成日時: 不明` を赤で強調する。
      expect(rowText, rowWarningDetailLabel);
      final createdAt = tester.widget<Text>(find.byKey(rowCreatedAtKey));
      expect(createdAt.data, contains('不明'));
      expect(createdAt.style?.color, AppColors.dark.danger);

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

    testWidgets('桁不足: 行も詳細も同じ語(`008:T50` で「桁不足」へ短くした)', (tester) async {
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
        digitShortageKindLabel,
      );

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      // 詳細の節の見出しも同じ語(桁不足は対象をトークンで示すので件数を付けない)。
      // 以前の長い語は残っていない。
      expect(find.text(digitShortageKindLabel), findsWidgets);
      expect(find.textContaining('桁不足 1 件'), findsNothing);
      expect(find.textContaining('連番の桁不足'), findsNothing);
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
        closeTo(8, 0.01),
        reason: 'padding vertical 4 の上下(`008:T50` で枠線をやめた)',
      );
      expect(
        hit.width - content.width,
        closeTo(12, 0.01),
        reason: 'padding horizontal 6 の左右(`008:T50` で枠線をやめた)',
      );
      // 指で押せる大きさであること(縮める変更を止める)。
      expect(hit.height, greaterThanOrEqualTo(20));
    });
  });
}
