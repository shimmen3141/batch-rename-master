// 013:T01 spike S-2 — renameat2(RENAME_NOREPLACE) がAndroidの共有storageで
// 有効かを観測する。
//
// 何を知りたいか:
//   005の INV-002「既存fileを置換しない」をAndroidで満たせるかは、
//   RENAME_NOREPLACE が実際に効くかで決まる。Android 11以降の /sdcard は
//   MediaProvider の FUSE を経由するため、フラグが素通りするとは限らない。
//
// なぜ対照(case B)が要るか:
//   「NOREPLACE を付けたら失敗した」だけでは、フラグが効いたのか、その path が
//   そもそも上書きrenameを拒むのかを区別できない。flags=0 で同じ操作を試し、
//   そちらが**成功して上書きする**ことを見て初めて「フラグが効いた」と言える。
//
// 使い方:
//   ./renameat2_spike <作業ディレクトリ>
//
// 観測するもの:
//   case A: RENAME_NOREPLACE + target あり → EEXIST で失敗し、source も
//           target も無傷か(005 INV-002 と OP-004)
//   case B: flags=0 + target あり → 成功して上書きするか(対照。これが無いと
//           「フラグが効いた」と「その path が上書きを拒む」を区別できない)
//   case C: RENAME_NOREPLACE + target なし → 成功し、中身が移るか
//
//   例: ./renameat2_spike /sdcard         (FUSE経由。本番)
//       ./renameat2_spike /data/local/tmp (FUSEを経由しない path。切り分け用)
//   filesystem 種別は思い込まず `stat -f <dir>` で別途記録する。
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
// 生のsyscallを使うので、bionicのwrapperが公開されたAPI levelには縛られない。
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

static char src[512], dst[512], missing[512];

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

// 1=ある / 0=無い / -1=判定できない。
//
// stat の失敗を一律「無い」とみなすと、権限などで見えないだけのfileを
// 上書きしうる。TOCTOUを調べるspikeで自分がTOCTOUを踏まないよう、
// ENOENT 以外は「判定できない」として中止する。
static int exists(const char *path) {
  struct stat st;
  if (stat(path, &st) == 0) return 1;
  return errno == ENOENT ? 0 : -1;
}

static void cleanup(void) {
  unlink(src);
  unlink(dst);
  unlink(missing);
}

// src="SOURCE" / dst="TARGET" を作り直す。失敗したら 0。
static int reset_fixture(int with_target) {
  cleanup();
  if (write_file(src, "SOURCE") != 0) return 0;
  if (with_target && write_file(dst, "TARGET") != 0) return 0;
  return 1;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s <directory>\n", argv[0]);
    return 2;
  }
  const char *dir = argv[1];

  snprintf(src, sizeof(src), "%s/spike-c.txt", dir);
  snprintf(dst, sizeof(dst), "%s/spike-d.txt", dir);
  snprintf(missing, sizeof(missing), "%s/spike-e.txt", dir);

  const char *paths[3] = {src, dst, missing};
  for (int i = 0; i < 3; i++) {
    int e = exists(paths[i]);
    if (e == 1) {
      fprintf(stderr,
              "ERROR: %s が既にあります。\n"
              "利用者のfileを壊さないため中止します。先に消してください。\n",
              paths[i]);
      return 2;
    }
    if (e == -1) {
      fprintf(stderr,
              "ERROR: %s の有無を判定できません (%s)。\n"
              "上書きするおそれがあるため中止します。\n",
              paths[i], strerror(errno));
      return 2;
    }
  }

  printf("=== renameat2 spike (013:T01 S-2) ===\n");
  printf("directory: %s\n\n", dir);

  char body[64];

  // --- case A: RENAME_NOREPLACE、target あり(本命) ---
  if (!reset_fixture(1)) {
    fprintf(stderr, "ERROR: fixtureを作れません: %s\n", strerror(errno));
    cleanup();
    return 2;
  }
  errno = 0;
  int rA = renameat2_raw(src, dst, RENAME_NOREPLACE);
  int eA = errno;
  body[0] = '\0';
  int readA = read_file(dst, body, sizeof(body));
  int intactA = readA && strcmp(body, "TARGET") == 0;
  // 失敗時不変(005 OP-004)は target だけでなく source 側でも見る。
  char srcBody[64] = {0};
  int readSrcA = read_file(src, srcBody, sizeof(srcBody));
  int srcIntactA = readSrcA && strcmp(srcBody, "SOURCE") == 0;

  printf("[case A] RENAME_NOREPLACE / target あり\n");
  printf("  戻り値 : %d\n", rA);
  printf("  errno  : %d (%s)\n", eA, rA == 0 ? "-" : strerror(eA));
  printf("  spike-d.txt : %s\n", readA ? body : "(読めない)");
  printf("  target は無傷か : %s\n", intactA ? "YES" : "NO");
  printf("  spike-c.txt : %s\n", readSrcA ? srcBody : "(読めない)");
  printf("  source は無傷か : %s\n\n", srcIntactA ? "YES" : "NO");

  // --- case B: flags=0、target あり(対照。ここが要) ---
  if (!reset_fixture(1)) {
    fprintf(stderr, "ERROR: fixtureを作り直せません: %s\n", strerror(errno));
    cleanup();
    return 2;
  }
  errno = 0;
  int rB = renameat2_raw(src, dst, 0);
  int eB = errno;
  body[0] = '\0';
  int readB = read_file(dst, body, sizeof(body));
  int replacedB = readB && strcmp(body, "SOURCE") == 0;

  printf("[case B] flags=0 / target あり(対照)\n");
  printf("  戻り値 : %d\n", rB);
  printf("  errno  : %d (%s)\n", eB, rB == 0 ? "-" : strerror(eB));
  printf("  spike-d.txt : %s\n", readB ? body : "(読めない)");
  printf("  上書きされたか : %s\n\n", replacedB ? "YES" : "NO");

  // --- case C: RENAME_NOREPLACE、target なし(通常成功の確認) ---
  if (!reset_fixture(0)) {
    fprintf(stderr, "ERROR: fixtureを作り直せません: %s\n", strerror(errno));
    cleanup();
    return 2;
  }
  errno = 0;
  int rC = renameat2_raw(src, missing, RENAME_NOREPLACE);
  int eC = errno;

  body[0] = '\0';
  int readC = read_file(missing, body, sizeof(body));
  int movedC = readC && strcmp(body, "SOURCE") == 0;

  printf("[case C] RENAME_NOREPLACE / target なし\n");
  printf("  戻り値 : %d\n", rC);
  printf("  errno  : %d (%s)\n", eC, rC == 0 ? "-" : strerror(eC));
  printf("  spike-e.txt : %s\n", readC ? body : "(読めない)");
  printf("  中身が移ったか : %s\n\n", movedC ? "YES" : "NO");

  // --- 判定 ---
  printf("=== 判定 ===\n");
  if (rA == -1 && eA == EEXIST && intactA && srcIntactA && rB == 0 && replacedB) {
    printf("A) RENAME_NOREPLACE が効いている。\n");
    printf("   フラグ有りは EEXIST で失敗し source も target も無傷、フラグ\n");
    printf("   無しは成功して上書きした。差はフラグに由来する。\n");
    printf("   候補Eは成立しうる。\n");
  } else if (rA == -1 && (eA == EINVAL || eA == ENOSYS)) {
    printf("B) フラグを解釈できない (errno=%s)。候補Eは不成立。\n", strerror(eA));
  } else if (rA == 0) {
    printf("C) フラグが無視され、既存fileを置換した。候補Eは不成立、かつ危険。\n");
  } else if (rA == -1 && eA == EEXIST && rB != 0) {
    printf("D) フラグの有無に関わらず上書きrenameが失敗している。\n");
    printf("   安全ではあるが、**フラグが効いた証拠にはならない。**\n");
    printf("   case B の 戻り値=%d errno=%d (%s) を報告する。\n", rB, eB,
           eB == 0 ? "errnoは設定されていない" : strerror(eB));
  } else {
    printf("E) 想定外。上の生の値をそのまま報告する。\n");
  }
  if (rA == -1 && eA == EEXIST && intactA && !srcIntactA) {
    printf("   注意: 失敗したのに source が変化している。失敗時不変(OP-004)を\n");
    printf("   満たさない。この点だけで候補Eは採れない。\n");
  }
  if (rC == 0 && !movedC) {
    printf("   注意: case C は成功を返したが中身が移っていない。\n");
  }
  if (rC != 0) {
    printf("   注意: target が無い場合の rename も失敗した (errno=%d %s)。\n",
           eC, strerror(eC));
    printf("   書き込めていないのか、フラグを拒んでいるのか、case B と\n");
    printf("   合わせて判断する。\n");
  }

  cleanup();
  printf("\nfixtureを削除しました。\n");
  return 0;
}
