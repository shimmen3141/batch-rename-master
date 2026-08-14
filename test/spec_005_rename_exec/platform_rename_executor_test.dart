// VER-001 / VER-007: platform adapter の実ファイル作用と SAF 契約。
import 'dart:io';

import 'package:batch_rename_master/data/rename_exec/desktop_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:batch_rename_master/data/rename_exec/platform_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/saf_rename_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DesktopRenameExecutor.setModifiedAt (VER-006 / REQ-016)', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('desktop-mtime-');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('実ファイルの更新日時を書き換え、成功なら null を返す', () async {
      final file = File(p.join(directory.path, 'a.txt'));
      await file.writeAsString('x');
      final target = DateTime(2021, 2, 3, 4, 5, 6);

      final error = await DesktopRenameExecutor().setModifiedAt(
        file.path,
        target,
      );

      expect(error, isNull);
      expect(await file.lastModified(), target);
    });

    test('対象が無ければ例外を投げず、理由つきの失敗を返す(REQ-017)', () async {
      final missing = p.join(directory.path, 'missing.txt');

      final error = await DesktopRenameExecutor().setModifiedAt(
        missing,
        DateTime(2021),
      );

      expect(error, isNotNull);
      expect(error!.kind, RenameErrorKind.notFound);
      expect(error.message, contains('更新日時を設定できません'));
    });

    test('FileSystemException 以外の例外も外へ出さない(REQ-016)', () async {
      // port は「例外を投げない」と約束している。想定外の例外が漏れると、
      // 呼び出し側の更新日時ずらしが実行ごと止まる。
      final executor = DesktopRenameExecutor(
        setModifiedAt: (path, value) async => throw StateError('想定外'),
      );

      final error = await executor.setModifiedAt('/any/path', DateTime(2021));

      expect(error, isNotNull);
      expect(error!.kind, RenameErrorKind.unknown);
    });

    test('権限の失敗は permissionDenied として分類する', () async {
      final executor = DesktopRenameExecutor(
        setModifiedAt: (path, value) async =>
            throw PathAccessException(path, const OSError('denied', 13)),
      );

      final error = await executor.setModifiedAt('/any/path', DateTime(2021));

      expect(error!.kind, RenameErrorKind.permissionDenied);
    });
  });

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

    test('原子的no-replaceが効かなくても、実在確認で上書きを止める(REQ-025)', () async {
      // フラグを受け付けながら黙って無視する環境を模す。native rename を
      // 「常に成功する上書き rename」に差し替えても、実在確認が先に止める。
      // **アプリはこの環境を他と区別できない**ので、原子的no-replaceがあっても
      // 確認を省いてはならない。
      final source = File(p.join(directory.path, 'before.txt'));
      final occupied = File(p.join(directory.path, 'after.txt'));
      await source.writeAsString('source-content');
      await occupied.writeAsString('occupied-content');

      var nativeCalled = false;
      final executor = DesktopRenameExecutor(
        rename: (from, to) async {
          nativeCalled = true;
          await File(from).rename(to); // 上書きする(危険な環境)
          return NativeRenameResult.success;
        },
      );

      final result = await executor.rename(source.path, 'after.txt');

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(nativeCalled, isFalse, reason: '実在確認で止めるので native を呼ばない');
      expect(await occupied.readAsString(), 'occupied-content');
      expect(await source.readAsString(), 'source-content');
    });

    test('大文字小文字だけの改名は、自分自身との衝突として扱わない(REQ-025)', () async {
      // 大文字小文字を区別しないfilesystemでは、目標名が「実在する」ことになる。
      // **それは自分自身である。** `FileSystemEntity.identical` がfilesystemへ
      // 問い合わせて判定するので、case感度をアプリ側で推測しない。
      //
      // **Linux(case-sensitive)ではこのtestは自己衝突の分岐を通らない** —
      // 目標名が実在しないので、通常の改名として成功する。case-insensitiveな
      // filesystemでの回帰ガードである。
      //
      // **自己衝突の分岐そのものは、次のhard linkのtestがLinuxで能動的に検査する。**
      final source = File(p.join(directory.path, 'Photo.jpg'));
      await source.writeAsString('kept-content');

      final result = await DesktopRenameExecutor().rename(
        source.path,
        'photo.jpg',
      );

      expect(result, isA<Renamed>(), reason: '衝突として扱わない');
      final renamed = result as Renamed;
      expect(await File(renamed.newHandle).readAsString(), 'kept-content');
    });

    test('目標名に別の実体があれば nameConflict を返す(REQ-025 / INV-002)', () async {
      // 上のtestの裏。**「実在する」だけで通してはならない。**
      final source = File(p.join(directory.path, 'Photo.jpg'));
      final other = File(p.join(directory.path, 'photo.jpg'));
      await source.writeAsString('source-content');
      await other.writeAsString('other-content');

      final result = await DesktopRenameExecutor().rename(
        source.path,
        'photo.jpg',
      );

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await other.readAsString(), 'other-content');
      expect(await source.readAsString(), 'source-content');
    });

    test('目標名が hard link なら、同じ実体でも衝突として扱う(REQ-025 / INV-003)', () async {
      // `FileSystemEntity.identical` が答えるのは「同じ**実体**か」であって
      // 「同じ**directory entry** か」ではない。hard linkは別の名前が同じ
      // inodeを指すので `identical` は true を返すが、それは自分自身ではない。
      //
      // 見逃すと、POSIXの`rename()`が「同じfileの別entry」に対して**何もせず
      // 成功を返す**ため、実体が動いていないのに改名済みとして記録される
      // (INV-003違反)。**この経路はLinuxで再現できる。**
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');
      final link = File(p.join(directory.path, 'b.txt'));
      final result0 = await Process.run('ln', [source.path, link.path]);
      expect(result0.exitCode, 0, reason: 'hard linkを作れること: ${result0.stderr}');

      final result = await DesktopRenameExecutor().rename(source.path, 'b.txt');

      expect(
        (result as RenameFailed).error.kind,
        RenameErrorKind.nameConflict,
        reason: '改名していないのに成功を返してはならない',
      );
      expect(await source.exists(), isTrue);
      expect(await link.exists(), isTrue);
    });

    test('case-insensitiveなfilesystemを模すと、自己衝突は改名として通る(REQ-025)', () async {
      // **Linuxの実FSではこの条件を作れない**(目標名が実在し、同じ実体で、
      // 別entryではない = case/正規化だけの別名)。probeを差し替えて、この機能の
      // 中心にある分岐を能動的に検査する。
      final source = File(p.join(directory.path, 'Photo.jpg'));
      await source.writeAsString('kept-content');

      var exclusiveRenameUsed = false;
      final executor = DesktopRenameExecutor(
        probe: _FakeProbe(
          exists: true,
          sameEntity: true,
          exactEntry: false, // 保存されている名前は 'Photo.jpg' なので一致しない
        ),
        rename: (from, to) async {
          exclusiveRenameUsed = true;
          return NativeRenameResult.nameConflict;
        },
      );

      final result = await executor.rename(source.path, 'photo.jpg');

      expect(result, isA<Renamed>(), reason: '自己衝突を衝突として扱わない');
      expect(
        exclusiveRenameUsed,
        isFalse,
        reason: '排他renameは使わない(macOSのRENAME_EXCLは自己衝突でもEEXISTを返す)',
      );
      expect(
        await File(p.join(directory.path, 'photo.jpg')).readAsString(),
        'kept-content',
      );
    });

    test('同じ実体でも別entryなら衝突として扱う(probe差し替え)', () async {
      // 上のtestの裏。`isSameEntity` が真でも `hasExactEntry` が真なら
      // hard linkであり、自分自身ではない。
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      final executor = DesktopRenameExecutor(
        probe: _FakeProbe(exists: true, sameEntity: true, exactEntry: true),
        rename: (from, to) async => NativeRenameResult.success,
      );

      final result = await executor.rename(source.path, 'b.txt');

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await source.readAsString(), 'kept-content');
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
    test('providerを呼ばず理由付きunsupportedを返す(REQ-017 / INV-002)', () async {
      const executor = SafRenameExecutor();
      const handle = 'content://provider/document/source';

      final first = await executor.rename(handle, 'target.txt');
      final second = await executor.rename(handle, 'target.txt');

      expect(
        (first as RenameFailed).error.kind,
        RenameErrorKind.unsupportedPlatform,
      );
      expect(first.error.message, contains('既存ファイルを置換しない'));
      expect((second as RenameFailed).error.kind, first.error.kind);
      expect(second.error.message, first.error.message);
    });
  });

  test('現在の desktop OS では desktop adapter を構成する', () {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      expect(createPlatformRenameExecutor(), isA<DesktopRenameExecutor>());
    }
  });

  test('Android/iOS native assetはdesktop rename symbolを参照しない', () async {
    final hook = await File('hook/build.dart').readAsString();
    final source = await File('src/native_exclusive_rename.c').readAsString();

    expect(hook, contains('if (!input.config.buildCodeAssets)'));
    expect(hook, contains('final targetOS = input.config.code.targetOS'));
    expect(hook, contains('targetOS == OS.android'));
    expect(hook, contains('targetOS == OS.iOS'));
    expect(hook, contains("'BRM_UNSUPPORTED_PLATFORM': null"));
    expect(source, contains('#if defined(BRM_UNSUPPORTED_PLATFORM)'));
    expect(source, contains('return BRM_RENAME_UNSUPPORTED;'));
  });
}

/// [DesktopPathProbe] の固定応答版。filesystemのcase感度・正規化感度を
/// containerで再現できないため、条件そのものを注入する。
class _FakeProbe implements DesktopPathProbe {
  _FakeProbe({
    required bool exists,
    required this.sameEntity,
    required this.exactEntry,
  }) : existsResult = exists;

  final bool existsResult;
  final bool sameEntity;
  final bool exactEntry;

  @override
  Future<bool> exists(String path) async => existsResult;

  @override
  Future<bool> isSameEntity(String a, String b) async => sameEntity;

  @override
  Future<bool> hasExactEntry(String path) async => exactEntry;
}
