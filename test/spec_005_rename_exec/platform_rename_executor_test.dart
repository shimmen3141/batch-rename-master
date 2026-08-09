// VER-001 / VER-007: platform adapter の実ファイル作用と SAF 契約。
import 'dart:io';

import 'package:batch_rename_master/data/rename_exec/desktop_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:batch_rename_master/data/rename_exec/platform_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/saf_rename_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:saf_util/saf_util_platform_interface.dart';

void main() {
  group('DesktopRenameExecutor', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('desktop-rename-');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('実ファイルを改名し、新しい絶対パスを返す(REQ-001 / REQ-017)', () async {
      final source = File(p.join(directory.path, 'before.txt'));
      await source.writeAsString('kept-content');

      final result = await DesktopRenameExecutor().rename(
        source.path,
        'after.txt',
      );

      expect(result, isA<Renamed>());
      final renamed = result as Renamed;
      expect(renamed.newHandle, p.join(directory.absolute.path, 'after.txt'));
      expect(renamed.name, 'after.txt');
      expect(await source.exists(), isFalse);
      expect(await File(renamed.newHandle).readAsString(), 'kept-content');
    });

    test('目標が既存なら上書きせず nameConflict を返す(INV-002)', () async {
      final source = File(p.join(directory.path, 'before.txt'));
      final occupied = File(p.join(directory.path, 'after.txt'));
      await source.writeAsString('source-content');
      await occupied.writeAsString('occupied-content');

      final result = await DesktopRenameExecutor().rename(
        source.path,
        'after.txt',
      );

      final failure = result as RenameFailed;
      expect(
        failure.error.kind,
        RenameErrorKind.nameConflict,
        reason: failure.error.toString(),
      );
      expect(await source.readAsString(), 'source-content');
      expect(await occupied.readAsString(), 'occupied-content');
    });

    test('存在しない対象は例外でなく notFound を返す(REQ-017)', () async {
      final result = await DesktopRenameExecutor().rename(
        p.join(directory.path, 'missing.txt'),
        'after.txt',
      );

      expect((result as RenameFailed).error.kind, RenameErrorKind.notFound);
    });

    test('目標名にパスを含む場合は所在を変えず失敗する(INV-001)', () async {
      final source = File(p.join(directory.path, 'before.txt'));
      await source.writeAsString('kept-content');
      final outside = File(p.join(directory.parent.path, 'moved.txt'));
      if (await outside.exists()) await outside.delete();

      final result = await DesktopRenameExecutor().rename(
        source.path,
        '../moved.txt',
      );

      expect(result, isA<RenameFailed>());
      expect(await source.readAsString(), 'kept-content');
      expect(await outside.exists(), isFalse);
    });

    test('存在確認後に作られた衝突先も原子的に上書きしない(INV-002)', () async {
      final source = File(p.join(directory.path, 'before.txt'));
      final occupied = File(p.join(directory.path, 'after.txt'));
      await source.writeAsString('source-content');
      final executor = DesktopRenameExecutor(
        rename: (sourcePath, destinationPath) async {
          await occupied.writeAsString('racing-content');
          return renameFileWithoutOverwrite(sourcePath, destinationPath);
        },
      );

      final result = await executor.rename(source.path, 'after.txt');

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await source.readAsString(), 'source-content');
      expect(await occupied.readAsString(), 'racing-content');
    });

    test('native wrapperのnotFound結果を安定して返す(REQ-017)', () async {
      final source = File(p.join(directory.path, 'before.txt'));
      await source.writeAsString('source-content');
      final executor = DesktopRenameExecutor(
        rename: (sourcePath, _) async {
          await File(sourcePath).delete();
          return NativeRenameResult.notFound;
        },
      );

      final result = await executor.rename(source.path, 'after.txt');

      expect((result as RenameFailed).error.kind, RenameErrorKind.notFound);
    });

    test(
      'native wrapperのpermission結果をpermissionDeniedへ写像する(REQ-017)',
      () async {
        final source = File(p.join(directory.path, 'before.txt'));
        await source.writeAsString('source-content');
        final executor = DesktopRenameExecutor(
          rename: (_, _) async => NativeRenameResult.permissionDenied,
        );

        final result = await executor.rename(source.path, 'after.txt');

        expect(
          (result as RenameFailed).error.kind,
          RenameErrorKind.permissionDenied,
        );
        expect(await source.readAsString(), 'source-content');
      },
    );

    test('native wrapper自体が存在しないsourceをnotFoundへ変換する(REQ-017)', () {
      final result = renameFileWithoutOverwrite(
        p.join(directory.path, 'missing.txt'),
        p.join(directory.path, 'after.txt'),
      );

      expect(result, NativeRenameResult.notFound);
    });
  });

  group('SafRenameExecutor', () {
    test('プラグインが返した URI を新しいハンドルとして返す(REQ-001)', () async {
      late (String, bool, String) call;
      final executor = SafRenameExecutor(
        rename: (uri, isDir, newName) async {
          call = (uri, isDir, newName);
          return SafDocumentFile(
            uri: '$uri-renamed',
            name: '',
            isDir: false,
            length: 1,
            lastModified: 0,
          );
        },
      );

      final result = await executor.rename('content://old', 'target.txt');

      expect(call, ('content://old', false, 'target.txt'));
      expect((result as Renamed).newHandle, 'content://old-renamed');
      expect(result.name, isEmpty, reason: '空の戻り名も契約上有効(REQ-018)');
    });

    test('プラットフォーム例外は理由付き失敗へ変換する(REQ-017)', () async {
      final executor = SafRenameExecutor(
        rename: (_, _, _) async => throw Exception('Permission denied'),
      );

      final result = await executor.rename('content://old', 'target.txt');

      expect(
        (result as RenameFailed).error.kind,
        RenameErrorKind.permissionDenied,
      );
    });
  });

  test('現在の desktop OS では desktop adapter を構成する', () {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      expect(createPlatformRenameExecutor(), isA<DesktopRenameExecutor>());
    }
  });
}
