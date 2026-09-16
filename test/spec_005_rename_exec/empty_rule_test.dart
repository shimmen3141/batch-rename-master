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

FileEntry _file(String name, {DateTime? createdAt, bool selected = true}) =>
    FileEntry(
      name: name,
      createdAt: createdAt,
      selected: selected,
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

  // ------------------------------------------------------------------
  // REQ-019 revision 9.0(008:T17 の改訂。008:T20 で実装)。
  //
  // **0件はルールが空のときだけではない。** ルールは設定されているのに生成後名が
  // 全件で現在名と同じ場合(例22a / 例22b)や、全件が REQ-022 の除外に当たる場合
  // (例21a / 例22d)も0件である。**判定はルールの形ではなく生成後名と現在名の
  // 比較で行う。**
  // ------------------------------------------------------------------
  group('REQ-019: ルールがあっても変更が0件なら実行が始まらない', () {
    /// 実行の門と実体を1組で作る。
    ({
      FileListController files,
      FakeRenameExecutor executor,
      RenameExecutionController execution,
    })
    wire(List<FileEntry> entries, RenameRule rule) {
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

    testWidgets('例22a: [元の名前] だけのルールでは押せず、実体も変わらない', (tester) async {
      final w = wire([
        _file('a.txt'),
        _file('b.txt'),
      ], const RenameRule([OriginalNameToken()]));
      await _pump(tester, w.files, execution: w.execution);

      expect(w.files.changedFileCount, 0);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('rename-action')),
      );
      expect(button.onPressed, isNull, reason: '押せない(REQ-019)');

      await tester.tap(
        find.byKey(const Key('rename-action')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(w.executor.calls, isEmpty);
      expect(w.files.items.map((e) => e.name), ['a.txt', 'b.txt']);
    });

    testWidgets('逆方向: 1件でも名前が変われば押せる', (tester) async {
      final w = wire([
        _file('a.txt'),
        _file('b.txt'),
      ], const RenameRule([OriginalNameToken(), LiteralToken('-x')]));
      await _pump(tester, w.files, execution: w.execution);

      expect(w.files.changedFileCount, 2);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('rename-action')),
      );
      expect(button.onPressed, isNotNull);
    });

    test('例22b: 同じ結果になる別の形のルールも同じ扱いになる', () async {
      // **ルールの形では数えない。** `[元の名前]` + 空の固定文字は、トークンが
      // 2つあってもどのファイルの名前も変えない。
      final w = wire([
        _file('a.txt'),
      ], const RenameRule([OriginalNameToken(), LiteralToken('')]));

      expect(w.files.isRuleEmpty, isFalse, reason: 'ルールは空ではない');
      expect(w.files.changedFileCount, 0);
      expect(await prepareAndExecute(w.execution, force: false), isNull);
      expect(await prepareAndExecute(w.execution, force: true), isNull);
      expect(w.executor.calls, isEmpty);
      expect(w.files.items.single.name, 'a.txt');
    });

    test('例21a / 例22d: 全件が REQ-022 の除外なら強制実行の経路へも入らない', () async {
      // 作成日時が不明な file だけなので、生成後ベース名が全件で空になる。
      final w = wire(
        [_file('a.txt'), _file('b.txt')],
        const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );

      expect(w.files.changedFileCount, 0);
      expect(
        await prepareAndExecute(w.execution, force: true),
        isNull,
        reason: '強制実行でも門を通らない(REQ-019 revision 9.0)',
      );
      expect(w.executor.calls, isEmpty);
      expect(w.files.items.map((e) => e.name), ['a.txt', 'b.txt']);
    });

    test('例22e: 一部だけ変わるなら実行は始まり、変わる件数だけ数える', () async {
      // 5件中 `keep` の2件は作成日時が無くて除外、3件は改名される。
      final w = wire(
        [
          _file('keep1.txt'),
          _file('keep2.txt'),
          _file('c1.txt', createdAt: DateTime(2026, 3, 4)),
          _file('c2.txt', createdAt: DateTime(2026, 3, 5)),
          _file('c3.txt', createdAt: DateTime(2026, 3, 6)),
        ],
        const RenameRule([
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );

      expect(w.files.changedFileCount, 3, reason: '除外される2件は数えない');
      expect(await prepareAndExecute(w.execution, force: false), isNotNull);
      expect(w.executor.calls, hasLength(3), reason: '変更が生じる3件だけが改名される');
      // **強制実行では件数が増えうる。** 同一 folder に空ベース名が2件あると、
      // 自動解決が2件目へ ` (1)` を付けてベース名が空でなくなり、REQ-022 の除外が
      // 解ける(005 REQ-029 の但し書きと同じ差)。ここで見たいのは「一部でも変わる
      // なら実行が始まる」ことなので、自動解決を挟まない経路で数える。
    });

    test('未選択の行は数えない(002 REQ-007)', () async {
      final w = wire([
        _file('a.txt'),
        _file('b.txt'),
      ], const RenameRule([OriginalNameToken(), LiteralToken('-x')]));
      expect(w.files.changedFileCount, 2, reason: '前提: どちらも変わる');

      // **選択の正本は controller である。** `FileEntry.selected` を false にしても
      // `FileListController` は読み込み時に全件を選択集合へ入れるので、ここを
      // 通さないと「未選択」を作れない(空振りになる)。
      w.files.toggleSelection(w.files.items[1]);

      expect(
        w.files.changedFileCount,
        1,
        reason: 'プレビュー対象外の行は「変更が生じるファイル」ではない',
      );
    });

    test('選択が0件なら実行は始まらない', () async {
      final w = wire([
        _file('a.txt'),
      ], const RenameRule([OriginalNameToken(), LiteralToken('-x')]));
      w.files.clearAll();

      expect(w.files.changedFileCount, 0);
      expect(await prepareAndExecute(w.execution, force: false), isNull);
      expect(w.executor.calls, isEmpty);
    });
  });

  group('REQ-020: 警告ではなく未設定を提示する', () {
    testWidgets('空ルールでは警告帯を出さず、未設定の案内を出す', (tester) async {
      // 空ルールでは全ファイルが拡張子だけの名前になり、001 は空名と重複を返す。
      // それらを警告として見せず、未設定として1つの案内にする。
      final files = FileListController(files: [_file('a.txt'), _file('b.txt')]);
      expect(files.warnings, isNotEmpty); // 001 の判定自体は変えない。
      // **ルール設定の導線がある状態で確かめる。** 導線が無い画面では原因の説明が
      // そもそも tree に無く、不在のassertionが空振りする(N-15-1 と同じ型)。
      await _pump(tester, files, onEditRule: () {});

      // **廃止された帯の key の不在では押さえない。** widget が無いから通る状態に
      // なる(008:T15 の独立reviewが安全網の穴 N-15-1 として挙げた)。
      // 行に警告が出ないこと・原因の説明が出ないこと・件数を出さないことを、
      // **現に在る提示に対して**確かめる。
      expect(find.byKey(rowWarningKey), findsNothing);
      // **ルール設定button自体は在るが、警告は載っていない**(008:T20 で
      // ルール単位の警告表示を外した)。**不在のassertionが空振りしないよう、
      // 器が在ることを先に確かめる。**
      expect(find.byKey(const Key('configure-rule')), findsOneWidget);
      expect(find.text('基準日時なし'), findsNothing);
      expect(find.text('桁不足'), findsNothing);
      // 件数も出さない。001 は空名と重複を返しているので「問題なし」は誤りになる。
      expect(find.byKey(warningCountKey), findsNothing);
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
      // 参考designの2行button(見出し + 設定中のルール)へ入れ替わる。
      expect(find.text('命名ルール'), findsOneWidget);
      // **トークンを並べた形である**(008:T20 の要望9)。説明文にしない。
      expect((tester.widget<Text>(find.byKey(ruleSummaryKey))).data, 'x');
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
      // **ルール単位の常設表示はもう無い**(008:T20。開発者の決定「ルールの
      // 警告は無くす」)。**器は在るのに警告が載っていない**ことを確かめる —
      // 器ごと無い状態で通る空振りを避ける(N-15-1 と同じ型)。
      expect(find.byKey(const Key('configure-rule')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('configure-rule')),
          matching: find.text('基準日時なし'),
        ),
        findsNothing,
      );
      // **種別が読めなくなったわけではない。** 行が出している。
      expect(
        find.descendant(
          of: find.byKey(rowWarningKey),
          matching: find.textContaining('作成日時不明'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(warningCountKey));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(warningDetailCausesKey),
          matching: find.textContaining('2 番目のトークン'),
        ),
        findsOneWidget,
      );
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
