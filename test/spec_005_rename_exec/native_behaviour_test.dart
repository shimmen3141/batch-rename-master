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
// 差し替えて製品の関数をそのまま呼び、**この関数の入口と出口**を観測する —
// 渡った syscall 番号・flag・dirfd・path、呼び出し回数、errno から返る結果。
//
// **入力空間を全走査する。** errno を 0〜255 まで回す(Linux の errno は
// `EHWPOISON` = 133 まで)。**手書きの errno 表を持たない** — attempt 9 は、表に
// 載っていない errno で分類を書き換えると誰も気づかないことを対照実験で示した。
// 手書きにしてよいのは「何が正しいか」(下の [_expected] = 仕様)であって、
// 「どれを調べるか」ではない。
//
// **この検査で見ていないもの。**
//
// - **host(x86_64)以外の arch の syscall 番号。** host 上でしか実行できない。
//   他 arch は `native_constants_test.dart` が実 kernel header と突き合わせ、
//   `__arm__` は照合手段が無いので `013:T08` の実機確認が引き受ける。
// - **Android 向けの実 compile と実機挙動。** NDK が無い。`013:T08` が見る。
// - **Windows 分岐。** この環境で compile できない。
//
// それ以外については、**渡る値・返る値が変われば落ちる** — `if` 文でも、
// 呼び出し側でも、`#undef` でも、補助関数でも、表に無い errno でも。

@Tags(['native'])
library;

import 'dart:io';

import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _source = 'src/native_exclusive_rename.c';
const _harness = 'test/native/renameat2_harness.c';

/// 観測1件。**6引数すべてと呼び出し回数を持つ。**
///
/// 番号と flag だけを見ていたときは、引数の入れ替え・dirfd の差し替え・
/// 「先に別の flag で1回呼ぶ」が素通りした(独立review attempt 8 の P1-1)。
typedef _Observation = ({
  int syscallNumber,
  int flags,
  int oldDirFd,
  int newDirFd,
  String oldPath,
  String newPath,
  int calls,
  int atFdCwd,
  NativeRenameResult result,
});

/// この関数が満たすべき写像(**仕様**)。errno の全域に対する総関数である。
///
/// **手書きなのは仕様だから**である。どの入力を調べるかは機械が決める(全走査)。
NativeRenameResult _expected(int errno, {required bool android}) =>
    switch (errno) {
      0 => NativeRenameResult.success,
      17 /* EEXIST */ || 39 /* ENOTEMPTY */ => NativeRenameResult.nameConflict,
      2 /* ENOENT */ || 20 /* ENOTDIR */ => NativeRenameResult.notFound,
      1 /* EPERM */ ||
      13 /* EACCES */ ||
      30 /* EROFS */ => NativeRenameResult.permissionDenied,
      // `EINVAL` = filesystem が flag を解釈できない(FUSE 経由の共有 storage)。
      // `ENOSYS` = kernel に `renameat2` が無い(013 spec D-1 が想定した端末)。
      // `ENOTSUP`(= `EOPNOTSUPP` = 95)も同じ扱い。
      // **Android だけが「落としてよい」と言う**(013 REQ-005 / VER-005)。
      // desktop では `EINVAL` は `io`、`ENOSYS` / `ENOTSUP` は `unsupported` である。
      22 /* EINVAL */ =>
        android ? NativeRenameResult.fallbackRequired : NativeRenameResult.io,
      38 /* ENOSYS */ || 95 /* ENOTSUP */ =>
        android
            ? NativeRenameResult.fallbackRequired
            : NativeRenameResult.unsupported,
      // **残りはすべて `io`。** 上へ書き足さない限り、どの errno も劣化を要求しない。
      _ => NativeRenameResult.io,
    };

/// harness を組み立てて実行し、`errno -> 観測` を返す。
Map<int, _Observation> _observe({
  required bool android,
  bool unsupported = false,
}) {
  final dir = Directory.systemTemp.createTempSync('brm-harness-');
  addTearDown(() => dir.deleteSync(recursive: true));
  final binary = p.join(dir.path, 'harness');

  final build = Process.runSync('gcc', [
    '-o',
    binary,
    // 未対応 platform 分岐は OS を呼ばないので shim も要らない。
    if (unsupported)
      '-DBRM_UNSUPPORTED_PLATFORM'
    else if (android) ...[
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

  final observations = <int, _Observation>{};
  for (final line in (run.stdout as String).trim().split('\n')) {
    final match = RegExp(
      r'^errno=(\d+) nr=(-?\d+) flags=(\d+) olddirfd=(-?\d+) newdirfd=(-?\d+) '
      r'oldpath=(\S*) newpath=(\S*) calls=(\d+) atfdcwd=(-?\d+) '
      r'result=(-?\d+)$',
    ).firstMatch(line.trim());
    if (match == null) {
      // **読めない行を捨てない。** それが4回続いた漏れの作り方である。
      throw StateError('harness の出力を読めない: `$line`');
    }
    final code = int.parse(match.group(10)!);
    if (code < 0 || code >= NativeRenameResult.values.length) {
      throw StateError('未知の結果コード $code が返った: `$line`');
    }
    observations[int.parse(match.group(1)!)] = (
      syscallNumber: int.parse(match.group(2)!),
      flags: int.parse(match.group(3)!),
      oldDirFd: int.parse(match.group(4)!),
      newDirFd: int.parse(match.group(5)!),
      oldPath: match.group(6)!,
      newPath: match.group(7)!,
      calls: int.parse(match.group(8)!),
      atFdCwd: int.parse(match.group(9)!),
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

  for (final android in [true, false]) {
    final label = android ? 'Android' : 'desktop';
    group('$label: 製品の関数を実際に呼んで観測する', () {
      late Map<int, _Observation> observed;
      setUpAll(() {
        observed = _observe(android: android);
      });

      test('errno の全域(0〜255)を観測している', () {
        expect(observed.keys.toSet(), {for (var e = 0; e <= 255; e++) e});
      });

      test('`RENAME_NOREPLACE` だけを渡す(`RENAME_EXCHANGE` を混ぜない)', () {
        // **実際に渡った値**を見る。`1` 以外はすべて別の意味になる —
        // `2` は交換(2つの file が黙って入れ替わる)、`3` は kernel が `EINVAL` を
        // 返して常時劣化する。005 INV-002 / OP-004。
        for (final entry in observed.entries) {
          expect(entry.value.flags, 1, reason: 'errno=${entry.key}');
        }
      });

      test('引数は「現在のdirectory基準で source を destination へ」1回だけである', () {
        for (final entry in observed.entries) {
          final o = entry.value;
          expect(o.calls, 1, reason: 'errno=${entry.key}: 呼び出し回数');
          expect(o.oldPath, 'source', reason: 'errno=${entry.key}: 元の path');
          expect(
            o.newPath,
            'destination',
            reason: 'errno=${entry.key}: 目標の path',
          );
          // 入れ替わると改名が逆向きになり、013 REQ-005 / REQ-006 が製品として
          // 一切成立しない(常に notFound)。
          expect(o.oldDirFd, o.atFdCwd, reason: 'errno=${entry.key}: 元の dirfd');
          expect(
            o.newDirFd,
            o.atFdCwd,
            reason: 'errno=${entry.key}: 目標の dirfd',
          );
        }
      });

      test('errno から結果への写像が、全域で仕様どおりである', () {
        expect(
          {for (final e in observed.entries) e.key: e.value.result},
          {
            for (var errno = 0; errno <= 255; errno++)
              errno: _expected(errno, android: android),
          },
        );
      });

      if (android) {
        test('`renameat2` を host arch の番号で呼ぶ(wrapper を経由しない)', () {
          // 他 arch の番号は `native_constants_test.dart` が実 kernel header と
          // 突き合わせる(host 上では実行できないため)。
          expect(observed[0]!.syscallNumber, 316);
        });
      } else {
        test('劣化を一度も要求しない(005 INV-002 の保証を弱めない)', () {
          for (final entry in observed.entries) {
            expect(
              entry.value.result,
              isNot(NativeRenameResult.fallbackRequired),
              reason: 'errno=${entry.key} が desktop で劣化を要求している',
            );
          }
        });
      }
    });
  }

  test('Android と desktop の差は「劣化してよいか」だけである', () {
    final android = _observe(android: true);
    final desktop = _observe(android: false);
    final changed = {
      for (final key in android.keys)
        if (android[key]!.result != desktop[key]!.result) key,
    };
    expect(changed, {22 /* EINVAL */, 38 /* ENOSYS */, 95 /* ENOTSUP */});
    for (final key in changed) {
      expect(android[key]!.result, NativeRenameResult.fallbackRequired);
    }
  });

  test('未対応 platform は OS を一切呼ばず、常に unsupported を返す', () {
    // `hook/build.dart` が iOS へ渡す `BRM_UNSUPPORTED_PLATFORM` の分岐。
    // ここが劣化を要求すると、**改名できない platform で通常 rename へ落ちる**
    // (独立review attempt 9 の P2-1。source assert は desktop 分岐の同じ文字列で
    // 満たされていて、この分岐を固定していなかった)。
    final observed = _observe(android: false, unsupported: true);

    expect(observed.keys.toSet(), {for (var e = 0; e <= 255; e++) e});
    for (final entry in observed.entries) {
      expect(
        entry.value.result,
        NativeRenameResult.unsupported,
        reason: 'errno=${entry.key}',
      );
      expect(entry.value.calls, 0, reason: 'errno=${entry.key}: OS を呼んでいる');
    }
  });
}
