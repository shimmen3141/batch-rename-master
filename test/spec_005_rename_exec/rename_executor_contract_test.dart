// VER-001: RenameExecutor ポート契約(OP-004 / REQ-017 / REQ-018 / REQ-001)。
//
// 観点: 例外を投げず結果型で返すこと、改名のたびにハンドルが変わり古いハンドルが
// 使えなくなること、戻り値の名前が空になりうるので目標名を正とすること。
// fake が本物より親切にならないことを、T8(2026-08-05)の実機スパイクで得た
// 実物の URI 断片で固定する(ADR-001「実機で確認した事実」2・3)。
import 'package:batch_rename_master/data/rename_exec/rename_execution.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// T8 の実機スパイクで実測したドキュメント URI(ADR-001)。
const _realUri =
    'content://com.android.externalstorage.documents/document/'
    'primary%3ADownload%2Frename_test_a%2FIMG_0010.jpg';

/// 同じフォルダで `IMG_0010_t8.jpg` へ改名したときの実測値(ADR-001)。
const _realUriAfterRename =
    'content://com.android.externalstorage.documents/document/'
    'primary%3ADownload%2Frename_test_a%2FIMG_0010_t8.jpg';

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

  test('実機の SAF ドキュメント URI は改名で変わる(REQ-001)', () async {
    final executor = FakeRenameExecutor(
      files: {_realUri: 'IMG_0010.jpg'},
      renamedHandle: safDocumentRenamedHandle,
    );

    final result =
        await executor.rename(_realUri, 'IMG_0010_t8.jpg') as Renamed;

    expect(result.newHandle, _realUriAfterRename);
    expect(result.newHandle, isNot(_realUri));
    // 元の URI は stale になる(ADR-001「実機で確認した事実」2)。
    final stale = await executor.rename(_realUri, 'IMG_0011.jpg');
    expect((stale as RenameFailed).error.kind, RenameErrorKind.notFound);
  });

  test('実機のドキュメント URI 経由では戻り値の名前が空で返る(REQ-018)', () async {
    final executor = FakeRenameExecutor(
      files: {_realUri: 'IMG_0010.jpg'},
      renamedHandle: safDocumentRenamedHandle,
    );

    final result =
        await executor.rename(_realUri, 'IMG_0010_t8.jpg') as Renamed;

    // fake は本物より親切にしない: name は空文字列のまま返る(ADR-001 の 3)。
    expect(result.name, isEmpty);
  });

  test('改名後の名前は戻り値ではなく目標名を正とする(REQ-018)', () async {
    final request = RenameRequest(
      handle: _realUri,
      originalName: 'IMG_0010.jpg',
      targetName: 'IMG_0010_t8.jpg',
    );
    final executor = FakeRenameExecutor(
      files: {_realUri: 'IMG_0010.jpg'},
      renamedHandle: safDocumentRenamedHandle,
    );

    final outcome = await executePlan(planExecution([request]), executor);

    final success = outcome.successes.single;
    expect(success.newName, 'IMG_0010_t8.jpg');
    expect(success.newName, isNotEmpty);
    expect(success.originalName, 'IMG_0010.jpg');
    // ハンドルは改名後の URI へ更新される(REQ-001 / INV-005)。
    expect(success.handle, _realUriAfterRename);
    expect(request.handle, _realUriAfterRename);
  });
}
