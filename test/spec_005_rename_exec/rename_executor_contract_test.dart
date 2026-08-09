// VER-001: RenameExecutor ポート契約(OP-004 / REQ-017 / REQ-018 / REQ-001)。
//
// 観点: 例外を投げず結果型で返すこと、改名のたびにハンドルが変わり古いハンドルが
// 使えなくなること、戻り値の名前が空になりうるので目標名を正とすること。
// Android SAF productionはrevision 2で安全な未対応となる。ここではdesktopや
// 将来の安全な境界を含むport一般の許容値域として、opaque handleの変化と空名を扱う。
import 'package:batch_rename_master/data/rename_exec/rename_execution.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const _opaqueHandle = 'opaque://provider/item/42';
const _opaqueHandleAfterRename = 'opaque://provider/item/84';

String _changedOpaqueHandle(String _, String _) => _opaqueHandleAfterRename;

void main() {
  test('rename は成功時に改名後のハンドルを返す(OP-004)', () async {
    final executor = FakeRenameExecutor(files: {'/photos/a.jpg': 'a.jpg'});

    final result = await executor.rename('/photos/a.jpg', 'b.jpg');

    expect(result, isA<Renamed>());
    expect((result as Renamed).newHandle, '/photos/b.jpg');
    expect(executor.names, ['b.jpg']);
  });

  test('rename は例外を投げず、理由つきの失敗を返す(REQ-017)', () async {
    final executor = FakeRenameExecutor(
      files: {'/photos/a.jpg': 'a.jpg', '/photos/b.jpg': 'b.jpg'},
      failWhen: (handle, newName) => newName == 'denied.jpg'
          ? const RenameError(RenameErrorKind.permissionDenied, '権限がありません')
          : null,
    );

    final denied = await executor.rename('/photos/a.jpg', 'denied.jpg');
    final missing = await executor.rename('/photos/zzz.jpg', 'x.jpg');
    final conflict = await executor.rename('/photos/a.jpg', 'b.jpg');

    expect(
      (denied as RenameFailed).error.kind,
      RenameErrorKind.permissionDenied,
    );
    expect(denied.error.message, '権限がありません');
    expect((missing as RenameFailed).error.kind, RenameErrorKind.notFound);
    expect((conflict as RenameFailed).error.kind, RenameErrorKind.nameConflict);
    // 失敗時、実体は変化しない(OP-004 の事後条件)。
    expect(executor.names, unorderedEquals(['a.jpg', 'b.jpg']));
  });

  test('未対応プラットフォームは失敗を返す(REQ-017)', () async {
    const executor = UnsupportedRenameExecutor();

    final result = await executor.rename('/photos/a.jpg', 'b.jpg');

    expect(result, isA<RenameFailed>());
    expect(
      (result as RenameFailed).error.kind,
      RenameErrorKind.unsupportedPlatform,
    );
  });

  test('改名すると古いハンドルは使えなくなる(REQ-001)', () async {
    final executor = FakeRenameExecutor(files: {'/photos/a.jpg': 'a.jpg'});

    final first = await executor.rename('/photos/a.jpg', 'b.jpg') as Renamed;
    final stale = await executor.rename('/photos/a.jpg', 'c.jpg');
    final withNewHandle = await executor.rename(first.newHandle, 'c.jpg');

    expect((stale as RenameFailed).error.kind, RenameErrorKind.notFound);
    expect(withNewHandle, isA<Renamed>());
    expect(executor.names, ['c.jpg']);
  });

  test('成功可能なportではopaque handleが改名で変わりうる(REQ-001)', () async {
    final executor = FakeRenameExecutor(
      files: {_opaqueHandle: 'IMG_0010.jpg'},
      renamedHandle: _changedOpaqueHandle,
    );

    final result =
        await executor.rename(_opaqueHandle, 'IMG_0010_t8.jpg') as Renamed;

    expect(result.newHandle, _opaqueHandleAfterRename);
    expect(result.newHandle, isNot(_opaqueHandle));
    final stale = await executor.rename(_opaqueHandle, 'IMG_0011.jpg');
    expect((stale as RenameFailed).error.kind, RenameErrorKind.notFound);
  });

  test('成功可能なportの戻り値名は空でもよい(REQ-018)', () async {
    final executor = FakeRenameExecutor(
      files: {_opaqueHandle: 'IMG_0010.jpg'},
      renamedHandle: _changedOpaqueHandle,
    );

    final result =
        await executor.rename(_opaqueHandle, 'IMG_0010_t8.jpg') as Renamed;

    expect(result.name, isEmpty);
  });

  test('改名後の名前は戻り値ではなく目標名を正とする(REQ-018)', () async {
    final request = RenameRequest(
      handle: _opaqueHandle,
      originalName: 'IMG_0010.jpg',
      targetName: 'IMG_0010_t8.jpg',
    );
    final executor = FakeRenameExecutor(
      files: {_opaqueHandle: 'IMG_0010.jpg'},
      renamedHandle: _changedOpaqueHandle,
    );

    final outcome = await executePlan(planExecution([request]), executor);

    final success = outcome.successes.single;
    expect(success.newName, 'IMG_0010_t8.jpg');
    expect(success.newName, isNotEmpty);
    expect(success.originalName, 'IMG_0010.jpg');
    expect(success.handle, _opaqueHandleAfterRename);
    expect(request.handle, _opaqueHandleAfterRename);
  });
}
