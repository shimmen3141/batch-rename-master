/* `src/native_exclusive_rename.c` を **Linux 上で実際に呼んで**、
 * 「syscall へ渡した番号と flag」「errno から返る結果」を観測する harness。
 *
 * **source を読む検査をやめるためにある。** `013:T05` では
 * 「C の Android 分岐が代用の source assert から漏れる」型の指摘が4回続いた
 * (attempt 4 / 5 / 6 / 7)。毎回**別の書き方**で漏れており、読み取りを賢くする
 * 方向では閉じない — `if` 文、呼び出し側、`#undef` して再定義、補助関数、書式差。
 *
 * ここでは書き方に一切依存しない。**実際に渡った値**を見る。
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
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* 観測した値。 */
static long observed_nr = -1;
static unsigned int observed_flags = 0xffffffffu;
/* shim が返す errno。0 なら成功を返す。 */
static int scripted_errno = 0;

int32_t brm_rename_no_replace_utf8(const char *source, const char *destination);

#if defined(__ANDROID__)
/* `unistd.h` の `long syscall(long, ...)` がこの名前に置き換わっている。 */
long brm_test_syscall(long number, ...) {
  va_list args;
  va_start(args, number);
  (void)va_arg(args, int);         /* olddirfd */
  (void)va_arg(args, const char *); /* oldpath */
  (void)va_arg(args, int);         /* newdirfd */
  (void)va_arg(args, const char *); /* newpath */
  observed_flags = va_arg(args, unsigned int);
  va_end(args);
  observed_nr = number;
  if (scripted_errno == 0) return 0;
  errno = scripted_errno;
  return -1;
}
#else
/* desktop 側は glibc の `renameat2` wrapper を経由する。 */
int brm_test_renameat2(int olddirfd, const char *oldpath, int newdirfd,
                       const char *newpath, unsigned int flags) {
  (void)olddirfd;
  (void)oldpath;
  (void)newdirfd;
  (void)newpath;
  observed_flags = flags;
  observed_nr = 0; /* wrapper 経由なので番号は観測できない */
  if (scripted_errno == 0) return 0;
  errno = scripted_errno;
  return -1;
}
#endif

/* 観測したい errno。名前ではなく **compile される値** で回す。 */
static const struct {
  const char *name;
  int value;
} cases[] = {
    {"SUCCESS", 0},   {"EPERM", EPERM},     {"ENOENT", ENOENT},
    {"EIO", EIO},     {"EACCES", EACCES},   {"EEXIST", EEXIST},
    {"EXDEV", EXDEV}, {"ENOTDIR", ENOTDIR}, {"EINVAL", EINVAL},
    {"EROFS", EROFS}, {"ENOSYS", ENOSYS},   {"ENOTEMPTY", ENOTEMPTY},
    {"ENOTSUP", ENOTSUP}, {"ENAMETOOLONG", ENAMETOOLONG},
};

int main(void) {
  for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
    observed_nr = -1;
    observed_flags = 0xffffffffu;
    scripted_errno = cases[i].value;
    errno = 0;
    const int32_t result = brm_rename_no_replace_utf8("source", "destination");
    printf("%s nr=%ld flags=%u result=%d\n", cases[i].name, observed_nr,
           observed_flags, (int)result);
  }
  return 0;
}
