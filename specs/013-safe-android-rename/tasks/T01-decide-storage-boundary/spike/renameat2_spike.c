// 013:T01 spike S-2 — renameat2(RENAME_NOREPLACE) がAndroidの共有storageで
// 有効かを観測する。
//
// 何を知りたいか:
//   005の INV-002「既存fileを置換しない」をAndroidで満たせるかは、
//   RENAME_NOREPLACE が実際に効くかで決まる。Android 11以降の /sdcard は
//   MediaProvider の FUSE を経由するため、フラグが素通りするとは限らない。
//
// 使い方:
//   ./renameat2_spike <作業ディレクトリ>
//   例: ./renameat2_spike /sdcard        (FUSE。本番)
//       ./renameat2_spike /data/local/tmp (ext4。対照)
//
// このプログラムは自分でfixtureを作り、終了時に片付ける。引数のディレクトリに
// spike-c.txt / spike-d.txt / spike-e.txt を一時的に作る。既に同名のfileが
// あれば何もせず終了する(利用者のfileを壊さない)。

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

// SYS_renameat2 が headerに無い環境でも呼べるようにarch別の番号を用意する。
#ifndef SYS_renameat2
#if defined(__aarch64__)
#define SYS_renameat2 276
#elif defined(__x86_64__)
#define SYS_renameat2 316
#elif defined(__arm__)
#define SYS_renameat2 382
#elif defined(__i386__)
#define SYS_renameat2 353
#else
#error "SYS_renameat2 unknown for this architecture"
#endif
#endif

static int renameat2_raw(const char *from, const char *to, unsigned int flags) {
  return (int)syscall(SYS_renameat2, AT_FDCWD, from, AT_FDCWD, to, flags);
}

static int write_file(const char *path, const char *text) {
  FILE *f = fopen(path, "w");
  if (!f) return -1;
  fputs(text, f);
  return fclose(f);
}

// path の中身を buf へ読む。読めなければ 0 を返す。
static int read_file(const char *path, char *buf, size_t n) {
  FILE *f = fopen(path, "r");
  if (!f) return 0;
  size_t got = fread(buf, 1, n - 1, f);
  buf[got] = '\0';
  fclose(f);
  return 1;
}

static int exists(const char *path) {
  struct stat st;
  return stat(path, &st) == 0;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s <directory>\n", argv[0]);
    return 2;
  }
  const char *dir = argv[1];

  char src[512], dst[512], missing[512];
  snprintf(src, sizeof(src), "%s/spike-c.txt", dir);
  snprintf(dst, sizeof(dst), "%s/spike-d.txt", dir);
  snprintf(missing, sizeof(missing), "%s/spike-e.txt", dir);

  if (exists(src) || exists(dst) || exists(missing)) {
    fprintf(stderr,
            "ERROR: %s に spike-c/d/e.txt のいずれかが既にあります。\n"
            "利用者のfileを壊さないため中止します。先に消してください。\n",
            dir);
    return 2;
  }

  printf("=== renameat2(RENAME_NOREPLACE) spike ===\n");
  printf("directory: %s\n\n", dir);

  // --- case 1: target が既にある(本命) ---
  if (write_file(src, "SOURCE") != 0 || write_file(dst, "TARGET") != 0) {
    fprintf(stderr, "ERROR: fixtureを作れません: %s\n", strerror(errno));
    return 2;
  }

  errno = 0;
  int r1 = renameat2_raw(src, dst, RENAME_NOREPLACE);
  int e1 = errno;

  char body[64] = {0};
  int dst_readable = read_file(dst, body, sizeof(body));
  int target_intact = dst_readable && strcmp(body, "TARGET") == 0;

  printf("[case 1] target あり: spike-c.txt -> spike-d.txt\n");
  printf("  戻り値 : %d\n", r1);
  printf("  errno  : %d (%s)\n", e1, r1 == 0 ? "-" : strerror(e1));
  printf("  spike-d.txt の中身 : %s\n", dst_readable ? body : "(読めない)");
  printf("  target は無傷か    : %s\n\n", target_intact ? "YES" : "NO");

  // --- case 2: target が無い(対照。通常のrenameが動くことの確認) ---
  const char *src2 = exists(src) ? src : dst;  // case 1 の結果で場所が変わる
  errno = 0;
  int r2 = renameat2_raw(src2, missing, RENAME_NOREPLACE);
  int e2 = errno;

  printf("[case 2] target なし: %s -> spike-e.txt\n", src2);
  printf("  戻り値 : %d\n", r2);
  printf("  errno  : %d (%s)\n\n", e2, r2 == 0 ? "-" : strerror(e2));

  // --- 判定 ---
  printf("=== 判定 ===\n");
  if (r1 == -1 && e1 == EEXIST && target_intact) {
    printf("A) RENAME_NOREPLACE は有効。候補Eは成立しうる。\n");
  } else if (r1 == -1 && (e1 == EINVAL || e1 == ENOSYS)) {
    printf("B) このpathではフラグを解釈できない(errno=%s)。候補Eは不成立。\n",
           strerror(e1));
  } else if (r1 == 0) {
    printf("C) フラグが無視され、既存fileを置換した。候補Eは不成立、かつ危険。\n");
  } else {
    printf("D) 想定外。戻り値=%d errno=%d(%s)。上の生の値をそのまま報告する。\n",
           r1, e1, strerror(e1));
  }
  if (r2 != 0) {
    printf("   注意: target が無い場合の rename も失敗している。\n"
           "   この環境ではそもそも書き込めていない可能性がある。\n");
  }

  // --- 片付け ---
  unlink(src);
  unlink(dst);
  unlink(missing);
  printf("\nfixtureを削除しました。\n");
  return 0;
}
