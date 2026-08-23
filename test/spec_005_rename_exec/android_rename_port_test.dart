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
        exclusiveRename: (from, to) async {
          // 本物の renameat2(RENAME_NOREPLACE) と同じ意味論にする —
          // target があれば置換せず失敗し、無ければ移す。
          if (File(to).existsSync()) return NativeRenameResult.nameConflict;
          File(from).renameSync(to);
          return NativeRenameResult.success;
        },
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
        exclusiveRename: (_, _) async => NativeRenameResult.unsupported,
        plainRename: (_, _) async => NativeRenameResult.permissionDenied,
      );

      final result = await executor.rename(source, 'b.txt');

      // 排他 rename も通常 rename も失敗した。**それでも
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
        exclusiveRename: (from, to) async {
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
        exclusiveRename: (_, _) async {
          order.add('exclusive');
          return NativeRenameResult.unsupported;
        },
        plainRename: (from, to) async {
          order.add('plain');
          File(from).renameSync(to);
          return NativeRenameResult.success;
        },
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

  // ---------------------------------------------------------------------------
  // **fake を一切使わずに、production が組み立てる object をそのまま動かす。**
  //
  // このtaskは「production が通る経路を test が通らない」型の指摘を**3回**受けた
  // (`M47` → `M48`/`M49` → `R1`/`R2`/`R3`)。3回とも、振る舞いを見る test が
  // すべて依存を注入しており、**`?? 既定` の右辺が一度も評価されない**ことが原因
  // だった。穴は合成から既定へ、既定から別の既定へ移動しただけである。
  //
  // したがって mutation を足すのをやめ、**引数を1つも渡さない factory を実 file
  // に対して動かす**群を置く。Linux の `flutter test` では実の `renameat2` が動く
  // (`platform_rename_executor_test.dart` が既にそれを使っている)ので、
  // **出荷するものそのものを検査できる。**
  //
  // 規則: **optional な依存を持つ factory には、その依存を省いた test を必ず置く。**
  group('production の既定を fake 無しで動かす', () {
    test('既定だけで実 file を改名できる(排他 rename が本当に呼ばれている)', () async {
      final source = await makeFile('a.txt', 'body');
      final executor = createAndroidRenameExecutor();

      final result = await executor.rename(source, 'b.txt');

      expect(result, isA<Renamed>());
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'body');
      expect(File(source).existsSync(), isFalse);
    });

    test('既定だけで、目標名が実在すると置換せず nameConflict を返す', () async {
      // **既定の `exclusiveRename` が通常 rename にすり替わると、ここで上書きして
      // 成功してしまう。** 005 INV-002 の核心を、fake 無しで固定する。
      final source = await makeFile('a.txt', 'source-body');
      final keep = await makeFile('keep.txt', 'keep-body');
      final executor = createAndroidRenameExecutor();

      final result = await executor.rename(source, 'keep.txt');

      expect(result, isA<RenameFailed>());
      expect((result as RenameFailed).error.kind, RenameErrorKind.nameConflict);
      expect(
        await File(keep).readAsString(),
        'keep-body',
        reason: '既存の実体を置換しない(005 INV-002)',
      );
      expect(await File(source).readAsString(), 'source-body');
    });

    test('既定だけで、対象が無ければ notFound を返す', () async {
      final executor = createAndroidRenameExecutor();

      final result = await executor.rename(
        p.join(dir.path, 'missing.txt'),
        'b.txt',
      );

      expect(result, isA<RenameFailed>());
      expect((result as RenameFailed).error.kind, RenameErrorKind.notFound);
    });

    test('既定の操作そのものが、実在する目標名を置換しない', () async {
      // **executor を通さずに操作を直接呼ぶ。** executor は実在確認(005 REQ-025)で
      // 先に止めるので、**排他 rename が通常 rename にすり替わっても結果は変わらない**
      // — 005 INV-002 が「flag が効くのは TOCTOU の窓だけ」と書いているとおりである。
      // したがって「no-replace が本当に使われているか」は、**確認を挟まない操作を
      // 直接叩く**ことでしか観測できない。
      //
      // この test が無いと、既定の排他 rename を通常 rename へすり替えても、
      // 既定を常に `unsupported` にしても、suite は緑のままになる。
      final source = await makeFile('a.txt', 'source-body');
      final keep = await makeFile('keep.txt', 'keep-body');

      final result = await androidRenameOperation()(source, keep);

      expect(
        result,
        NativeRenameResult.nameConflict,
        reason: '実の renameat2(RENAME_NOREPLACE) が効いている',
      );
      expect(
        await File(keep).readAsString(),
        'keep-body',
        reason: '既存の実体を置換しない(005 INV-002)',
      );
      expect(await File(source).readAsString(), 'source-body');
    });

    test('`plainRename` を省いても、劣化経路が実 file を改名する', () async {
      // **`plainRename` の既定だけを検査する。** 排他 rename が使えない環境を作れ
      // ないので、そこだけ注入して**既定を1つ残す**。
      final source = await makeFile('a.txt', 'body');
      final executor = createAndroidRenameExecutor(
        exclusiveRename: (_, _) async => NativeRenameResult.unsupported,
      );

      final result = await executor.rename(source, 'b.txt');

      expect(
        result,
        isA<Renamed>(),
        reason: '既定の `plainRenameFile` が実 file を動かしている(013 REQ-005)',
      );
      expect(await File(p.join(dir.path, 'b.txt')).readAsString(), 'body');
    });
  });

  group('factory が劣化経路を必ず通す', () {
    test('`exclusiveRename` が unsupported を返すと通常 rename が呼ばれる', () async {
      final source = await makeFile('a.txt', 'body');
      var plainCalled = false;
      final executor = createAndroidRenameExecutor(
        exclusiveRename: (_, _) async => NativeRenameResult.unsupported,
        plainRename: (from, to) async {
          plainCalled = true;
          File(from).renameSync(to);
          return NativeRenameResult.success;
        },
      );

      expect(await executor.rename(source, 'b.txt'), isA<Renamed>());
      expect(plainCalled, isTrue);
    });

    test('`exclusiveRename` が成功すれば通常 rename は呼ばれない', () async {
      final source = await makeFile('a.txt', 'body');
      var plainCalled = false;
      final executor = createAndroidRenameExecutor(
        exclusiveRename: (from, to) async {
          File(from).renameSync(to);
          return NativeRenameResult.success;
        },
        plainRename: (_, _) async {
          plainCalled = true;
          return NativeRenameResult.success;
        },
      );

      expect(await executor.rename(source, 'b.txt'), isA<Renamed>());
      expect(plainCalled, isFalse, reason: 'no-replace が効いたので落とさない');
    });
  });

  group('platform 分岐', () {
    test('Android は UTF-8 path の wrapper を使う', () {
      // **Android を分岐から外すと落ちる。** `Platform.isAndroid` を条件式へ直接
      // 書いていた頃は、Linux 上の test から観測できず外しても緑のままだった。
      expect(usesUtf8NativePath('android'), isTrue);
    });

    test('linux / macos も UTF-8、windows と未知の OS は使わない', () {
      expect(usesUtf8NativePath('linux'), isTrue);
      expect(usesUtf8NativePath('macos'), isTrue);
      expect(usesUtf8NativePath('windows'), isFalse);
      expect(usesUtf8NativePath('fuchsia'), isFalse);
    });
  });

  group('`plainRenameFile` の errno 写像', () {
    test('対象が無ければ notFound', () async {
      final result = await plainRenameFile(
        p.join(dir.path, 'missing.txt'),
        p.join(dir.path, 'b.txt'),
      );

      expect(
        result,
        NativeRenameResult.notFound,
        reason: '`io` へ丸めない — 呼び出し側は分類で経路を分ける(005 OP-004)',
      );
    });

    test('書き込めない folder では permissionDenied', () async {
      // 受け入れ証拠「権限が無い場合…の分類をtestで検査する」。
      // read-only directory は非 root でも作れる(EACCES)。
      final locked = Directory(p.join(dir.path, 'locked'))..createSync();
      final source = File(p.join(locked.path, 'a.txt'))..writeAsStringSync('x');
      await Process.run('chmod', ['555', locked.path]);
      addTearDown(() async {
        await Process.run('chmod', ['755', locked.path]);
      });

      final result = await plainRenameFile(
        source.path,
        p.join(locked.path, 'b.txt'),
      );

      expect(
        result,
        NativeRenameResult.permissionDenied,
        reason: '`io` へ丸めない(005 OP-004 の errors)',
      );
    });
  });
}
