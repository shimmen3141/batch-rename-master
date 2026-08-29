// VER-004 / VER-005: ルール未設定時の実行防止、未設定の提示、双方向の復帰、
// および空名と基準日時不明のまとめ提示(REQ-019 / REQ-020 / REQ-021)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'occupied_support.dart';

FileEntry _file(String name, {DateTime? createdAt}) => FileEntry(
  name: name,
  createdAt: createdAt,
  modifiedAt: DateTime(2026, 8, 11),
  size: 1,
  sourceHandle: '/files/$name',
  sourceFolder: '/files',
);

Future<void> _pump(
  WidgetTester tester,
  FileListController files, {
  RenameExecutionController? execution,
  VoidCallback? onEditRule,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(
          controller: files,
          renameExecution: execution,
          onEditRule: onEditRule,
        ),
      ),
    ),
  );
}

void main() {
  group('REQ-019: ルールが空なら実行が始まらない', () {
    testWidgets('実行ボタンは無効で、押しても改名が走らない', (tester) async {
      final files = FileListController(files: [_file('a.txt')]);
      final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
      final execution = RenameExecutionController(
        permission: const UnrestrictedStoragePermission(),
        files: files,
        executor: executor,
        listNames: listNamesOf(executor, folder: '/files'),
      );
      await _pump(tester, files, execution: execution);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('rename-action')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('rename-action')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(executor.calls, isEmpty);
      expect(files.items.single.name, 'a.txt');
    });

    test('ボタンを介さない経路でも実体を1件も変更しない', () async {
      final files = FileListController(files: [_file('a.txt')]);
      final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
      final execution = RenameExecutionController(
        permission: const UnrestrictedStoragePermission(),
        files: files,
        executor: executor,
        listNames: listNamesOf(executor, folder: '/files'),
      );

      expect(await prepareAndExecute(execution, force: false), isNull);
      // 強制実行(自動解決)経路でも同じく止まる。
      expect(await prepareAndExecute(execution, force: true), isNull);
      expect(executor.calls, isEmpty);
      expect(files.items.single.name, 'a.txt');
    });
  });

  group('REQ-020: 警告ではなく未設定を提示する', () {
    testWidgets('空ルールでは警告帯を出さず、未設定の案内を出す', (tester) async {
      // 空ルールでは全ファイルが拡張子だけの名前になり、001 は空名と重複を返す。
      // それらを警告として見せず、未設定として1つの案内にする。
      final files = FileListController(files: [_file('a.txt'), _file('b.txt')]);
      expect(files.warnings, isNotEmpty); // 001 の判定自体は変えない。
      await _pump(tester, files);

      // **廃止された帯の key の不在では押さえない。** widget が無いから通る状態に
      // なる(008:T15 の独立reviewが安全網の穴 N-15-1 として挙げた)。
      // 行に警告が出ないこと・原因の説明が出ないこと・件数が「問題なし」で
      // あることを、**現に在る提示に対して**確かめる。
      expect(find.byKey(rowWarningKey), findsNothing);
      expect(find.byKey(ruleWarningNoticeKey), findsNothing);
      expect(find.text('問題なし'), findsOneWidget);
      expect(find.byKey(ruleNotConfiguredKey), findsOneWidget);
      expect(find.textContaining('命名ルールが未設定'), findsOneWidget);
    });

    testWidgets('トークンが1つ加わると案内が消え、警告の提示に戻る', (tester) async {
      final files = FileListController(files: [_file('a.txt'), _file('b.txt')]);
      await _pump(tester, files);
      expect(find.byKey(ruleNotConfiguredKey), findsOneWidget);

      // 2件とも同じ名前になるルール = 重複警告が出る状態。
      files.setRule(const RenameRule([LiteralToken('same')]));
      await tester.pump();

      expect(find.byKey(ruleNotConfiguredKey), findsNothing);
      expect(find.byKey(rowWarningKey), findsNWidgets(2));
      expect(find.textContaining('名前が重複'), findsNWidgets(2));

      // 空へ戻せば案内へ戻る(両方向を観測する)。
      files.setRule(RenameRule.empty);
      await tester.pump();
      expect(find.byKey(ruleNotConfiguredKey), findsOneWidget);
      expect(find.byKey(rowWarningKey), findsNothing);
    });

    testWidgets('未設定のときはルール設定への導線が主役になる', (tester) async {
      final files = FileListController(files: [_file('a.txt')]);
      var opened = 0;
      await _pump(tester, files, onEditRule: () => opened++);

      expect(find.text('変更する名前を設定する'), findsOneWidget);
      await tester.tap(find.byKey(const Key('configure-rule')));
      await tester.pumpAndSettle();
      expect(opened, 1);

      files.setRule(const RenameRule([LiteralToken('x')]));
      await tester.pump();
      expect(find.text('変更する名前を設定する'), findsNothing);
      expect(find.text('ルールを編集'), findsOneWidget);
    });
  });

  group('REQ-021: 空名と基準日時不明を1件にまとめる', () {
    testWidgets('2行ではなく、結果と原因を1行で提示する', (tester) async {
      // 作成日時トークンだけのルール + 作成日時が不明なファイル。
      // 001 は空名と基準日時不明の2件を返す。
      final files = FileListController(
        files: [_file('shot.png')],
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      expect(files.warnings.whereType<EmptyNameWarning>(), hasLength(1));
      expect(
        files.warnings.whereType<MissingSourceDateWarning>(),
        hasLength(1),
      );

      await _pump(tester, files);

      // **行が出すのは結果だけ**である。(i) 名前が空になること、
      // (ii) そのファイルが改名の対象にならないこと。原因(どのトークンか)は
      // 行に出さない — 該当ファイルが増えても行の内容は増えない。
      final rowText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(rowWarningKey),
              matching: find.byType(Text),
            ),
          )
          .single
          .data!;
      expect(rowText, contains('空')); // (i) 結果
      expect(rowText, contains('改名されません')); // (ii) 結果
      expect(rowText, isNot(contains('トークン'))); // 原因は行に出さない

      // 詳細には結果と原因が 1 件としてまとまって出る(001 の 2 件を 1 件へ)。
      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      final detail = find.byKey(warningDetailDialogKey);
      expect(detail, findsOneWidget);
      expect(find.textContaining('1 件の問題'), findsWidgets);
      final merged = tester
          .widgetList<Text>(
            find.descendant(
              of: detail,
              matching: find.textContaining('shot.png'),
            ),
          )
          .single
          .data!;
      expect(merged, contains('名前が空になります')); // 結果
      expect(merged, contains('基準日時が取れない')); // 原因
      expect(merged, contains('1 番目のトークン')); // どのトークンか
    });

    testWidgets('片方だけのときは従来どおり個別に提示する', (tester) async {
      // 元名トークンを足すことで名前は空にならないが、基準日時は取れないまま。
      final files = FileListController(
        files: [_file('shot.png')],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
      expect(files.warnings.whereType<EmptyNameWarning>(), isEmpty);

      await _pump(tester, files, onEditRule: () {});

      // 行には種別が出る(REQ-021 規則1 の対象外。005 例20g)。
      expect(find.byKey(rowWarningKey), findsOneWidget);
      // 原因の説明は**ルールを直す側**へ 1 つだけ出る。
      expect(find.byKey(ruleWarningNoticeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ruleWarningNoticeKey),
          matching: find.textContaining('2 番目のトークン'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('基準日時なし 1 件'), findsOneWidget);
    });
  });

  testWidgets('アクションバーはファイル一覧より下に描画する', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('x')]),
    );
    // 観測元と実体を同じ instance にする。別々にすると、実行で名前が変わっても
    // lister は古い名前を返し続け、fixture が実体とずれる。
    final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
    final execution = RenameExecutionController(
      permission: const UnrestrictedStoragePermission(),
      files: files,
      executor: executor,
      listNames: listNamesOf(executor, folder: '/files'),
    );
    await _pump(tester, files, execution: execution, onEditRule: () {});

    final listBottom = tester
        .getBottomLeft(find.byType(ReorderableListView))
        .dy;
    expect(
      tester.getTopLeft(find.byKey(const Key('configure-rule'))).dy,
      greaterThanOrEqualTo(listBottom),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('rename-action'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('configure-rule'))).dy,
      ),
    );
  });
}
