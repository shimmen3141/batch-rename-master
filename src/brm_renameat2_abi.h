/* Android で `renameat2` を生の syscall で呼ぶための ABI 定数。
 *
 * **この file は何も include しない。** そのおかげで
 * `gcc -E -dM -nostdinc -D<arch>` だけで arch ごとの値を取り出せる —
 * `test/spec_005_rename_exec/native_constants_test.dart` がそうして値を読み、
 * **実 kernel header と突き合わせる**。system header を含むと、arch macro を
 * 差し替えた時点で header 側が壊れて値を取り出せない(独立review attempt 6 の
 * 対応で実測した)。
 *
 * **自前の名前を持つ**(`RENAME_NOREPLACE` / `SYS_renameat2` へ `#ifndef` で
 * 譲らない)。譲る形だと、system が定義している環境では自前の値がそもそも
 * 展開されず、**間違っていても誰も気づけない**。
 *
 * `native_exclusive_rename.c` の `_Static_assert` は、**その位置での macro 値**が
 * system 定義と一致することしか見ない(後で `#undef` されれば効かない)。
 * **実際に syscall へ渡る値**は `test/spec_005_rename_exec/native_behaviour_test.dart`
 * が shim 経由で観測する。独立review attempt 7 の指摘。
 */
#ifndef BRM_RENAMEAT2_ABI_H
#define BRM_RENAMEAT2_ABI_H

/* `(1 << 1)` は `RENAME_EXCHANGE`(交換)である。効くと2つの file が黙って
 * 入れ替わり、005 INV-002 / OP-004 が破れる。 */
#define BRM_RENAME_NOREPLACE (1 << 0)

/* 出典: 013:T01 の spike(検証済みの参照実装)。
 * `__arm__` 以外はこの環境の kernel uapi header と照合済み。 */
#if defined(__aarch64__)
#define BRM_SYS_RENAMEAT2 276
#elif defined(__x86_64__)
#define BRM_SYS_RENAMEAT2 316
#elif defined(__arm__)
#define BRM_SYS_RENAMEAT2 382
#elif defined(__i386__)
#define BRM_SYS_RENAMEAT2 353
#else
#error "SYS_renameat2 unknown for this architecture"
#endif

#endif /* BRM_RENAMEAT2_ABI_H */
