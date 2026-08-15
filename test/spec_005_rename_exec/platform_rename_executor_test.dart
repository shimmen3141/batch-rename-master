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

    test('case-only改名は一時名を経由して通る(REQ-025)', () async {
      // **判定しない。** 目標名が実在しても、一時名を経由すれば自分自身かどうかが
      // 分かる。1段目で元の名前が空くので、自分自身なら2段目が通る。
      //
      // Linuxのcontainerではcase-insensitiveなFSを作れないので、
      // 「目標名が実在する」という条件だけを注入して経路を通す。
      final source = File(p.join(directory.path, 'Photo.jpg'));
      await source.writeAsString('kept-content');

      final calls = <String>[];
      final executor = DesktopRenameExecutor(
        probe: const _AlwaysExists(),
        rename: (from, to) async {
          calls.add('${p.basename(from)} -> ${p.basename(to)}');
          return renameFileWithoutOverwrite(from, to);
        },
      );

      final result = await executor.rename(source.path, 'photo.jpg');

      expect(result, isA<Renamed>());
      expect(calls.length, 2, reason: '一時名を経由する: $calls');
      expect(calls.first, startsWith('Photo.jpg -> Photo.jpg.renaming-swap-'));
      expect(calls.last, endsWith('-> photo.jpg'));
      expect(
        await File(p.join(directory.path, 'photo.jpg')).readAsString(),
        'kept-content',
      );
      // 一時名は残らない。
      final left = await directory
          .list()
          .map((e) => p.basename(e.path))
          .toList();
      expect(left, ['photo.jpg']);
    });

    test('目標名に別の実体があれば、巻き戻して nameConflict を返す(INV-002)', () async {
      // 2段目が`EEXIST`で止まり、元の名前へ戻る。**一度も上書きしない。**
      final source = File(p.join(directory.path, 'Photo.jpg'));
      final other = File(p.join(directory.path, 'photo.jpg'));
      await source.writeAsString('source-content');
      await other.writeAsString('other-content');

      final result = await DesktopRenameExecutor(
        probe: const _AlwaysExists(),
      ).rename(source.path, 'photo.jpg');

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await source.readAsString(), 'source-content');
      expect(await other.readAsString(), 'other-content');
      final left =
          (await directory.list().map((e) => p.basename(e.path)).toList())
            ..sort();
      expect(left, ['Photo.jpg', 'photo.jpg'], reason: '一時名が残らない');
    });

    test('目標名が hard link なら衝突として扱う(INV-003)', () async {
      // hard linkは別の名前が同じ実体を指す。**それは自分自身ではない。**
      // 通常のrenameだと「何もせず成功」を返すが、排他renameは`EEXIST`にする。
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');
      final link = File(p.join(directory.path, 'b.txt'));
      final ln = await Process.run('ln', [source.path, link.path]);
      expect(ln.exitCode, 0, reason: 'hard linkを作れること: ${ln.stderr}');

      final result = await DesktopRenameExecutor(
        probe: const _AlwaysExists(),
      ).rename(source.path, 'b.txt');

      expect(
        (result as RenameFailed).error.kind,
        RenameErrorKind.nameConflict,
        reason: '改名していないのに成功を返してはならない',
      );
      expect(await source.exists(), isTrue);
      expect(await link.exists(), isTrue);
    });

    test('目標名が実在するときだけ一時名を経由する(REQ-025の実在確認)', () async {
      // **productionの述語(`_RealPathProbe.exists`)が実際に効いていること**を
      // 固定する。probeを注入せず、rename呼び出しの回数で判定する。
      // `exists`を常にtrue/falseへ倒すと、どちらもこのtestが落ちる。
      final occupied = File(p.join(directory.path, 'b.txt'));
      await occupied.writeAsString('other');
      final free = File(p.join(directory.path, 'a.txt'));
      await free.writeAsString('src');

      final calls = <String>[];
      DesktopRenameExecutor record() => DesktopRenameExecutor(
        rename: (from, to) async {
          calls.add('${p.basename(from)} -> ${p.basename(to)}');
          return renameFileWithoutOverwrite(from, to);
        },
      );

      // 目標名が実在する → 退避・前進失敗・巻き戻しの3回。
      final conflict = await record().rename(free.path, 'b.txt');
      expect(
        (conflict as RenameFailed).error.kind,
        RenameErrorKind.nameConflict,
      );
      expect(calls.length, 3, reason: '一時名を経由する: $calls');

      // 目標名が空いている → 1回だけ。
      calls.clear();
      final ok = await record().rename(free.path, 'c.txt');
      expect(ok, isA<Renamed>());
      expect(calls, ['a.txt -> c.txt'], reason: '一時名を経由しない');
    });

    test('2段階の途中で例外が出ても、例外を外へ出さず元の名前へ戻す(REQ-017)', () async {
      // **1段目を通ったあとの例外で抜けると、実体は一時名のまま残り、
      // 利用者はどのfileがどうなったかを知る手立てを失う。**
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      var step = 0;
      final executor = DesktopRenameExecutor(
        probe: const _AlwaysExists(),
        rename: (from, to) async {
          step += 1;
          if (step == 2) throw const FileSystemException('boom');
          return renameFileWithoutOverwrite(from, to);
        },
      );

      final result = await executor.rename(source.path, 'b.txt');

      expect(result, isA<RenameFailed>(), reason: '例外ではなく失敗値を返す');
      expect(await source.readAsString(), 'kept-content', reason: '元の名前へ戻す');
      final left = await directory
          .list()
          .map((e) => p.basename(e.path))
          .toList();
      expect(left, ['a.txt'], reason: '一時名が残らない');
    });

    test('例外のあと巻き戻しもできなければ、現在の名前を理由に含める(REQ-017)', () async {
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      var step = 0;
      final executor = DesktopRenameExecutor(
        probe: const _AlwaysExists(),
        rename: (from, to) async {
          step += 1;
          if (step == 1) return renameFileWithoutOverwrite(from, to);
          throw const FileSystemException('boom');
        },
      );

      final result = await executor.rename(source.path, 'b.txt');

      final failure = result as RenameFailed;
      expect(failure.error.message, contains('renaming-swap-'));
      expect(failure.error.message, contains('戻せませんでした'));
    });

    test('巻き戻しにも失敗したら、一時名を含む理由を返す(REQ-017)', () async {
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      var step = 0;
      final executor = DesktopRenameExecutor(
        probe: const _AlwaysExists(),
        rename: (from, to) async {
          step += 1;
          if (step == 1) return renameFileWithoutOverwrite(from, to);
          return NativeRenameResult.nameConflict; // 前進も巻き戻しも失敗
        },
      );

      final result = await executor.rename(source.path, 'b.txt');

      final failure = result as RenameFailed;
      expect(failure.error.kind, RenameErrorKind.io);
      expect(failure.error.message, contains('renaming-swap-'));
      expect(failure.error.message, contains('戻せませんでした'));
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

/// 目標名が「実在する」と答える [DesktopPathProbe]。
///
/// 大文字小文字や正規化を区別しないfilesystemを模す。Linuxの実FSでは
/// この条件を作れない(`mount`が使えない)ので、条件そのものを注入する。
class _AlwaysExists implements DesktopPathProbe {
  const _AlwaysExists();

  @override
  Future<bool> exists(String path) async => true;
}
