// VER-005: 001 の検証警告のプレビュー上での提示(FEAT-005 / Strict)。
// 対象: REQ-009(警告 4 種すべてを、対象ファイル・該当トークンが識別できる形で提示)
//       REQ-010(警告 0 件のときは提示しない)。
//
// 判定は 001 の validate が持ち、005 は表示だけを担う(契約 terms の「警告」)ので、
// ここでは「001 が返した警告が画面上で識別できるか」だけを見る。
// 帯は「件数と内訳の見出し(常時)」+「1 件 1 行の内訳(開閉)」の構成なので、
// 内訳を見る検証は見出しをタップしてから行う。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
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

final _panel = find.byKey(renameWarningsKey);

Finder _inPanel(Finder matching) =>
    find.descendant(of: _panel, matching: matching);

Finder _panelTexts() =>
    find.descendant(of: _panel, matching: find.byType(Text));

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

/// 内訳(1 件 1 行)を開く。
Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(renameWarningToggleKey));
  await tester.pump();
}

/// 帯を出し、内訳まで開いた状態にする。
Future<void> _pumpExpanded(WidgetTester tester, FileListController c) async {
  await _pump(tester, c);
  await _openDetails(tester);
}

void main() {
  group('REQ-009: 警告 4 種を対象が識別できる形で提示する', () {
    testWidgets('重複(DuplicateWarning): 対象ファイルと衝突する生成後名が分かる', (tester) async {
      // 2 件とも同じ固定文字になるので、双方が重複警告の対象になる。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pumpExpanded(tester, c);

      expect(c.warnings.whereType<DuplicateWarning>().length, 2);
      expect(_panel, findsOneWidget);
      // どのファイルが対象かが行から読み取れる(2 件それぞれ別の行)。
      expect(_inPanel(find.textContaining('alpha.txt')), findsOneWidget);
      expect(_inPanel(find.textContaining('bravo.txt')), findsOneWidget);
      // 衝突する生成後名も併記される。
      expect(_inPanel(find.textContaining('same.txt')), findsNWidgets(2));
      expect(
        _inPanel(find.textContaining('重複')),
        findsNWidgets(3),
      ); // 見出し + 2 行
    });

    testWidgets('桁不足(DigitShortageWarning): 該当トークンの位置と必要桁数が分かる', (
      tester,
    ) async {
      // 開始 100・1 桁なので、選択 1 件でも 3 桁必要になる。
      final c = FileListController(
        files: [_f('alpha.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );
      await _pumpExpanded(tester, c);

      expect(c.warnings.whereType<DigitShortageWarning>().length, 1);
      expect(_panel, findsOneWidget);
      // ルール内の何番目のトークンか(1 始まりの表示)と、必要な桁数。
      expect(_inPanel(find.textContaining('1 番目のトークン')), findsOneWidget);
      expect(_inPanel(find.textContaining('連番 1 桁')), findsOneWidget);
      expect(_inPanel(find.textContaining('3 桁必要')), findsOneWidget);
    });

    testWidgets('空名(EmptyNameWarning): 名前が空になるファイルが分かる', (tester) async {
      // トークンなし = ベース名が空。拡張子だけが残る。
      final c = FileListController(
        files: [_f('only.txt')],
        rule: RenameRule.empty,
      );
      await _pumpExpanded(tester, c);

      expect(c.warnings.whereType<EmptyNameWarning>().length, 1);
      expect(_panel, findsOneWidget);
      expect(_inPanel(find.textContaining('only.txt')), findsOneWidget);
      expect(_inPanel(find.textContaining('名前が空になります')), findsOneWidget);
    });

    testWidgets('基準日時不明(MissingSourceDateWarning): どのファイルのどのトークンが空になるか分かる', (
      tester,
    ) async {
      // 1 件は作成日時が不明、1 件は判明。ルールの 2 番目が作成日時トークン。
      final c = FileListController(
        files: [_f('dated.jpg'), _noCreatedAt('nodate.jpg')],
        rule: const RenameRule([
          LiteralToken('img_'),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
          SequenceToken(start: 1, digits: 2),
        ]),
      );
      await _pumpExpanded(tester, c);

      final missing = c.warnings.whereType<MissingSourceDateWarning>().toList();
      expect(missing.length, 1);
      expect(missing.single.file.name, 'nodate.jpg');
      expect(missing.single.tokenIndex, 1);

      expect(_panel, findsOneWidget);
      // 出るのはこの 1 件だけ(作成日時が判明している行は巻き込まない)。
      expect(_inPanel(find.textContaining('警告 1 件')), findsOneWidget);
      expect(find.byKey(renameWarningRowKey(0)), findsOneWidget);
      expect(find.byKey(renameWarningRowKey(1)), findsNothing);
      // どのファイルか。
      expect(_inPanel(find.textContaining('nodate.jpg')), findsOneWidget);
      // 「ルール内のどのトークンが空になるか」: 位置と書式で識別できる。
      expect(_inPanel(find.textContaining('2 番目のトークン')), findsOneWidget);
      expect(_inPanel(find.textContaining('作成日時「YYYYMMDD」')), findsOneWidget);
      expect(_inPanel(find.textContaining('が空になります')), findsOneWidget);
      // 空になる理由(基準日時が取れないこと)も添える。
      expect(_inPanel(find.textContaining('作成日時が不明')), findsOneWidget);
    });

    testWidgets('複数種が同時に出ても 1 件 1 行で並び、全件が識別できる', (tester) async {
      // 増分 0 の連番 + 作成日時不明の 2 件 →
      // 重複 2 件・基準日時不明 2 件・桁不足 1 件(空名は連番があるため起きない)。
      final c = FileListController(
        files: [_noCreatedAt('alpha.jpg'), _noCreatedAt('bravo.jpg')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          SequenceToken(start: 100, digits: 1, increment: 0),
        ]),
      );
      await _pumpExpanded(tester, c);

      final warnings = c.warnings;
      expect(warnings.whereType<DuplicateWarning>().length, 2);
      expect(warnings.whereType<MissingSourceDateWarning>().length, 2);
      expect(warnings.whereType<DigitShortageWarning>().length, 1);
      expect(warnings.length, 5);

      expect(_panel, findsOneWidget);
      // 見出し 1 行 + 警告 1 件につき 1 行。
      expect(_panelTexts(), findsNWidgets(warnings.length + 1));
      for (var i = 0; i < warnings.length; i++) {
        expect(find.byKey(renameWarningRowKey(i)), findsOneWidget);
      }
      // 対象ファイルは行ごとに識別できる(重複 + 基準日時不明で 1 ファイル 2 行)。
      expect(_inPanel(find.textContaining('alpha.jpg')), findsNWidgets(2));
      expect(_inPanel(find.textContaining('bravo.jpg')), findsNWidgets(2));
      // 種別ごとの手掛かりもそれぞれ残っている。
      expect(_inPanel(find.textContaining('作成日時が不明')), findsNWidgets(2));
      expect(_inPanel(find.textContaining('3 桁必要')), findsOneWidget);
    });

    testWidgets('見出しは件数と種別の内訳を常に示し、タップで 1 件 1 行の内訳を開閉する', (tester) async {
      final c = FileListController(
        files: [_noCreatedAt('alpha.jpg'), _noCreatedAt('bravo.jpg')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
          SequenceToken(start: 100, digits: 1, increment: 0),
        ]),
      );
      await _pump(tester, c);

      // 畳んだ状態でも「何がいくつ起きているか」は見えている。
      final summary = tester.widget<Text>(find.byKey(renameWarningSummaryKey));
      expect(summary.data, contains('警告 5 件'));
      expect(summary.data, contains('重複 2'));
      expect(summary.data, contains('基準日時なし 2'));
      expect(summary.data, contains('桁不足 1'));
      expect(find.byKey(renameWarningRowKey(0)), findsNothing);

      await _openDetails(tester);
      expect(find.byKey(renameWarningRowKey(0)), findsOneWidget);

      await _openDetails(tester); // もう一度で閉じる
      expect(find.byKey(renameWarningRowKey(0)), findsNothing);
      expect(find.byKey(renameWarningSummaryKey), findsOneWidget);
    });

    testWidgets('同名・別フォルダのときは場所も添えて対象ファイルを見分けられる', (tester) async {
      final c = FileListController(
        files: [
          _f('photo.jpg', location: '/dcim/a'),
          _f('photo.jpg', location: '/dcim/b'),
        ],
        rule: const RenameRule([OriginalNameToken()]),
      );
      await _pumpExpanded(tester, c);

      expect(c.warnings.whereType<DuplicateWarning>().length, 2);
      expect(_inPanel(find.textContaining('/dcim/a')), findsOneWidget);
      expect(_inPanel(find.textContaining('/dcim/b')), findsOneWidget);
    });

    testWidgets('警告の文字色・アイコン・背景は AppColors のセマンティック色を使う', (tester) async {
      final c = FileListController(
        files: [_f('only.txt')],
        rule: RenameRule.empty,
      );
      await _pumpExpanded(tester, c);

      final container = tester.widget<Container>(_panel);
      expect(container.color, AppColors.dark.danger.withValues(alpha: 0.12));

      final texts = tester.widgetList<Text>(_panelTexts()).toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.style?.color, AppColors.dark.danger);
      }
      final icons = tester
          .widgetList<Icon>(_inPanel(find.byType(Icon)))
          .toList();
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(icon.color, AppColors.dark.danger);
      }
    });
  });

  group('REQ-010: 警告が 0 件なら提示しない', () {
    testWidgets('該当が無ければ帯そのものが出ない', (tester) async {
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([
          LiteralToken('img_'),
          SequenceToken(start: 1, digits: 2),
        ]),
      );
      await _pump(tester, c);

      expect(c.warnings, isEmpty);
      expect(_panel, findsNothing);
      expect(find.byKey(renameWarningSummaryKey), findsNothing);
      expect(find.byKey(renameWarningToggleKey), findsNothing);
      expect(find.byKey(renameWarningRowKey(0)), findsNothing);
      expect(find.textContaining('警告'), findsNothing);
    });

    testWidgets('選択を外して警告が消えたら帯も消える', (tester) async {
      // 2 件が同名になる状態から、片方の選択を外すと重複が解消する。
      final files = [_f('alpha.txt'), _f('bravo.txt')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([LiteralToken('same')]),
      );
      await _pumpExpanded(tester, c);
      expect(_panel, findsOneWidget);
      expect(find.byKey(renameWarningRowKey(0)), findsOneWidget);

      c.toggleSelection(files[1]);
      await tester.pump();

      expect(c.warnings, isEmpty);
      expect(_panel, findsNothing);
      expect(find.byKey(renameWarningRowKey(0)), findsNothing);
    });

    testWidgets('ファイルが 0 件でも帯は出ない', (tester) async {
      final c = FileListController(files: const [], rule: RenameRule.empty);
      await _pump(tester, c);

      expect(c.warnings, isEmpty);
      expect(_panel, findsNothing);
    });
  });
}
