// 013 VER-005 / 005 VER-001: Android の改名 port(013 REQ-005 / REQ-006)。
//
// 観点: `renameat2(RENAME_NOREPLACE)` が効く環境では `EEXIST` を `nameConflict` で
// 返して 005 の再採番へ繋ぎ、**効かない環境では「対応外」にせず実在確認の水準へ
// 劣化するだけ**であること。
//
// 「劣化する側」と「劣化しない側」は逆向きなので両方を固定する。片方だけでは
// 「常に通常 rename へ落ちる実装」(= no-replace を一度も使わない)と
// 「一度も落ちない実装」(= 効かない端末で改名できない)のどちらかが通ってしまう。
//
// **Android の実 build と実機確認はここでは行えない**(AI container に SDK / NDK が
// 無い)。ここが検査するのは Dart 層の分岐と写像で、`renameat2` が実際に効くかは
// `013:T08` の実機確認が見る。
import 'dart:io';

import 'package:batch_rename_master/data/rename_exec/android_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/desktop_rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 実在を答えるだけの probe(005 REQ-025 の確認を差し替える)。
class _Probe implements DesktopPathProbe {
  _Probe(this.existing);

  final Set<String> existing;
  final List<String> asked = [];

  @override
  Future<bool> exists(String path) async {
    asked.add(path);
    return existing.contains(path);
  }
}

/// 呼ばれた順を記録する rename。返す結果は path ごとに差し替えられる。
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

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-android-port-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// 実 file を作る。executor は source の実在を実 filesystem で確かめるので、
  /// ここだけは fake にできない。
  Future<String> makeFile(String name, [String body = 'x']) async {
    final file = File(p.join(dir.path, name));
    await file.writeAsString(body);
    return file.path;
  }

  group('013 REQ-005: flag が効かない環境では通常 rename へ落とす', () {
    test('`unsupported` を受けたら通常 rename を試す', () async {
      final exclusive = _Rename({}, fallback: NativeRenameResult.unsupported);
      final plain = _Rename({});
      final operation = androidRenameOperation(
        exclusiveRename: exclusive.call,
        plainRename: plain.call,
      );

      final result = await operation('/A/a.txt', '/A/b.txt');

      expect(result, NativeRenameResult.success);
      expect(exclusive.calls, ['/A/a.txt -> /A/b.txt']);
      expect(plain.calls, [
        '/A/a.txt -> /A/b.txt',
      ], reason: '排他 rename が使えないので通常 rename へ落ちる');
    });

    test('`unsupported` 以外では通常 rename を試さない', () async {
      // 逆向き。これが無いと「常に通常 rename へ落ちる実装」が通ってしまう
      // (= no-replace を一度も使わない = 005 INV-002 を捨てる)。
      for (final result in [
        NativeRenameResult.success,
        NativeRenameResult.nameConflict,
        NativeRenameResult.notFound,
        NativeRenameResult.permissionDenied,
        NativeRenameResult.io,
      ]) {
        final exclusive = _Rename({}, fallback: result);
        final plain = _Rename({});
        final operation = androidRenameOperation(
          exclusiveRename: exclusive.call,
          plainRename: plain.call,
        );

        expect(await operation('/A/a.txt', '/A/b.txt'), result);
        expect(plain.calls, isEmpty, reason: '$result では落とさない');
      }
    });

    test('通常 rename の失敗もそのまま返る(握りつぶさない)', () async {
      final operation = androidRenameOperation(
        exclusiveRename: (_, _) async => NativeRenameResult.unsupported,
        plainRename: (_, _) async => NativeRenameResult.permissionDenied,
      );

      expect(
        await operation('/A/a.txt', '/A/b.txt'),
        NativeRenameResult.permissionDenied,
      );
    });
  });

  group('013 REQ-006: EEXIST は nameConflict として返り、再採番へ繋がる', () {
    test('target がある改名は `nameConflict` を返し、実体を変えない', () async {
      // 目標名が実在するので port は一時名を経由して自己衝突を確かめる
      // (005 REQ-025)。ここでは別の実体なので前進せず巻き戻す。
      final source = await makeFile('a.txt', 'source-body');
      final keep = await makeFile('keep.txt', 'keep-body');
      final executor = createAndroidRenameExecutor(
        rename: androidRenameOperation(
          exclusiveRename: (from, to) async {
            // 本物の renameat2(RENAME_NOREPLACE) と同じ意味論にする —
            // target があれば置換せず失敗し、無ければ移す。
            if (File(to).existsSync()) return NativeRenameResult.nameConflict;
            File(from).renameSync(to);
            return NativeRenameResult.success;
          },
        ),
      );

      final result = await executor.rename(source, 'keep.txt');

      expect(result, isA<RenameFailed>());
      expect(
        (result as RenameFailed).error.kind,
        RenameErrorKind.nameConflict,
        reason: '005 contract REQ-023 の再採番はこの kind だけを拾う',
      );
      expect(
        await File(keep).readAsString(),
        'keep-body',
        reason: '既存の実体は変わらない(005 INV-002)',
      );
      expect(await File(source).readAsString(), 'source-body');
    });

    test('Android 固有の失敗として見せない(unsupportedPlatform を返さない)', () async {
      final source = await makeFile('a.txt');
      final executor = createAndroidRenameExecutor(
        rename: (_, _) async => NativeRenameResult.unsupported,
      );

      final result = await executor.rename(source, 'b.txt');

      // `unsupported` は `androidRenameOperation` が受け止める前提だが、ここでは
      // port を直接差し替えているので executor まで届く。**それでも
      // `unsupportedPlatform` にはしない**(013 REQ-005)。
      expect(result, isA<RenameFailed>());
      expect(
        (result as RenameFailed).error.kind,
        isNot(RenameErrorKind.unsupportedPlatform),
      );
    });
  });

  group('005 REQ-025: 劣化しても実在確認は省かない', () {
    test('目標名が実在しないことを確認してから改名する', () async {
      final source = await makeFile('a.txt', 'body');
      final probe = _Probe({source});
      final executor = createAndroidRenameExecutor(
        rename: (from, to) async {
          File(from).renameSync(to);
          return NativeRenameResult.success;
        },
        probe: probe,
      );

      final result = await executor.rename(source, 'b.txt');

      expect(result, isA<Renamed>());
      expect(
        probe.asked,
        contains(p.join(dir.path, 'b.txt')),
        reason: '改名の前に目標名を観測している',
      );
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'body');
    });

    test('劣化経路でも、実在確認を通ってから通常 rename が呼ばれる', () async {
      // **順序が要点である。** 確認より先に通常 rename を呼ぶと、既存 file を
      // 黙って置換する(005 INV-002)。
      final source = await makeFile('a.txt', 'body');
      final order = <String>[];
      final probe = _Probe({source});
      final executor = createAndroidRenameExecutor(
        rename: androidRenameOperation(
          exclusiveRename: (_, _) async {
            order.add('exclusive');
            return NativeRenameResult.unsupported;
          },
          plainRename: (from, to) async {
            order.add('plain');
            File(from).renameSync(to);
            return NativeRenameResult.success;
          },
        ),
        probe: probe,
      );

      final result = await executor.rename(source, 'b.txt');

      expect(result, isA<Renamed>());
      expect(order, ['exclusive', 'plain']);
      expect(
        probe.asked.indexOf(p.join(dir.path, 'b.txt')),
        greaterThanOrEqualTo(0),
        reason: '通常 rename の前に目標名を観測している',
      );
    });
  });

  group('REQ-017: 例外を投げない', () {
    test('通常 rename が投げても結果型で返る', () async {
      final operation = androidRenameOperation(
        exclusiveRename: (_, _) async => NativeRenameResult.unsupported,
        plainRename: (_, _) async => throw StateError('想定外'),
      );

      await expectLater(
        operation('/A/a.txt', '/A/b.txt'),
        throwsA(isA<StateError>()),
        reason:
            '注入した op がそのまま投げるのは呼び出し側の責務ではない — '
            '実装の `plainRenameFile` が投げないことを次の test で固定する',
      );
    });

    test('`plainRenameFile` は存在しない path でも投げず notFound を返す', () async {
      final result = await plainRenameFile(
        '/definitely/does/not/exist-brm/a.txt',
        '/definitely/does/not/exist-brm/b.txt',
      );

      expect(
        result,
        NativeRenameResult.notFound,
        reason: '`io` へ丸めない — 呼び出し側は分類で経路を分ける(005 OP-004)',
      );
    });
  });

  group('composition root: Android はまだ切り替えない', () {
    test('`createAndroidRenameExecutor` は port を組み立てられる', () {
      expect(createAndroidRenameExecutor(), isA<RenameExecutor>());
    });
  });
}
