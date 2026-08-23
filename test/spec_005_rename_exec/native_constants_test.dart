// 013 VER-005: C の Android 分岐で自前に持っている ABI 定数と errno 写像を固定する。
//
// **source を正規表現で読むのをやめた**(ADR-003 の追補、独立review attempt 6)。
// 3回続けて「代用の source assert から漏れる」型の指摘が出た。
//
// 1. 1件ずつ `contains` する → 書き忘れた定数が黙って通る(attempt 4 / 5)
// 2. 表駆動の完全一致にする → **抽出器が認識できない書き方**が黙って通る(attempt 6)
//    (`default:` arm、1行形式の `case X: return Y;`、`#  define`、コメント内の `#define`)
//
// どちらも「**自分が想像できた形しか見ていない**」点で同じで、しかも fail-open
// (認識できなければ無視)なので、検査していない範囲を PASS として報告していた。
//
// **ここでは oracle を文字列から compiler と実 kernel header へ移す。**
//
// - `gcc -E -P` は コメント・`#if`・macro・書式差を**すべて解決した** token 列を返す。
//   errno は数値になる。「読めなかったので無視した」余地が構造的に無い。
// - ABI 定数は `gcc -E -dM -nostdinc` で **arch ごとに**取り出し、その arch の
//   **実 kernel uapi header** と `_Static_assert` で突き合わせる。
//
// **Android 向けの compile と実機確認はここでは行えない**(AI container に SDK / NDK が
// 無い)。`renameat2` が実際に効くかは `013:T08` が見る。
@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _abiHeader = 'src/brm_renameat2_abi.h';
const _source = 'src/native_exclusive_rename.c';

/// arch macro を1つだけ立てるための打ち消し。compiler が host arch を
/// 自動で定義するので、消さないと常に host の枝が選ばれる。
const _undefArch = ['-U__x86_64__', '-U__aarch64__', '-U__arm__', '-U__i386__'];

ProcessResult _gcc(List<String> args) => Process.runSync('gcc', args);

/// [arch] を立てて ABI header だけを preprocess し、`#define` を読み取る。
Map<String, String> _abiFor(String? arch) {
  final result = _gcc([
    '-E',
    '-dM',
    '-nostdinc',
    ..._undefArch,
    if (arch != null) '-D$arch',
    _abiHeader,
  ]);
  final defines = <String, String>{};
  for (final line in (result.stdout as String).split('\n')) {
    final match = RegExp(r'^#define (BRM_\w+) (.*)$').firstMatch(line.trim());
    if (match != null) defines[match.group(1)!] = match.group(2)!.trim();
  }
  return defines;
}

/// `brm_result_from_errno` を preprocess 後の形で読み、`errno 番号 -> 結果` を返す。
///
/// **fail-closed である。** switch 本体に既知でない token が出たら例外を投げる。
/// 「認識できなかったので無視する」は、まさに attempt 6 で破られた前提である。
Map<int, String> _errnoMapping({required bool android}) {
  final result = _gcc(['-E', '-P', if (android) '-D__ANDROID__', _source]);
  if (result.exitCode != 0) {
    throw StateError('preprocess に失敗した: ${result.stderr}');
  }
  final text = result.stdout as String;
  final start = text.indexOf('brm_result_from_errno');
  // `switch (error) {` の**中身だけ**を見る。前置きを含めると、それ自体が
  // 「既知でない token」になって読み取りが止まる。
  final body = text.substring(
    text.indexOf('{', text.indexOf('switch', start)) + 1,
    text.indexOf('\n}', start),
  );

  final mapping = <int, String>{};
  final pending = <int>[];
  // preprocess 後は改行位置が当てにならないので、token 単位で読む。
  final tokens = RegExp(
    r'case\s+(-?\d+)\s*:|default\s*:|return\s+(BRM_RENAME_\w+)\s*;|(\S+)',
  ).allMatches(body);
  for (final token in tokens) {
    if (token.group(1) != null) {
      pending.add(int.parse(token.group(1)!));
      continue;
    }
    if (token.group(2) != null) {
      for (final errno in pending) {
        mapping[errno] = token.group(2)!;
      }
      // `default:` は errno を持たないので -1 で表す。**表に必ず現れる。**
      if (pending.isEmpty) mapping[-1] = token.group(2)!;
      pending.clear();
      continue;
    }
    final other = token.group(3);
    if (other == null) continue;
    // switch 本体の閉じ括弧だけを見逃す。それ以外は必ず表へ載せる。
    if (other == '}') continue;
    throw StateError(
      'switch 本体に既知でない token がある: `$other`。'
      '新しい書き方を足したなら、この読み取りを更新して表へ載せること',
    );
  }
  return mapping;
}

void main() {
  setUpAll(() {
    final probe = _gcc(['--version']);
    if (probe.exitCode != 0) {
      throw StateError('この検査は gcc を必要とする');
    }
  });

  group('ABI 定数(arch ごとに preprocessor から取り出す)', () {
    // 実 kernel uapi header と突き合わせる arch。`__arm__` はこの環境に header が
    // 無いので照合できない(`013:T08` が実機で取る)。
    const verifiable = {
      '__x86_64__': 'asm/unistd_64.h',
      '__i386__': 'asm/unistd_32.h',
      '__aarch64__': 'asm-generic/unistd.h',
    };
    const unverified = {'__arm__': 382};

    test('flag は `RENAME_NOREPLACE` と一致する(`RENAME_EXCHANGE` ではない)', () {
      final value = _abiFor('__x86_64__')['BRM_RENAME_NOREPLACE'];
      expect(value, isNotNull, reason: 'header から値を取り出せる');

      final dir = Directory.systemTemp.createTempSync('brm-abi-flag-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final probe = File(p.join(dir.path, 'probe.c'))
        ..writeAsStringSync('''
#define _GNU_SOURCE
#include <stdio.h>
_Static_assert($value == RENAME_NOREPLACE, "flag");
''');

      final result = _gcc(['-fsyntax-only', probe.path]);
      expect(
        result.exitCode,
        0,
        reason: '実 kernel header と一致しない: ${result.stderr}',
      );
    });

    for (final entry in verifiable.entries) {
      test('${entry.key} の syscall 番号が ${entry.value} と一致する', () {
        final value = _abiFor(entry.key)['BRM_SYS_RENAMEAT2'];
        expect(value, isNotNull, reason: 'この arch の枝が値を持つ');

        // **header を1つだけ include した独立 TU で見る。** 他の arch の header が
        // 先に読まれていると `__NR_renameat2` が別の値に解決される。
        final dir = Directory.systemTemp.createTempSync('brm-abi-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final probe = File(p.join(dir.path, 'probe.c'))
          ..writeAsStringSync('''
#include <${entry.value}>
_Static_assert($value == __NR_renameat2, "${entry.key}");
''');

        final result = _gcc(['-fsyntax-only', probe.path]);
        expect(
          result.exitCode,
          0,
          reason: '実 kernel header と一致しない: ${result.stderr}',
        );
      });
    }

    test('照合できない arch も値を持つ(未照合であることを明示する)', () {
      unverified.forEach((arch, expected) {
        expect(
          _abiFor(arch)['BRM_SYS_RENAMEAT2'],
          '$expected',
          reason: '$arch は header が無く照合できない。`013:T08` が実機で取る',
        );
      });
    });

    test('知らない arch は `#error` で止まる(黙って別の値を使わない)', () {
      final result = _gcc(['-E', '-nostdinc', ..._undefArch, _abiHeader]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('unknown for this architecture'));
    });

    test('`native_exclusive_rename.c` が両分岐で compile 前検査を通る', () {
      // ここが落ちるのは `_Static_assert` が破れたときである。
      for (final args in [
        ['-fsyntax-only', '-Wall', '-Wextra', _source],
        ['-fsyntax-only', '-Wall', '-Wextra', '-D__ANDROID__', _source],
      ]) {
        final result = _gcc(args);
        expect(
          result.exitCode,
          0,
          reason: '${args.join(' ')}: ${result.stderr}',
        );
      }
    });
  });

  group('errno 写像(preprocess 後の数値で突き合わせる)', () {
    // 値は `errno.h` の Linux/glibc のもの。preprocess 後は数値になるので、
    // 名前ではなく**実際に compile される値**を見ている。
    const eperm = 1;
    const enoent = 2;
    const eio = 5;
    const eacces = 13;
    const eexist = 17;
    const exdev = 18;
    const enotdir = 20;
    const einval = 22;
    const enosys = 38;
    const enotempty = 39;
    const erofs = 30;
    const eopnotsupp = 95; // == ENOTSUP

    const shared = {
      eexist: 'BRM_RENAME_NAME_CONFLICT',
      enotempty: 'BRM_RENAME_NAME_CONFLICT',
      enoent: 'BRM_RENAME_NOT_FOUND',
      enotdir: 'BRM_RENAME_NOT_FOUND',
      eacces: 'BRM_RENAME_PERMISSION_DENIED',
      eperm: 'BRM_RENAME_PERMISSION_DENIED',
      erofs: 'BRM_RENAME_PERMISSION_DENIED',
      // `default:` は -1 で表す。**表に必ず現れるので、書き換えれば落ちる。**
      -1: 'BRM_RENAME_IO',
    };

    test('desktop は劣化を要求しない', () {
      expect(_errnoMapping(android: false), {
        ...shared,
        enosys: 'BRM_RENAME_UNSUPPORTED',
        eopnotsupp: 'BRM_RENAME_UNSUPPORTED',
      });
    });

    test('Android だけが劣化を要求する(013 REQ-005 / VER-005)', () {
      expect(_errnoMapping(android: true), {
        ...shared,
        // `EINVAL` = filesystem が flag を解釈できない(FUSE 経由の共有 storage)。
        einval: 'BRM_RENAME_FALLBACK_REQUIRED',
        // `ENOSYS` = kernel に `renameat2` が無い(spec D-1 が想定した端末)。
        enosys: 'BRM_RENAME_FALLBACK_REQUIRED',
        eopnotsupp: 'BRM_RENAME_FALLBACK_REQUIRED',
      });
    });

    test('desktop と Android の差は劣化の要否だけである', () {
      final desktop = _errnoMapping(android: false);
      final android = _errnoMapping(android: true);
      final changed = {
        for (final key in {...desktop.keys, ...android.keys})
          if (desktop[key] != android[key]) key,
      };
      // `EINVAL` は desktop では `default` の `IO` へ落ちるので表に現れない。
      expect(changed, {einval, enosys, eopnotsupp});
      // 実害の向きも見る: 変わるのは「劣化してよい」側だけ。
      for (final key in changed) {
        expect(android[key], 'BRM_RENAME_FALLBACK_REQUIRED');
      }
      expect(desktop[exdev], isNull, reason: 'EXDEV は default の IO へ落ちる');
      expect(desktop[eio], isNull);
    });
  });
}
