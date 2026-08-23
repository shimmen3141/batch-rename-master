/* `src/native_exclusive_rename.c` を **Linux 上で実際に呼んで**、
 * 「syscall へ渡した番号と flag」「errno から返る結果」を観測する harness。
 *
 * **source を読む検査をやめるためにある。** `013:T05` では
 * 「C の Android 分岐が代用の source assert から漏れる」型の指摘が4回続いた
 * (attempt 4 / 5 / 6 / 7)。毎回**別の書き方**で漏れており、読み取りを賢くする
 * 方向では閉じない — `if` 文、呼び出し側、`#undef` して再定義、補助関数、書式差。
 *
 * ここでは**この関数の入口と出口**を見る。渡った syscall 番号・flag・dirfd・path と、
 * 呼び出し回数、そして errno から返る結果。source の書き方には依存しない。
 *
 * **観測できないもの**(独立review attempt 8 の指摘): host 以外の arch の syscall 番号。
 * host(x86_64)でしか実行できないので、他 arch の値は
 * `native_constants_test.dart` が実 kernel header と突き合わせ、`__arm__` は
 * `013:T08` の実機確認が引き受ける。
 *
 * 使い方(`test/spec_005_rename_exec/native_behaviour_test.dart` が組み立てる):
 *
 *   Android: gcc -D__ANDROID__ -Dsyscall=brm_test_syscall \
 *              src/native_exclusive_rename.c test/native/renameat2_harness.c
 *   desktop: gcc -Drenameat2=brm_test_renameat2 \
 *              src/native_exclusive_rename.c test/native/renameat2_harness.c
 *
 * `-D` は identifier ごと置き換えるので、system header の宣言もこの shim を指す。
 * したがって**製品の呼び出しはそのまま**で、行き先だけが差し替わる。
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* 観測した値。**6引数すべてと呼び出し回数を見る。** 2つ(番号と flag)しか見ないと、
 * 引数の入れ替えや dirfd の差し替え、「先に別の flag で1回呼ぶ」が素通りする
 * (独立review attempt 8 の P1-1)。 */
static long observed_nr = -1;
static unsigned int observed_flags = 0xffffffffu;
static int observed_olddirfd = 0x7fffffff;
static int observed_newdirfd = 0x7fffffff;
static char observed_oldpath[256] = "";
static char observed_newpath[256] = "";
static int observed_calls = 0;
/* shim が返す errno。0 なら成功を返す。 */
static int scripted_errno = 0;

int32_t brm_rename_no_replace_utf8(const char *source, const char *destination);

#if defined(BRM_UNSUPPORTED_PLATFORM)
/* 未対応 platform 分岐は OS を一切呼ばない。shim も要らない。 */
#elif defined(__ANDROID__)
/* `unistd.h` の `long syscall(long, ...)` がこの名前に置き換わっている。 */
long brm_test_syscall(long number, ...) {
  va_list args;
  va_start(args, number);
  observed_olddirfd = va_arg(args, int);
  snprintf(observed_oldpath, sizeof(observed_oldpath), "%s",
           va_arg(args, const char *));
  observed_newdirfd = va_arg(args, int);
  snprintf(observed_newpath, sizeof(observed_newpath), "%s",
           va_arg(args, const char *));
  observed_flags = va_arg(args, unsigned int);
  va_end(args);
  observed_nr = number;
  observed_calls++;
  if (scripted_errno == 0) return 0;
  errno = scripted_errno;
  return -1;
}
#else
/* desktop 側は glibc の `renameat2` wrapper を経由する。 */
int brm_test_renameat2(int olddirfd, const char *oldpath, int newdirfd,
                       const char *newpath, unsigned int flags) {
  observed_olddirfd = olddirfd;
  observed_newdirfd = newdirfd;
  snprintf(observed_oldpath, sizeof(observed_oldpath), "%s", oldpath);
  snprintf(observed_newpath, sizeof(observed_newpath), "%s", newpath);
  observed_flags = flags;
  observed_nr = 0; /* wrapper 経由なので番号は観測できない */
  observed_calls++;
  if (scripted_errno == 0) return 0;
  errno = scripted_errno;
  return -1;
}
#endif

/* **手書きの errno 表を持たない。** 独立review attempt 9 は、表に載っていない errno
 * (`ENOSPC` など)で分類を書き換えると誰も気づかないことを**対照実験**で示した —
 * `switch` の前で `ENOSPC` を成功にした変異は SURVIVED、まったく同じ形で `EEXIST` に
 * しただけの変異は KILLED だった。差は「表に載っているか」だけである。
 *
 * 検査に手書きの列挙が1つでも残っていると、そこが次の穴になる(4世代・9回)。
 * **入力空間を全走査する。** Linux の errno は `EHWPOISON` = 133 までなので、
 * 0〜255 を回せば**全域**である。期待値は Dart 側が手書きの**仕様**として持つ —
 * 手書きにしてよいのは「何が正しいか」であって、「どれを調べるか」ではない。 */
#define BRM_TEST_ERRNO_MAX 255

int main(void) {
  for (int scripted = 0; scripted <= BRM_TEST_ERRNO_MAX; scripted++) {
    observed_nr = -1;
    observed_flags = 0xffffffffu;
    observed_olddirfd = 0x7fffffff;
    observed_newdirfd = 0x7fffffff;
    observed_oldpath[0] = '\0';
    observed_newpath[0] = '\0';
    observed_calls = 0;
    scripted_errno = scripted;
    errno = 0;
    const int32_t result = brm_rename_no_replace_utf8("source", "destination");
    /* `AT_FDCWD` は harness 側の header から取る(製品と独立した oracle)。 */
    printf("errno=%d nr=%ld flags=%u olddirfd=%d newdirfd=%d oldpath=%s "
           "newpath=%s calls=%d atfdcwd=%d result=%d\n",
           scripted, observed_nr, observed_flags, observed_olddirfd,
           observed_newdirfd, observed_oldpath, observed_newpath,
           observed_calls, AT_FDCWD, (int)result);
  }
  return 0;
}
