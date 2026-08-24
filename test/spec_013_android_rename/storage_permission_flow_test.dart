// 013 VER-001 / VER-003: 全ファイルアクセスの取得導線(REQ-001〜004、INV-002)。
//
// 観点: 権限が無い間は**読み込ませず**、理由の説明と設定導線をその位置に出し続ける。
// **起動しただけでは確認も遷移もしない**。**毎回確認する**(取り消されうるため)。
// 権限が無い状態では **filesystem へ書き込みを試みない**。
//
// 権限判定は port なので、Linux 上で未許可・許可・拒否後・取り消し後をすべて
// 再現できる。**実機の付与・取り消しと設定画面の往復は `013:T08`** が引き受ける
// (`task.md` の宣言表)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/data/rename_exec/occupied_names.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/permission/storage_permission_notice.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 状態を差し替えられる権限 port。**呼ばれた回数と順序を記録する。**
class _FakePermission implements StoragePermissionPort {
  _FakePermission(this.state, {this.canOpenSettings = true});

  StoragePermissionState state;
  bool canOpenSettings;
  int checks = 0;
  int opens = 0;

  /// この `check` を答えた**あと**に移る状態。「読み込んだあとで設定から
  /// 取り消された」を模す(013 REQ-004 が想定している状況)。
  StoragePermissionState? stateAfterNextCheck;

  /// `check` を待たせる。channel 往復に時間がかかる状況を模す。
  Duration checkDelay = Duration.zero;

  @override
  Future<StoragePermissionState> check() async {
    checks++;
    if (checkDelay > Duration.zero) await Future<void>.delayed(checkDelay);
    final current = state;
    if (stateAfterNextCheck != null) {
      state = stateAfterNextCheck!;
      stateAfterNextCheck = null;
    }
    return current;
  }

  @override
  Future<bool> openSettings() async {
    opens++;
    return canOpenSettings;
  }
}

/// 書き込みが起きたら記録する executor。**INV-002 の観測点である。**
class _RecordingExecutor implements RenameExecutor {
  final List<String> calls = [];

  @override
  Future<RenameResult> rename(String handle, String newName) async {
    calls.add('rename $handle -> $newName');
    return Renamed(handle, name: newName);
  }
}

FileEntry _entry(String name, {required String handle}) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 2),
  size: 10,
  sourceHandle: handle,
);

final _pickFiles = find.byKey(const Key('pick-files-button'));
final _notice = find.byKey(const Key('storage-permission-notice'));
final _openSettings = find.byKey(const Key('open-storage-settings'));

Future<void> _pump(
  WidgetTester tester,
  FileSource source,
  FileListController controller,
  StoragePermissionPort permission,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileSourceBar(
          source: source,
          controller: controller,
          permission: permission,
        ),
      ),
    ),
  );
}

void main() {
  group('REQ-002: 起動しただけでは確認も遷移もしない', () {
    testWidgets('最初の描画では権限を確認せず、説明も出さない', (tester) async {
      final permission = _FakePermission(StoragePermissionState.denied);
      await _pump(
        tester,
        FakeFileSource(fileResults: const []),
        FileListController(files: const []),
        permission,
      );

      expect(permission.checks, 0, reason: '起動だけでは確認しない');
      expect(permission.opens, 0, reason: '起動だけでは設定画面を開かない');
      expect(_notice, findsNothing);
      expect(_pickFiles, findsOneWidget, reason: '読み込み導線自体は見えている');
    });
  });

  group('REQ-001: 未許可のあいだは読み込ませず、理由と導線を出す', () {
    testWidgets('読み込もうとすると確認し、種類シートを開かずに説明を出す', (tester) async {
      final permission = _FakePermission(StoragePermissionState.denied);
      final source = FakeFileSource(
        fileResults: [
          Picked([_entry('a.txt', handle: 'h:a')]),
        ],
      );
      final controller = FileListController(files: const []);
      await _pump(tester, source, controller, permission);

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();

      expect(permission.checks, 1, reason: '読み込もうとした時点で確認する');
      expect(
        find.byKey(Key('file-kind-${FileKind.all.name}')),
        findsNothing,
        reason: '種類シートを開かない',
      );
      expect(controller.items, isEmpty, reason: '読み込まない');
      expect(_notice, findsOneWidget);
      expect(
        find.text(StoragePermissionNotice.explanation),
        findsOneWidget,
        reason: 'なぜこの権限が要るかを示す',
      );
      expect(permission.opens, 0, reason: '設定画面を自動で開かない');
    });

    testWidgets('許可されていれば、これまでどおり読み込める', (tester) async {
      final permission = _FakePermission(StoragePermissionState.granted);
      final source = FakeFileSource(
        fileResults: [
          Picked([_entry('a.txt', handle: 'h:a')]),
        ],
      );
      final controller = FileListController(files: const []);
      await _pump(tester, source, controller, permission);

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('file-kind-${FileKind.all.name}')));
      await tester.pumpAndSettle();

      expect(controller.items.map((e) => e.name), ['a.txt']);
      expect(_notice, findsNothing);
    });

    testWidgets('platform に権限の概念が無ければ制限しない(desktop)', (tester) async {
      final permission = _FakePermission(StoragePermissionState.notApplicable);
      final source = FakeFileSource(
        fileResults: [
          Picked([_entry('a.txt', handle: 'h:a')]),
        ],
      );
      final controller = FileListController(files: const []);
      await _pump(tester, source, controller, permission);

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('file-kind-${FileKind.all.name}')));
      await tester.pumpAndSettle();

      expect(controller.items.map((e) => e.name), ['a.txt']);
      expect(_notice, findsNothing);
    });
  });

  group('REQ-003: 拒否されたあとも黙らない', () {
    testWidgets('設定画面は利用者が押したときだけ開く', (tester) async {
      final permission = _FakePermission(StoragePermissionState.denied);
      await _pump(
        tester,
        FakeFileSource(fileResults: const []),
        FileListController(files: const []),
        permission,
      );

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      expect(permission.opens, 0, reason: '説明を出すだけで開かない');

      await tester.tap(_openSettings);
      await tester.pumpAndSettle();
      expect(permission.opens, 1);
    });

    testWidgets('許可して戻ってくると、押し直さなくても説明が消える', (tester) async {
      // **`openSettings` の直後では足りない。** `startActivity` は画面を出しただけで
      // 即座に返るので、その時点ではまだ許可されていない。**利用者が許可して
      // 戻ってきた瞬間**に気づくには app の復帰を見るしかない
      // (独立review attempt 2 の F1)。
      final permission = _FakePermission(StoragePermissionState.denied);
      await _pump(
        tester,
        FakeFileSource(fileResults: const []),
        FileListController(files: const []),
        permission,
      );

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      await tester.tap(_openSettings);
      await tester.pumpAndSettle();
      expect(_notice, findsOneWidget, reason: '開いた時点ではまだ許可されていない');

      // 設定画面で許可し、アプリへ戻ってくる。
      permission.state = StoragePermissionState.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(_notice, findsNothing, reason: '押し直さなくても消える');
    });

    testWidgets('一度も確認していないうちは、復帰しても確認しに行かない', (tester) async {
      // 起動直後の復帰で確認すると、目的を持つ前に権限を問うことになる
      // (013 REQ-002)。
      final permission = _FakePermission(StoragePermissionState.denied);
      await _pump(
        tester,
        FakeFileSource(fileResults: const []),
        FileListController(files: const []),
        permission,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(permission.checks, 0);
      expect(_notice, findsNothing);
    });

    testWidgets('拒否のままなら説明と導線を出し続ける', (tester) async {
      final permission = _FakePermission(StoragePermissionState.denied);
      await _pump(
        tester,
        FakeFileSource(fileResults: const []),
        FileListController(files: const []),
        permission,
      );

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      // 設定画面へ行って、許可せずに戻ってくる。
      await tester.tap(_openSettings);
      await tester.pumpAndSettle();

      expect(_notice, findsOneWidget, reason: '黙らない');
      expect(_openSettings, findsOneWidget, reason: '導線も残す');
    });

    testWidgets('設定画面を開けない端末でも導線を消さず、次の手を示す', (tester) async {
      final permission = _FakePermission(
        StoragePermissionState.denied,
        canOpenSettings: false,
      );
      await _pump(
        tester,
        FakeFileSource(fileResults: const []),
        FileListController(files: const []),
        permission,
      );

      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      await tester.tap(_openSettings);
      await tester.pumpAndSettle();

      expect(_openSettings, findsOneWidget);
      expect(
        find.byKey(const Key('storage-settings-unavailable')),
        findsOneWidget,
      );
    });
  });

  group('REQ-004: 一度確認した結果を持ち回らない', () {
    testWidgets('読み込みのたびに確認する(途中で取り消されたら止まる)', (tester) async {
      final permission = _FakePermission(StoragePermissionState.granted);
      final source = FakeFileSource(
        fileResults: [
          Picked([_entry('a.txt', handle: 'h:a')]),
          Picked([_entry('b.txt', handle: 'h:b')]),
        ],
      );
      final controller = FileListController(files: const []);
      await _pump(tester, source, controller, permission);

      // 1回目は許可されている。読み込んだあと、設定から取り消される。
      permission.stateAfterNextCheck = StoragePermissionState.denied;
      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('file-kind-${FileKind.all.name}')));
      await tester.pumpAndSettle();
      expect(controller.items.map((e) => e.name), ['a.txt']);

      // 2回目は取り消されているので読み込めない。
      await tester.tap(_pickFiles);
      await tester.pumpAndSettle();

      expect(permission.checks, 2, reason: '毎回確認する');
      expect(controller.items.map((e) => e.name), ['a.txt'], reason: '置き換わらない');
      expect(_notice, findsOneWidget);
    });
  });

  group('INV-002 / VER-003: 権限が無い状態でfilesystemへ書き込まない', () {
    test('実行を起動しても executor を1度も呼ばない', () async {
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NameListFailed(
          const PickError(PickErrorKind.permissionDenied, '未許可'),
        ),
        permission: _FakePermission(StoragePermissionState.denied),
      );
      addTearDown(controller.dispose);

      final outcome = await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );

      expect(outcome, isNull, reason: '実行しない');
      expect(controller.permissionDenied, isTrue, reason: '理由を提示できる形で止まる');
      expect(executor.calls, isEmpty, reason: '**書き込みを1件も試みない**');
    });

    test('許可されていれば実行する(未許可の判定が過剰でない)', () async {
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: _FakePermission(StoragePermissionState.granted),
      );
      addTearDown(controller.dispose);

      final outcome = await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );

      expect(outcome, isNotNull);
      expect(controller.permissionDenied, isFalse);
      expect(executor.calls, isNotEmpty);
    });

    test('権限不足で断っても、前回のundoを消さない', () async {
      // 何もしていないのに戻せなくなるのは、利用者から見て実体の損失に近い。
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final permission = _FakePermission(StoragePermissionState.granted);
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: permission,
      );
      addTearDown(controller.dispose);

      permission.stateAfterNextCheck = StoragePermissionState.denied;
      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      expect(controller.canUndo, isTrue, reason: '1回目は成功したので戻せる');

      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );

      expect(controller.permissionDenied, isTrue);
      expect(controller.canUndo, isTrue, reason: '断っただけなので戻せるまま');
    });

    test('二重起動を許さない(権限確認の待ちを門の外に置かない)', () async {
      // 権限確認を `_running` より前に置くと、その待ちの間に2回目が通り抜ける
      // (005 REQ-012)。**実体を二重に変更しうる。**
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: _FakePermission(StoragePermissionState.granted),
      );
      addTearDown(controller.dispose);

      final first = controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      final second = controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );

      expect(await second, isNull, reason: '2回目は始めない');
      expect(await first, isNotNull);
      expect(executor.calls, hasLength(1));
    });

    test('新しい実行のundo期限が、前回の残り時間で切れない', () async {
      // `_clearUndo()` を落とすと**前回のtimerが生き残り**、2回目のundoを
      // 期限前に消してしまう。利用者から見ると「戻せるはずが戻せない」。
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      // **毎回名前が変わるルール**にする。同じ名前だと2回目は改名が起きず、
      // undo の対象にならない。
      files.setRule(const RenameRule([OriginalNameToken(), LiteralToken('x')]));
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: _FakePermission(StoragePermissionState.granted),
        undoWindow: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      // 2回目から 200ms。2回目の期限(300ms)にはまだ届かないが、
      // 1回目の期限(通算 300ms)は過ぎている。
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(controller.canUndo, isTrue, reason: '2回目のundoは生きている');
    });

    test('undo も権限を確認する(戻す方向も書き込みである)', () async {
      // 実行後に権限を取り消されても undo の提示は期限まで残る(断っても undo を
      // 消さないと決めたため)。**押された時点で確かめないと、権限が無いのに
      // 書き込む**(013 INV-002。独立review attempt 1 の P1-1)。
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final permission = _FakePermission(StoragePermissionState.granted);
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: permission,
      );
      addTearDown(controller.dispose);

      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      expect(controller.canUndo, isTrue);
      final afterExecute = executor.calls.length;

      // 設定から取り消される。
      permission.state = StoragePermissionState.denied;
      final undone = await controller.undo();

      expect(undone, isNull, reason: '戻さない');
      expect(controller.permissionDenied, isTrue, reason: '理由を提示できる形で断る');
      expect(executor.calls.length, afterExecute, reason: '**書き込みを1件も試みない**');
      expect(controller.canUndo, isTrue, reason: '権限が戻れば期限内はまだ戻せる');
    });

    test('権限が戻れば undo できる(断り方が過剰でない)', () async {
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final permission = _FakePermission(StoragePermissionState.granted);
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: permission,
      );
      addTearDown(controller.dispose);

      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      permission.state = StoragePermissionState.denied;
      await controller.undo();
      permission.state = StoragePermissionState.granted;
      final undone = await controller.undo();

      expect(undone, isNotNull);
      expect(controller.permissionDenied, isFalse);
    });

    test('権限確認の待ちの間に期限が切れたら、undoしない', () async {
      // `check()` は channel 往復を含むので、その待ちの間に期限が切れうる
      // (独立review attempt 3 の F3)。**期限を読み直さないと、切れたあとに
      // 実体を書き換える。**
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final permission = _FakePermission(StoragePermissionState.granted);
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: permission,
        undoWindow: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);

      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      final afterExecute = executor.calls.length;
      expect(controller.canUndo, isTrue);

      // 期限内に押すが、権限確認の往復が期限をまたぐ。
      permission.checkDelay = const Duration(milliseconds: 300);
      final undone = await controller.undo();

      expect(undone, isNull, reason: '期限が切れているので戻さない');
      expect(executor.calls.length, afterExecute, reason: '**書き込みを1件も試みない**');
    });

    test('実行のたびに確認する(読み込み時の結果を持ち回らない)', () async {
      final executor = _RecordingExecutor();
      final files = FileListController(
        files: [_entry('a.txt', handle: '/tmp/a.txt')],
      );
      files.setRule(const RenameRule([LiteralToken('renamed')]));
      final permission = _FakePermission(StoragePermissionState.granted);
      final controller = RenameExecutionController(
        files: files,
        executor: executor,
        listNames: (_) async => NamesListed(const {}),
        permission: permission,
      );
      addTearDown(controller.dispose);

      // 1回目のあとで取り消される。
      permission.stateAfterNextCheck = StoragePermissionState.denied;
      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );
      final afterFirst = executor.calls.length;

      await controller.execute(
        force: false,
        occupiedNames: OccupiedNames.emptyFor(const [null]),
      );

      expect(permission.checks, 2, reason: '毎回確認する');
      expect(executor.calls.length, afterFirst, reason: '2回目は書き込まない');
      expect(controller.permissionDenied, isTrue);
    });
  });
}
