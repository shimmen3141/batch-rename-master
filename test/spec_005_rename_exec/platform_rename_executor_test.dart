// VER-001 / VER-007: platform adapter の実ファイル作用と SAF 契約。
import 'dart:convert';
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
        probe: const _CaseInsensitiveProbe(),
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
      // 1段目のあとの再観測でまだ実在するので、**2段目を実行しない**。
      final source = File(p.join(directory.path, 'a.txt'));
      final other = File(p.join(directory.path, 'b.txt'));
      await source.writeAsString('source-content');
      await other.writeAsString('other-content');

      final result = await DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
      ).rename(source.path, 'b.txt');

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await source.readAsString(), 'source-content');
      expect(await other.readAsString(), 'other-content');
      final left =
          (await directory.list().map((e) => p.basename(e.path)).toList())
            ..sort();
      expect(left, ['a.txt', 'b.txt'], reason: '一時名が残らない');
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
        probe: const _CaseInsensitiveProbe(),
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

      // 目標名が実在する → 退避・(再観測でまだ実在)・巻き戻しの2回。
      final conflict = await record().rename(free.path, 'b.txt');
      expect(
        (conflict as RenameFailed).error.kind,
        RenameErrorKind.nameConflict,
      );
      expect(calls.length, 2, reason: '一時名を経由する: $calls');

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
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async {
          step += 1;
          if (step == 2) throw const FileSystemException('boom');
          return renameFileWithoutOverwrite(from, to);
        },
      );

      final result = await executor.rename(source.path, 'A.txt');

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
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async {
          step += 1;
          if (step == 1) return renameFileWithoutOverwrite(from, to);
          throw const FileSystemException('boom');
        },
      );

      final result = await executor.rename(source.path, 'A.txt');

      final failure = result as RenameFailed;
      expect(failure.error.message, contains('renaming-swap-'));
      expect(failure.error.message, contains('戻せませんでした'));
    });

    test('巻き戻しにも失敗したら、一時名を含む理由を返す(REQ-017)', () async {
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      var step = 0;
      final executor = DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async {
          step += 1;
          if (step == 1) return renameFileWithoutOverwrite(from, to);
          return NativeRenameResult.nameConflict; // 前進も巻き戻しも失敗
        },
      );

      final result = await executor.rename(source.path, 'A.txt');

      final failure = result as RenameFailed;
      expect(failure.error.kind, RenameErrorKind.io);
      expect(failure.error.message, contains('renaming-swap-'));
      expect(failure.error.message, contains('戻せませんでした'));
    });

    test('no-replaceを黙って無視する環境でも、別の実体を上書きしない(REQ-025)', () async {
      // 排他renameが「常に成功する上書きrename」である環境を模す。
      // **1段目のあとの再観測が、2段目を実行させない。**
      final source = File(p.join(directory.path, 'a.txt'));
      final victim = File(p.join(directory.path, 'b.txt'));
      await source.writeAsString('source-content');
      await victim.writeAsString('victim-content');

      final calls = <String>[];
      final executor = DesktopRenameExecutor(
        rename: (from, to) async {
          calls.add('${p.basename(from)} -> ${p.basename(to)}');
          await File(from).rename(to); // 上書きする(危険な環境)
          return NativeRenameResult.success;
        },
      );

      final result = await executor.rename(source.path, 'b.txt');

      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await victim.readAsString(), 'victim-content', reason: '上書きしない');
      expect(await source.readAsString(), 'source-content');
      expect(calls.length, 2, reason: '2段目を実行しない: $calls');
    });

    test('一時名への退避で例外が出ても、例外を外へ出さない(REQ-017)', () async {
      // **1段目はまだ実体を動かしていない。** ここで例外が漏れると、
      // `rename()`のcatchを素通りして実行全体を貫通する。
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      final executor = DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async => throw const FileSystemException('boom'),
      );

      final result = await executor.rename(source.path, 'A.txt');

      expect(result, isA<RenameFailed>(), reason: '例外ではなく失敗値を返す');
      expect(await source.readAsString(), 'kept-content');
    });

    test('再観測で例外が出ても、巻き戻して元の名前へ戻す(REQ-017)', () async {
      // **1段目を通ったあとのawaitはすべて巻き戻し経路を通る。**
      // `isA<RenameFailed>()`だけでは、自分が作り出した残骸状態を観測していない。
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      final probe = _ThrowsAt(
        stage: 'reobserve',
        destination: 'A.txt',
        original: 'a.txt',
      );
      final result = await DesktopRenameExecutor(
        probe: probe,
      ).rename(source.path, 'A.txt');

      expect(probe.reachedStage, isTrue, reason: '再観測に到達していること');
      expect(result, isA<RenameFailed>(), reason: '例外ではなく失敗値を返す');
      expect(await source.readAsString(), 'kept-content', reason: '元の名前へ戻る');
      final left = await directory
          .list()
          .map((e) => p.basename(e.path))
          .toList();
      expect(left, ['a.txt'], reason: '一時名が残らない');
    });

    test('巻き戻し先の確認で例外が出たら、現在の名前を理由に含める(REQ-017)', () async {
      // 巻き戻せないので実体は一時名にある。**名前を理由へ出す**。
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      final probe = _ThrowsAt(
        stage: 'rollback',
        destination: 'A.txt',
        original: 'a.txt',
      );
      final result = await DesktopRenameExecutor(
        probe: probe,
      ).rename(source.path, 'A.txt');

      expect(probe.reachedStage, isTrue, reason: '巻き戻し先の確認に到達していること');
      final failure = result as RenameFailed;
      expect(failure.error.message, contains('renaming-swap-'));
      expect(failure.error.message, contains('戻せませんでした'));
      // **巻き戻していない**ことをFSの実状態で固定する。
      final left = await directory
          .list()
          .map((e) => p.basename(e.path))
          .toList();
      expect(left.single, startsWith('a.txt.renaming-swap-'));
      expect(
        await File(p.join(directory.path, left.single)).readAsString(),
        'kept-content',
        reason: '残っているのは元の実体である',
      );
    });

    test('一時名が埋まっていたら次の候補を試す', () async {
      // 前回の異常終了で残った一時名があっても、改名は通る。
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');
      await File(
        p.join(directory.path, 'a.txt.renaming-swap-0'),
      ).writeAsString('leftover');

      final calls = <String>[];
      final executor = DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async {
          calls.add(p.basename(to));
          return renameFileWithoutOverwrite(from, to);
        },
      );

      final result = await executor.rename(source.path, 'A.txt');

      expect(result, isA<Renamed>());
      expect(
        calls.first,
        'a.txt.renaming-swap-1',
        reason: '実在確認で swap-0 を避ける(呼ばない)',
      );
      expect(
        await File(
          p.join(directory.path, 'a.txt.renaming-swap-0'),
        ).readAsString(),
        'leftover',
        reason: '残骸を壊さない',
      );
    });

    test('一時名を32回取れなくても、nameConflictとして返す(再採番へ繋ぐ)', () async {
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      final executor = DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async => NativeRenameResult.nameConflict,
      );

      final result = await executor.rename(source.path, 'A.txt');

      // **観測済みの衝突を捨てない。** `io`で返すと呼び出し側の再採番が
      // 拾えず、実行全体が止まる(REQ-023)。
      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(result.error.message, contains('一時名を確保できませんでした'));
    });

    test('退避が別の理由で失敗しても、nameConflictとして返し理由を併記する', () async {
      final source = File(p.join(directory.path, 'a.txt'));
      await source.writeAsString('kept-content');

      final executor = DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async => NativeRenameResult.permissionDenied,
      );

      final result = await executor.rename(source.path, 'A.txt');

      // 分類は`nameConflict`(衝突は観測済み)。内部の理由は本文に残す。
      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(result.error.message, contains('権限がありません'));
    });

    test('巻き戻し先が塞がっていたら戻さず、現在の名前を理由に含める(REQ-025)', () async {
      // 退避と巻き戻しの間に他processが元の名前を作った状況。**戻すと
      // その実体を上書きする**(フラグを黙って無視する環境)。戻さない。
      final source = File(p.join(directory.path, 'a.txt'));
      final other = File(p.join(directory.path, 'b.txt'));
      await source.writeAsString('source-content');
      await other.writeAsString('other-content');

      final executor = DesktopRenameExecutor(
        probe: const _ExistsExceptTemporary(),
        rename: (from, to) async => renameFileWithoutOverwrite(from, to),
      );

      final result = await executor.rename(source.path, 'b.txt');

      final failure = result as RenameFailed;
      expect(failure.error.message, contains('renaming-swap-'));
      expect(failure.error.message, contains('戻せませんでした'));
      expect(await other.readAsString(), 'other-content', reason: '上書きしない');
    });

    test('元名が長くても、一時名が長さ上限を超えない(REQ-023が働く)', () async {
      // 一時名が`NAME_MAX`を超えると排他renameが`ENAMETOOLONG`で失敗し、
      // `io`として返る。呼び出し側の再採番は`nameConflict`しか拾わないので、
      // **長い名前のときだけ再採番が働かず実行全体が止まる。**
      final longBase = 'x' * 240;
      final source = File(p.join(directory.path, '$longBase.txt'));
      await source.writeAsString('source-content');
      final other = File(p.join(directory.path, 'dest.txt'));
      await other.writeAsString('other-content');

      final result = await DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
      ).rename(source.path, 'dest.txt');

      expect(
        (result as RenameFailed).error.kind,
        RenameErrorKind.nameConflict,
        reason: 'ioに化けない: ${result.error.message}',
      );
      expect(await source.readAsString(), 'source-content');
    });

    test('元名が長くても、一時名が有効なUTF-8になり元名を辿れる', () async {
      // 切り詰めをcode point境界で行わないと、多byte文字の途中で切れる。
      // 切り詰めると元名が読めなくなるので、短いhashを付けて区別できるようにする。
      final longBase = 'あ' * 80;
      final source = File(p.join(directory.path, '$longBase-TAIL.txt'));
      await source.writeAsString('source-content');
      await File(p.join(directory.path, 'dest.txt')).writeAsString('other');

      final calls = <String>[];
      await DesktopRenameExecutor(
        probe: const _CaseInsensitiveProbe(),
        rename: (from, to) async {
          calls.add(p.basename(to));
          return renameFileWithoutOverwrite(from, to);
        },
      ).rename(source.path, 'dest.txt');

      final temporary = calls.first;
      expect(utf8.encode(temporary).length, lessThanOrEqualTo(255));
      expect(
        temporary.contains('\uFFFD'),
        isFalse,
        reason: 'code point境界で切る: $temporary',
      );
      expect(
        RegExp(r'-[0-9a-f]{8}\.renaming-swap-\d+$').hasMatch(temporary),
        isTrue,
        reason: '元名を辿るhashが付く: $temporary',
      );
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

  // `013:T05` で **Android は unsupported から外れた**。生の syscall で
  // `renameat2` を呼ぶ経路に載る(013 spec D-1: minSdk は 24 のまま、対応可否は
  // 実行時に判定する)。iOS はこのアプリの対象 platform ではないので unsupported の
  // ままである。
  //
  // **Android の build はこの container で行えない**(SDK / NDK が無い)。したがって
  // ここが検査できるのは「build 設定と C の分岐が意図どおり書かれているか」までで、
  // **実際にコンパイル・実行できるかは `013:T08` の実機確認が見る**。
  test('native asset の設定が Android を対象に含み、iOS だけを外す', () async {
    final hook = await File('hook/build.dart').readAsString();
    final source = await File('src/native_exclusive_rename.c').readAsString();

    expect(hook, contains('if (!input.config.buildCodeAssets)'));
    expect(hook, contains('final targetOS = input.config.code.targetOS'));
    expect(
      hook,
      contains("if (targetOS == OS.iOS) 'BRM_UNSUPPORTED_PLATFORM': null"),
      reason: 'iOS だけを未対応にする',
    );
    expect(
      hook.contains('targetOS == OS.android'),
      isFalse,
      reason: 'Android を未対応の側へ戻さない(013 REQ-005)',
    );
    expect(source, contains('#if defined(BRM_UNSUPPORTED_PLATFORM)'));
    expect(source, contains('return BRM_RENAME_UNSUPPORTED;'));
  });

  test('Android は bionic の wrapper ではなく生の syscall で renameat2 を呼ぶ', () async {
    // wrapper が公開されたのは API 30 とされるが、`013` は minSdk 24 のままと
    // 決めた(spec D-1)。**API level を対応可否の代理指標にしない。**
    final source = await File('src/native_exclusive_rename.c').readAsString();

    expect(source, contains('#elif defined(__ANDROID__)'));
    // **flag が呼び出しに渡っていることまで見る。** `RENAME_NOREPLACE` が file の
    // どこかにある(`#define` など)だけでは、呼び出しから外れても気づけない。
    // 外れると置換 rename になり、005 INV-002 が全面的に破れる。
    final androidBranch = source.indexOf('#elif defined(__ANDROID__)');
    final call = source.substring(
      androidBranch,
      source.indexOf('#else', androidBranch),
    );
    expect(
      call,
      contains(
        'syscall(SYS_renameat2, AT_FDCWD, source, AT_FDCWD, destination',
      ),
      reason: 'wrapper ではなく生の syscall',
    );
    expect(
      call,
      contains('RENAME_NOREPLACE'),
      reason: '**この呼び出しに** flag が渡っている(外すと置換 rename になる)',
    );
    // header に SYS_renameat2 が無い環境でも呼べるよう arch 別の番号を持つ。
    // 値は kernel の uapi header と照合済み(x86_64=316、asm-generic=276)。
    for (final entry in {
      '__aarch64__': 276,
      '__x86_64__': 316,
      '__arm__': 382,
      '__i386__': 353,
    }.entries) {
      expect(
        source,
        contains('defined(${entry.key})'),
        reason: '${entry.key} の syscall 番号を用意する',
      );
      expect(source, contains('#define SYS_renameat2 ${entry.value}'));
    }
  });

  test('composition root はまだ Android を切り替えていない(`T07` が切り替える)', () async {
    // **切り替えは `013:T07` の受け入れ証拠である。** Android のハンドルがまだ SAF の
    // document URI で path として解釈できず、**005 contract revision 5.1 が今なお
    // Android SAF を未対応と規定している**(REQ-017 / OP-004)ためである。
    //
    // この test は `T07` が切り替えた時点で落ちる。**そのとき消すのではなく、
    // 「Android が `createAndroidRenameExecutor` を返す」検査へ置き換えること。**
    final source = await File(
      'lib/data/rename_exec/platform_rename_executor.dart',
    ).readAsString();

    expect(
      source,
      contains('if (Platform.isAndroid) return const SafRenameExecutor();'),
      reason: '退避経路(ADR-002)を wiring から外すのは `T07`',
    );
    expect(
      source.contains('createAndroidRenameExecutor'),
      isTrue,
      reason: '切り替え先と理由が doc comment に書かれている',
    );
  });

  test('EINVAL を unsupported へ写すのは Android のときだけ', () async {
    // `renameat2` は filesystem が flag を解釈できないと EINVAL を返す。Android は
    // 共有 storage が FUSE を経由するのでこの経路が現実的に起きる(013 REQ-005 で
    // 劣化させる)。**desktop の写像は変えない**(013 は desktop の振る舞いを変えない)。
    final source = await File('src/native_exclusive_rename.c').readAsString();
    // `brm_rename_no_replace_utf8` は未対応 platform の分岐にも現れるので、
    // errno 写像の直後にある**最後の**定義までを切り取る。
    final mapping = source.substring(
      source.indexOf('brm_result_from_errno'),
      source.lastIndexOf('BRM_EXPORT int32_t brm_rename_no_replace_utf8'),
    );

    expect(mapping, contains('#if defined(__ANDROID__)'));
    final einval = mapping.indexOf('case EINVAL:');
    final guard = mapping.indexOf('#if defined(__ANDROID__)');
    final endif = mapping.indexOf('#endif', guard);
    expect(einval, greaterThan(guard), reason: 'EINVAL は Android 分岐の中にある');
    expect(einval, lessThan(endif));
  });
}

/// 大文字小文字を区別しないfilesystemを模す [DesktopPathProbe]。
///
/// 実FSに加えて、**同じdirectoryに小文字化して一致するentryがあれば「実在する」**
/// と答える。Linuxの実FSではこの条件を作れない(`mount`が使えない)ので、
/// 条件そのものを注入する。
///
/// **退避で元の名前が空けば`false`になる**ので、2段階renameの各段で正しく
/// 振る舞う。固定値を返すfakeでは1段目の前後を区別できない。
class _CaseInsensitiveProbe implements DesktopPathProbe {
  const _CaseInsensitiveProbe();

  @override
  Future<bool> exists(String path) async {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return true;
    }
    final name = p.basename(path).toLowerCase();
    await for (final entity in Directory(p.dirname(path)).list()) {
      if (p.basename(entity.path).toLowerCase() == name) return true;
    }
    return false;
  }
}

/// 指定した段階で例外を投げる [DesktopPathProbe]。
///
/// **「N回目」で分岐しない。** probeの呼び出し回数は実装の都合で変わるので、
/// 回数で狙うと照準が黙ってずれる(review attempt 11で、再観測を狙ったはずの
/// testが退避先の確認に当たっていた)。**pathと段階で分岐する。**
class _ThrowsAt implements DesktopPathProbe {
  _ThrowsAt({
    required this.stage,
    required this.destination,
    required this.original,
  });

  /// `reobserve`: 1段目のあとの目標名の再観測。`rollback`: 巻き戻し先の確認。
  final String stage;
  final String destination;

  /// 巻き戻し先(元の名前)。**消去法で当てない** — 段階をpathで指名する。
  final String original;

  /// **狙った段階に実際に到達したか。** testはこれをassertする。
  /// 到達判定を持たないと、実装が変わったときに照準が黙ってずれて緑のまま通る
  /// (review attempt 11で10回分それが起きた)。
  bool reachedStage = false;

  /// 退避が**実際に起きたか**をFSで観測する。
  ///
  /// 「退避先をprobeしたか」で代理判定すると、候補probeと退避renameの間に
  /// 別のprobeが挿入されたときに照準がずれる(attempt 13のP2-3)。
  bool _movedAway(String path) => Directory(
    p.dirname(path),
  ).listSync().any((e) => p.basename(e.path).contains('renaming-swap'));

  @override
  Future<bool> exists(String path) async {
    if (p.basename(path).contains('renaming-swap')) {
      return false; // 退避先は空いている
    }
    final moved = _movedAway(path);
    final isDestination = p.basename(path) == p.basename(destination);
    if (isDestination) {
      if (!moved) return true; // 改名前の実在確認
      // 再観測(退避後に目標名を見ている)。
      if (stage == 'reobserve') {
        reachedStage = true;
        throw const FileSystemException('boom');
      }
      return true; // 別の実体がある → 巻き戻しへ
    }
    if (moved &&
        stage == 'rollback' &&
        p.basename(path) == p.basename(original)) {
      reachedStage = true;
      throw const FileSystemException('boom'); // 巻き戻し先の確認
    }
    return false;
  }
}

/// 一時名以外は「実在する」と答える [DesktopPathProbe]。
///
/// 退避は通り、**巻き戻し先が塞がっている**状況を模す(退避と巻き戻しの間に
/// 他processが元の名前を作った場合)。
class _ExistsExceptTemporary implements DesktopPathProbe {
  const _ExistsExceptTemporary();

  @override
  Future<bool> exists(String path) async =>
      !p.basename(path).contains('renaming-swap');
}
