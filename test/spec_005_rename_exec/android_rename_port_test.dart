// 013 VER-005 / 005 VER-001: 排他 rename が使えない環境での改名(013 REQ-005 / REQ-006)。
//
// 観点: `renameat2(RENAME_NOREPLACE)` が効く環境では `EEXIST` を `nameConflict` で
// 返して 005 の再採番へ繋ぎ、**効かない環境では「対応外」にせず実在確認の水準へ
// 劣化するだけ**であること。
//
// 「劣化する側」と「劣化しない側」は逆向きなので両方を固定する。片方だけでは
// 「常に通常 rename へ落ちる実装」(= no-replace を一度も使わない)と
// 「一度も落ちない実装」(= 効かない端末で改名できない)のどちらかが通ってしまう。
//
// **この file に `Platform` も `Android` 判定も出てこない。** ADR-003 により、
// 劣化するかどうかは OS ではなく native が返す [NativeRenameResult.fallbackRequired]
// で決まる。おかげで**Android の劣化経路そのものを Linux 上で実行できる** —
// 以前は platform 分岐だったため、production の合成を test が一度も通れなかった。
//
// 残るのは C 側の `#if defined(__ANDROID__)` だけで、それは `013:T08` の実機確認が見る。
import 'dart:io';

import 'package:batch_rename_master/data/rename_exec/desktop_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:batch_rename_master/data/rename_exec/plain_rename.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 呼ばれた順を記録する rename。返す結果は目標 path ごとに差し替えられる。
class _Rename {
  _Rename(this.results, {this.fallback = NativeRenameResult.success});

  final Map<String, NativeRenameResult> results;
  final NativeRenameResult fallback;
  final List<String> calls = [];

  Future<NativeRenameResult> call(String source, String destination) async {
    calls.add('$source -> $destination');
    return results[destination] ?? fallback;
  }
}

/// 「目標名は実在しない」と嘘をつく probe。
///
/// 005 REQ-025 の実在確認が**必ず先に止めてしまう**ので、確認を通したうえで
/// 「排他 rename と通常 rename のどちらが呼ばれたか」を観測する手段がこれしかない。
/// 実際の TOCTOU(確認から改名までの窓で他者が同名を作る)と同じ状況である。
class _BlindProbe implements DesktopPathProbe {
  @override
  Future<bool> exists(String path) async => false;
}

/// 1回目だけ「実在する」と答える probe。
///
/// 大文字小文字を区別しない volume での case-only 改名を模す。1回目(改名前)は
/// 目標名が実在し、退避で元の名前が空くと 2回目(退避後)には消える。
/// **`RENAME_NOREPLACE` が効かない volume(FAT / exFAT / FUSE)と同じ集合**なので、
/// Android ではこの組み合わせが例外ではなく典型である。
class _VanishingProbe implements DesktopPathProbe {
  final Set<String> asked = {};

  @override
  Future<bool> exists(String path) async {
    if (path.contains('renaming-swap-')) return false;
    return asked.add(path);
  }
}

/// 通常 rename が呼ばれたかを見る spy。既定では実体を動かさず成功だけ返す。
class _PlainSpy {
  _PlainSpy({this.result = NativeRenameResult.success, this.real = false});

  final NativeRenameResult result;
  final bool real;
  final List<String> calls = [];

  Future<NativeRenameResult> call(String source, String destination) async {
    calls.add('$source -> $destination');
    if (real) return plainRenameFile(source, destination);
    return result;
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-fallback-port-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// 実 file を作る。executor は実在を実 filesystem で確かめるので、
  /// ここだけは fake にできない。
  Future<String> makeFile(String name, [String body = 'x']) async {
    final file = File(p.join(dir.path, name));
    await file.writeAsString(body);
    return file.path;
  }

  group('013 REQ-005: native が劣化を要求したら通常 rename へ落とす', () {
    test('`fallbackRequired` を受けると、既定の通常 rename が実 file を改名する', () async {
      // **`plainRename` を渡さない。** production が使う既定の束縛そのものを通す。
      final source = await makeFile('a.txt', 'body');
      final executor = DesktopRenameExecutor(
        rename: _Rename(
          const {},
          fallback: NativeRenameResult.fallbackRequired,
        ).call,
      );

      final result = await executor.rename(source, 'b.txt');

      expect(result, isA<Renamed>());
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'body');
      expect(await File(source).exists(), isFalse);
    });

    test('`fallbackRequired` 以外では通常 rename を試さない', () async {
      final source = await makeFile('a.txt');
      final plain = _PlainSpy();

      for (final result in const [
        NativeRenameResult.success,
        NativeRenameResult.nameConflict,
        NativeRenameResult.notFound,
        NativeRenameResult.permissionDenied,
        NativeRenameResult.unsupported,
        NativeRenameResult.io,
      ]) {
        await DesktopRenameExecutor(
          rename: _Rename(const {}, fallback: result).call,
          plainRename: plain.call,
        ).rename(source, 'b.txt');
      }

      expect(plain.calls, isEmpty);
    });

    test('`unsupported` は劣化させず失敗にする(desktop の保証を弱めない)', () async {
      final source = await makeFile('a.txt', 'body');
      final result = await DesktopRenameExecutor(
        rename: _Rename(
          const {},
          fallback: NativeRenameResult.unsupported,
        ).call,
      ).rename(source, 'b.txt');

      expect(result, isA<RenameFailed>());
      // 実体は動いていない。
      expect(await File(source).readAsString(), 'body');
      expect(await File(p.join(dir.path, 'b.txt')).exists(), isFalse);
    });

    test('通常 rename の失敗もそのまま返る(握りつぶさない)', () async {
      final source = await makeFile('a.txt');
      final failure = await DesktopRenameExecutor(
        rename: _Rename(
          const {},
          fallback: NativeRenameResult.fallbackRequired,
        ).call,
        plainRename: _PlainSpy(result: NativeRenameResult.io).call,
      ).rename(source, 'b.txt');

      expect(failure, isA<RenameFailed>());
      expect((failure as RenameFailed).error.kind, RenameErrorKind.io);
    });

    test('一時名経路の2段目(前進)も劣化する(case-only 改名が失敗しない)', () async {
      // 1回目のprobeで目標名が実在し、退避後には消えている経路。ここが劣化しない
      // と、**flagが効かない volume での case-only 改名だけが `io` で失敗する** —
      // `nameConflict` ではないので 005 REQ-023 の再採番も拾わず、実行全体が止まる。
      final source = await makeFile('a.txt', 'body');
      final plain = _PlainSpy(real: true);

      final result = await DesktopRenameExecutor(
        rename: _Rename(
          const {},
          fallback: NativeRenameResult.fallbackRequired,
        ).call,
        plainRename: plain.call,
        probe: _VanishingProbe(),
      ).rename(source, 'A.txt');

      expect(result, isA<Renamed>());
      expect(await File(p.join(dir.path, 'A.txt')).readAsString(), 'body');
      // 退避(1段目)と前進(2段目)の両方が通常 rename を通っている。
      expect(plain.calls, hasLength(2));
    });

    test('一時名を経由する経路も劣化する(改名経路が1つ残らず通る)', () async {
      // 目標名に実体があると `_renameViaTemporary` を通る。ここが劣化しないと、
      // ありふれた重複名の改名だけ「効かない端末で失敗する」ことになる。
      final source = await makeFile('a.txt', 'source-body');
      await makeFile('b.txt', 'other-body');
      final plain = _PlainSpy(real: true);

      final result = await DesktopRenameExecutor(
        rename: _Rename(
          const {},
          fallback: NativeRenameResult.fallbackRequired,
        ).call,
        plainRename: plain.call,
      ).rename(source, 'b.txt');

      // 退避には成功するが、目標名の実体は自分自身ではないので巻き戻す。
      expect(result, isA<RenameFailed>());
      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(plain.calls, isNotEmpty);
      // 巻き戻せているので、両方とも元のまま。
      expect(await File(source).readAsString(), 'source-body');
      expect(
        await File(p.join(dir.path, 'b.txt')).readAsString(),
        'other-body',
      );
    });
  });

  group('013 REQ-006: EEXIST は nameConflict として返り、再採番へ繋がる', () {
    test('target がある改名は `nameConflict` を返し、実体を変えない', () async {
      final source = await makeFile('a.txt', 'source-body');
      await makeFile('b.txt', 'keep-body');

      final result = await DesktopRenameExecutor().rename(source, 'b.txt');

      expect(result, isA<RenameFailed>());
      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await File(source).readAsString(), 'source-body');
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'keep-body');
    });

    test('platform 固有の失敗として見せない', () async {
      final source = await makeFile('a.txt');
      await makeFile('b.txt');

      final result =
          await DesktopRenameExecutor().rename(source, 'b.txt') as RenameFailed;

      expect(result.error.kind, RenameErrorKind.nameConflict);
      expect(result.error.kind, isNot(RenameErrorKind.unsupportedPlatform));
      expect(result.error.message, isNot(contains('Android')));
    });
  });

  group('005 REQ-025: 劣化しても実在確認は省かない', () {
    test('目標名が実在するなら、劣化経路でも置換しない', () async {
      // 通常 rename は既存 target を黙って置換する。実在確認だけがそれを防ぐ。
      final source = await makeFile('a.txt', 'source-body');
      await makeFile('b.txt', 'keep-body');

      await DesktopRenameExecutor(
        rename: _Rename(
          const {},
          fallback: NativeRenameResult.fallbackRequired,
        ).call,
        plainRename: _PlainSpy(real: true).call,
      ).rename(source, 'b.txt');

      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'keep-body');
    });
  });

  group('production の既定を fake 無しで動かす', () {
    test('既定だけで実 file を改名できる(排他 rename が本当に呼ばれている)', () async {
      final source = await makeFile('a.txt', 'body');

      final result = await DesktopRenameExecutor().rename(source, 'b.txt');

      expect(result, isA<Renamed>());
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'body');
    });

    test('既定だけで、対象が無ければ notFound を返す', () async {
      final missing = p.join(dir.path, 'missing.txt');

      final result = await DesktopRenameExecutor().rename(missing, 'b.txt');

      expect(result, isA<RenameFailed>());
      expect((result as RenameFailed).error.kind, RenameErrorKind.notFound);
    });

    test('既定の排他 rename は、実在する目標名を置換しない', () async {
      final source = await makeFile('a.txt', 'source-body');
      final keep = await makeFile('keep.txt', 'keep-body');

      // executor を通さず native を直接呼ぶ。executor は実在確認で先に止まるので、
      // **排他 rename が通常 rename にすり替わっても executor 経由では気づけない。**
      final result = renameFileWithoutOverwrite(source, keep);

      expect(result, NativeRenameResult.nameConflict);
      expect(await File(keep).readAsString(), 'keep-body');
      expect(await File(source).readAsString(), 'source-body');
    });

    test('実在確認をすり抜けても、既定は既存 file を置換しない(005 INV-002 の残余保証)', () async {
      // probe が「無い」と答えても、**排他 rename 自体が置換を拒む**。ここが
      // 通常 rename へすり替わると、実在確認の窓で作られた file を黙って壊す。
      // executor 経由でこれを観測できる唯一の経路である。
      final source = await makeFile('a.txt', 'source-body');
      await makeFile('b.txt', 'keep-body');

      final result = await DesktopRenameExecutor(
        probe: _BlindProbe(),
      ).rename(source, 'b.txt');

      expect(result, isA<RenameFailed>());
      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'keep-body');
      expect(await File(source).readAsString(), 'source-body');
    });

    test('既定の排他 rename は、対象が無ければ notFound を返す', () {
      final result = renameFileWithoutOverwrite(
        p.join(dir.path, 'missing.txt'),
        p.join(dir.path, 'b.txt'),
      );

      expect(result, NativeRenameResult.notFound);
    });
  });

  group('`plainRenameFile` の errno 写像(REQ-017: 例外を投げない)', () {
    test('対象が無ければ notFound', () async {
      final result = await plainRenameFile(
        p.join(dir.path, 'missing.txt'),
        p.join(dir.path, 'b.txt'),
      );

      expect(result, NativeRenameResult.notFound);
    });

    test('書き込めない folder では permissionDenied', () async {
      final locked = Directory(p.join(dir.path, 'locked'));
      await locked.create();
      final source = File(p.join(locked.path, 'a.txt'));
      await source.writeAsString('x');
      await Process.run('chmod', ['555', locked.path]);
      addTearDown(() => Process.run('chmod', ['755', locked.path]));

      final result = await plainRenameFile(
        source.path,
        p.join(locked.path, 'b.txt'),
      );

      expect(result, NativeRenameResult.permissionDenied);
    });

    test('その他の filesystem 失敗は io(成功として返さない)', () async {
      // file を非空 directory へ改名すると EISDIR / ENOTEMPTY になる。
      // ここを success へ写すと、**改名していないのに Renamed が返る**。
      final source = await makeFile('a.txt');
      final occupied = Directory(p.join(dir.path, 'occupied'));
      await occupied.create();
      await File(p.join(occupied.path, 'inner.txt')).writeAsString('x');

      final result = await plainRenameFile(source.toString(), occupied.path);

      expect(result, NativeRenameResult.io);
      expect(await File(source).exists(), isTrue);
    });
  });
}
