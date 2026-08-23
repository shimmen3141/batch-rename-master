// 013 VER-005: C の改名 wrapper を **Linux 上で実際に呼んで** 振る舞いを固定する。
//
// **source を読む検査をやめた。** `013:T05` では「C の Android 分岐が代用の
// source assert から漏れる」型の指摘が4回続いた(独立review attempt 4 / 5 / 6 / 7)。
// 毎回**別の書き方**で漏れている — errno の追加、自作 `#define` の値、1行形式、
// `default` arm、`#  define`、コメント内の `#define`、`if` 文での分岐、
// **呼び出し側での書き換え**、`_Static_assert` の後での `#undef` と再定義。
//
// 読み取りを賢くする方向では閉じない。**読める範囲の外**が毎回残るからである。
//
// ここでは `test/native/renameat2_harness.c` が `syscall` / `renameat2` を shim へ
// 差し替えて製品の関数をそのまま呼び、**実際に渡った syscall 番号と flag**、
// **errno から返る結果**を観測する。書き方に一切依存しない。
//
// **Android 向けの実 compile と実機挙動はここでは見ない**(AI container に NDK が
// 無い)。`renameat2` が本当に効くかは `013:T08` が実機で見る。
@Tags(['native'])
library;

import 'dart:io';

import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _source = 'src/native_exclusive_rename.c';
const _harness = 'test/native/renameat2_harness.c';

/// 観測1件。
typedef _Observation = ({
  int syscallNumber,
  int flags,
  NativeRenameResult result,
});

/// harness を組み立てて実行し、`errno 名 -> 観測` を返す。
Map<String, _Observation> _observe({required bool android}) {
  final dir = Directory.systemTemp.createTempSync('brm-harness-');
  addTearDown(() => dir.deleteSync(recursive: true));
  final binary = p.join(dir.path, 'harness');

  final build = Process.runSync('gcc', [
    '-o',
    binary,
    if (android) ...[
      '-D__ANDROID__',
      '-Dsyscall=brm_test_syscall',
    ]
    // desktop は glibc の wrapper を経由するので、そちらを差し替える。
    else
      '-Drenameat2=brm_test_renameat2',
    _source,
    _harness,
  ]);
  if (build.exitCode != 0) {
    throw StateError('harness の build に失敗した:\n${build.stderr}');
  }

  final run = Process.runSync(binary, []);
  if (run.exitCode != 0) {
    throw StateError('harness の実行に失敗した:\n${run.stderr}');
  }

  final observations = <String, _Observation>{};
  for (final line in (run.stdout as String).trim().split('\n')) {
    final match = RegExp(
      r'^(\w+) nr=(-?\d+) flags=(\d+) result=(-?\d+)$',
    ).firstMatch(line.trim());
    if (match == null) {
      // **読めない行を捨てない。** それが4回続いた漏れの作り方である。
      throw StateError('harness の出力を読めない: `$line`');
    }
    final code = int.parse(match.group(4)!);
    if (code < 0 || code >= NativeRenameResult.values.length) {
      throw StateError('未知の結果コード $code が返った: `$line`');
    }
    observations[match.group(1)!] = (
      syscallNumber: int.parse(match.group(2)!),
      flags: int.parse(match.group(3)!),
      result: NativeRenameResult.values[code],
    );
  }
  return observations;
}

void main() {
  setUpAll(() {
    if (Process.runSync('gcc', ['--version']).exitCode != 0) {
      throw StateError('この検査は gcc を必要とする');
    }
  });

  group('Android: 実際に呼ばれる syscall と flag', () {
    late Map<String, _Observation> observed;
    setUpAll(() {
      observed = _observe(android: true);
    });

    test('`renameat2` を x86_64 の番号で呼ぶ(wrapper を経由しない)', () {
      // host が x86_64 なのでこの値になる。他 arch の番号は
      // `native_constants_test.dart` が実 kernel header と突き合わせる。
      expect(observed['SUCCESS']!.syscallNumber, 316);
    });

    test('`RENAME_NOREPLACE` だけを渡す(`RENAME_EXCHANGE` を混ぜない)', () {
      // **実際に渡った値**を見る。`1` 以外はすべて別の意味になる —
      // `2` は交換(2つの file が黙って入れ替わる)、`3` は kernel が `EINVAL` を
      // 返して常時劣化する。005 INV-002 / OP-004。
      for (final entry in observed.entries) {
        expect(
          entry.value.flags,
          1,
          reason: '${entry.key} の呼び出しで flag が 1 ではない',
        );
      }
    });

    test('errno の分類(劣化を要求するのは3つだけ)', () {
      expect(
        {for (final e in observed.entries) e.key: e.value.result},
        {
          'SUCCESS': NativeRenameResult.success,
          'EEXIST': NativeRenameResult.nameConflict,
          'ENOTEMPTY': NativeRenameResult.nameConflict,
          'ENOENT': NativeRenameResult.notFound,
          'ENOTDIR': NativeRenameResult.notFound,
          'EACCES': NativeRenameResult.permissionDenied,
          'EPERM': NativeRenameResult.permissionDenied,
          'EROFS': NativeRenameResult.permissionDenied,
          // flag を解釈できない filesystem(FUSE 経由の共有 storage)。
          'EINVAL': NativeRenameResult.fallbackRequired,
          // kernel に `renameat2` が無い(013 spec D-1 が想定した端末)。
          'ENOSYS': NativeRenameResult.fallbackRequired,
          'ENOTSUP': NativeRenameResult.fallbackRequired,
          'EIO': NativeRenameResult.io,
          'EXDEV': NativeRenameResult.io,
          'ENAMETOOLONG': NativeRenameResult.io,
        },
      );
    });
  });

  group('desktop: 013 は振る舞いを変えない', () {
    late Map<String, _Observation> observed;
    setUpAll(() {
      observed = _observe(android: false);
    });

    test('`RENAME_NOREPLACE` だけを渡す', () {
      for (final entry in observed.entries) {
        expect(entry.value.flags, 1, reason: '${entry.key} の flag が 1 ではない');
      }
    });

    test('劣化を一度も要求しない(005 INV-002 の保証を弱めない)', () {
      for (final entry in observed.entries) {
        expect(
          entry.value.result,
          isNot(NativeRenameResult.fallbackRequired),
          reason: '${entry.key} が desktop で劣化を要求している',
        );
      }
    });

    test('errno の分類(`EINVAL` は io、`ENOSYS` は unsupported)', () {
      expect(
        {for (final e in observed.entries) e.key: e.value.result},
        {
          'SUCCESS': NativeRenameResult.success,
          'EEXIST': NativeRenameResult.nameConflict,
          'ENOTEMPTY': NativeRenameResult.nameConflict,
          'ENOENT': NativeRenameResult.notFound,
          'ENOTDIR': NativeRenameResult.notFound,
          'EACCES': NativeRenameResult.permissionDenied,
          'EPERM': NativeRenameResult.permissionDenied,
          'EROFS': NativeRenameResult.permissionDenied,
          'ENOSYS': NativeRenameResult.unsupported,
          'ENOTSUP': NativeRenameResult.unsupported,
          'EINVAL': NativeRenameResult.io,
          'EIO': NativeRenameResult.io,
          'EXDEV': NativeRenameResult.io,
          'ENAMETOOLONG': NativeRenameResult.io,
        },
      );
    });
  });

  test('Android と desktop の差は「劣化してよいか」だけである', () {
    final android = _observe(android: true);
    final desktop = _observe(android: false);
    final changed = {
      for (final key in android.keys)
        if (android[key]!.result != desktop[key]!.result) key,
    };
    expect(changed, {'EINVAL', 'ENOSYS', 'ENOTSUP'});
    for (final key in changed) {
      expect(android[key]!.result, NativeRenameResult.fallbackRequired);
    }
  });
}
