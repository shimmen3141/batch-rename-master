// 008:T14 実行前確認dialogと再採番の結果の詳細の見せ方。
//
// **判定は 005 / 001 のまま**(確認を挟むか、強制実行で何が起きるか)。ここで固定する
// のは「何を聞かれていて、選ぶと何が起きるか」が種類ごとに読めることと、件数が
// 多くても見出しとbuttonが画面に残ることである。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/ui/common/app_toast.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/rename_confirmation_view.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'occupied_support.dart';

FileEntry _file(String name, {DateTime? createdAt}) => FileEntry(
  name: name,
  createdAt: createdAt,
  modifiedAt: DateTime(2026, 8, 9),
  size: 1,
  sourceHandle: '/files/$name',
  sourceFolder: '/files',
);

const _created = DateTimeToken(
  source: DateTimeSource.created,
  format: 'yyyyMMdd',
);

Future<void> _pump(
  WidgetTester tester,
  FileListController files,
  RenameExecutionController execution, {
  Size size = const Size(360, 720),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: FileListView(controller: files, renameExecution: execution),
      ),
    ),
  );
}

RenameExecutionController _execution(
  FileListController files,
  FakeRenameExecutor executor,
) => RenameExecutionController(
  permission: const UnrestrictedStoragePermission(),
  files: files,
  executor: executor,
  listNames: listNamesOf(executor, folder: '/files'),
);

Finder _inDialog(Finder matching) => find.descendant(
  of: find.byKey(renameConfirmationDialogKey),
  matching: matching,
);

void main() {
  group('confirmationIssues: 種類ごとに1つ、実行すると何が起きるかを添える', () {
    test('重複は件数ぶん行を増やさず1つにまとめ、末尾へ (n) を付けると書く', () {
      final files = [for (var i = 0; i < 30; i++) _file('f$i.jpg')];
      final warnings = validate(
        const RenameRule([LiteralToken('same')]),
        files,
        DateTime(2026, 10, 2),
      );
      final issues = confirmationIssues(warnings);
      expect(issues, hasLength(1));
      expect(issues.single.title, '重複 30 件');
      expect(issues.single.consequence, contains('(1) (2)'));
      expect(issues.single.targets, hasLength(30));
      expect(confirmationActionLabel(issues), '自動解決して実行');
      expect(
        confirmationDescription(warnings),
        startsWith('30 件のファイルに問題があります。'),
      );
    });

    test('名前が空になるファイルは「改名しない」とし、同じファイルの日時不明を別に数えない', () {
      // a: 作成日時が無い → 名前が空(REQ-022 で除外)。b: 作成日時がある → 正常。
      final files = [
        _file('a.jpg'),
        _file('b.jpg', createdAt: DateTime(2026, 1, 1)),
      ];
      final warnings = validate(
        const RenameRule([_created]),
        files,
        DateTime(2026, 10, 2),
      );
      expect(warnings.whereType<MissingSourceDateWarning>(), isNotEmpty);
      final issues = confirmationIssues(warnings);
      expect(issues.map((i) => i.title), ['名前が空 1 件']);
      expect(issues.single.consequence, contains('改名しません'));
      // 何も解決しないので「自動解決」と書かない。
      expect(confirmationActionLabel(issues), 'このまま実行');
    });

    test('日時不明だけなら「その部分を空にして改名」と書く', () {
      final files = [
        _file('a.jpg'),
        _file('b.jpg', createdAt: DateTime(2026, 1, 1)),
      ];
      final warnings = validate(
        const RenameRule([OriginalNameToken(), _created]),
        files,
        DateTime(2026, 10, 2),
      );
      final issues = confirmationIssues(warnings);
      expect(issues.map((i) => i.title), ['作成日時不明 1 件']);
      expect(issues.single.consequence, contains('空にして改名します'));
      expect(issues.single.targets, ['「a.jpg」']);
      expect(confirmationActionLabel(issues), 'このまま実行');
    });

    test('桁不足は(UIから届かなくても)必要な桁数へ広げると書く', () {
      final issues = confirmationIssues(const [
        DigitShortageWarning(
          tokenIndex: 0,
          token: SequenceToken(digits: 1),
          requiredDigits: 3,
        ),
      ]);
      expect(issues.single.title, '桁不足');
      expect(issues.single.consequence, contains('3 桁'));
      expect(issues.single.targets, isEmpty);
      expect(confirmationActionLabel(issues), '自動解決して実行');
    });
  });

  testWidgets('確認dialogは何を聞いているかと、実行すると何が起きるかを示す(REQ-011)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt'), _file('b.txt')],
      rule: const RenameRule([LiteralToken('same')]),
    );
    final executor = FakeRenameExecutor(
      files: {'/files/a.txt': 'a.txt', '/files/b.txt': 'b.txt'},
    );
    final execution = _execution(files, executor);
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();

    expect(_inDialog(find.text('実行前の確認')), findsOneWidget);
    expect(
      _inDialog(find.textContaining('このまま実行すると、次のように処理します')),
      findsOneWidget,
    );
    expect(_inDialog(find.byKey(confirmationIssueKey(0))), findsOneWidget);
    expect(_inDialog(find.byKey(confirmationIssueKey(1))), findsNothing);
    expect(_inDialog(find.text('重複 2 件')), findsOneWidget);
    // 実行は警告を押し切る操作だと色で見分けられる。
    final force = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(renameForceKey),
        matching: find.byType(TextButton),
      ),
    );
    final colors = appDarkTheme().extension<AppColors>()!;
    expect(force.style!.backgroundColor!.resolve({}), colors.danger);
    expect(
      find.descendant(
        of: find.byKey(renameForceKey),
        matching: find.text('自動解決して実行'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(renameForceKey));
    await tester.pumpAndSettle();
    expect(executor.calls, hasLength(2), reason: '自動解決した名前で2件とも改名する');
    execution.dispose();
  });

  testWidgets('件数が多く文字が大きくても、見出しとbuttonは画面に残る', (tester) async {
    final names = [for (var i = 0; i < 60; i++) 'photo_$i.jpg'];
    final files = FileListController(
      files: [for (final n in names) _file(n)],
      rule: const RenameRule([LiteralToken('same')]),
    );
    final executor = FakeRenameExecutor(
      files: {for (final n in names) '/files/$n': n},
    );
    final execution = _execution(files, executor);
    await _pump(
      tester,
      files,
      execution,
      size: const Size(320, 640),
      textScale: 1.6,
    );

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final screen = Offset.zero & const Size(320, 640);
    for (final key in [renameCancelKey, renameForceKey]) {
      final rect = tester.getRect(find.byKey(key));
      expect(screen.contains(rect.topLeft), isTrue, reason: '$key');
      expect(screen.contains(rect.bottomRight), isTrue, reason: '$key');
    }
    final title = tester.getRect(_inDialog(find.text('実行前の確認')));
    expect(screen.contains(title.topLeft), isTrue);

    await tester.tap(find.byKey(renameCancelKey));
    await tester.pumpAndSettle();
    expect(executor.calls, isEmpty);
    execution.dispose();
  });

  testWidgets('押した時点で変更が0件なら、確認も占有名の取得もしない(REQ-019。008:T20 の F5)', (
    tester,
  ) async {
    // **画面の門(`_request`)を外すと落ちる**ことを固定する。button は0件で無効に
    // なるが、押せた callback が古いまま呼ばれる(build と押下の間にルールが変わる)と
    // 画面の門だけが止める — controller の門は確認dialogより後にしか効かない。
    final files = FileListController(
      files: [_file('a.jpg')],
      rule: const RenameRule([OriginalNameToken(), LiteralToken('_x')]),
    );
    final executor = FakeRenameExecutor(files: {'/files/a.jpg': 'a.jpg'});
    final listed = <String>[];
    final execution = RenameExecutionController(
      permission: const UnrestrictedStoragePermission(),
      files: files,
      executor: executor,
      listNames: (folder) {
        listed.add(folder);
        return listNamesOf(executor, folder: '/files')(folder);
      },
    );
    await _pump(tester, files, execution);
    final stale = tester
        .widget<ButtonStyleButton>(find.byKey(const Key('rename-action')))
        .onPressed!;

    // 作成日時が無いので名前が空になる: 変更0件、警告はある(確認へ入りうる状態)。
    files.setRule(const RenameRule([_created]));
    expect(files.hasChangedFiles, isFalse);
    expect(files.warnings, isNotEmpty);
    stale();
    await tester.pumpAndSettle();

    expect(find.byKey(renameConfirmationDialogKey), findsNothing);
    expect(listed, isEmpty, reason: '実行を始めないので占有名も取り直さない');
    expect(executor.calls, isEmpty);
    execution.dispose();
  });

  group('再採番の結果(REQ-024)', () {
    Future<RenameExecutionController> runWithRenumbering(
      WidgetTester tester, {
      int count = 1,
    }) async {
      final files = FileListController(
        files: [for (var i = 0; i < count; i++) _file('f$i.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_x')]),
      );
      final fired = <String>{};
      final executor = FakeRenameExecutor(
        files: {for (var i = 0; i < count; i++) '/files/f$i.txt': 'f$i.txt'},
        failWhen: (handle, newName) {
          final key = handle.split('/').last;
          if (!fired.add(key)) return null;
          return const RenameError(RenameErrorKind.nameConflict, '注入');
        },
      );
      final execution = _execution(files, executor);
      await _pump(tester, files, execution);
      await tester.tap(find.byKey(const Key('rename-action')));
      await tester.pumpAndSettle();
      return execution;
    }

    testWidgets('通知は閉じるまで残り、「元に戻す」だけが期限で消える', (tester) async {
      final execution = await runWithRenumbering(tester);
      expect(find.textContaining('1 件の名前が変わりました'), findsOneWidget);
      expect(find.byKey(const Key('rename-undo')), findsOneWidget);

      await tester.pump(execution.undoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      // 詳細を開く前に消えると、どの名前になったかを読めない。
      expect(find.textContaining('1 件の名前が変わりました'), findsOneWidget);
      expect(find.byKey(renumberedDetailLinkKey), findsOneWidget);
      // 押しても何も起きない「元に戻す」を残さない(REQ-007)。
      expect(find.byKey(const Key('rename-undo')), findsNothing);

      await tester.tap(find.byKey(toastCloseKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 件の名前が変わりました'), findsNothing);
      execution.dispose();
    });

    testWidgets('件数が多くても、通知は伸びず、詳細のdialogで全件を読める', (tester) async {
      final execution = await runWithRenumbering(tester, count: 12);
      // 通知には名前を並べない。
      expect(find.textContaining(' → '), findsNothing);

      await tester.tap(find.byKey(renumberedDetailLinkKey));
      await tester.pumpAndSettle();
      final dialog = find.byKey(renumberedDetailDialogKey);
      expect(dialog, findsOneWidget);
      for (var i = 0; i < 12; i++) {
        expect(
          find.descendant(
            of: dialog,
            matching: find.byKey(
              renumberedDetailRowKey(i),
              skipOffstage: false,
            ),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining(
            'f0_x.txt → f0_x (1).txt',
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      // 閉じるbuttonは画面に残る。
      final screen = Offset.zero & const Size(360, 720);
      final close = tester.getRect(find.byKey(renumberedDetailCloseKey));
      expect(screen.contains(close.bottomRight), isTrue);

      await tester.tap(find.byKey(renumberedDetailCloseKey));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      // 詳細を閉じても通知は残り、もう一度開ける。
      expect(find.byKey(renumberedDetailLinkKey), findsOneWidget);
      execution.dispose();
    });

    testWidgets('再採番が無い結果は、これまでどおり期限で消える', (tester) async {
      final files = FileListController(
        files: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('renamed')]),
      );
      final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
      final execution = _execution(files, executor);
      await _pump(tester, files, execution);
      await tester.tap(find.byKey(const Key('rename-action')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 件を改名しました'), findsOneWidget);
      expect(find.byKey(renumberedDetailLinkKey), findsNothing);

      await tester.pump(execution.undoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 件を改名しました'), findsNothing);
      execution.dispose();
    });
  });
}
