#if !defined(_WIN32) && !defined(BRM_UNSUPPORTED_PLATFORM)
#define _GNU_SOURCE
#endif
#include <stdint.h>
#if defined(BRM_UNSUPPORTED_PLATFORM)
#elif defined(_WIN32)
#include <windows.h>
#else
#include <errno.h>
#include <stdio.h>
#if defined(__APPLE__)
#include <sys/attr.h>
#else
#include <fcntl.h>
#endif
#if defined(__ANDROID__)
/* bionic の renameat2 wrapper が公開されたのは API 30 とされるが、生の syscall を
 * 使えば wrapper の有無に依存しない(013:T01 の spike は android24 向けにビルドして
 * 動作した)。制約は libc ではなく kernel と filesystem の側にある。
 * 013 spec の D-1「minSdk は 24 のまま、対応可否を実行時に判定する」に従う。 */
#include <sys/syscall.h>
#include <unistd.h>
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif
/* SYS_renameat2 が header に無い環境でも呼べるよう arch 別の番号を持つ。
 * 出典: 013:T01 の spike(検証済みの参照実装)。 */
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
#endif
#endif

#if defined(_WIN32)
#define BRM_EXPORT __declspec(dllexport)
#else
#define BRM_EXPORT __attribute__((visibility("default")))
#endif

enum brm_rename_result {
  BRM_RENAME_SUCCESS = 0,
  BRM_RENAME_NAME_CONFLICT = 1,
  BRM_RENAME_NOT_FOUND = 2,
  BRM_RENAME_PERMISSION_DENIED = 3,
  BRM_RENAME_UNSUPPORTED = 4,
  BRM_RENAME_IO = 5
};

#if defined(BRM_UNSUPPORTED_PLATFORM)
BRM_EXPORT int32_t brm_rename_no_replace_utf8(const char *source,
                                               const char *destination) {
  (void)source;
  (void)destination;
  return BRM_RENAME_UNSUPPORTED;
}
#elif defined(_WIN32)
static int32_t brm_result_from_windows_error(DWORD error) {
  switch (error) {
    case ERROR_FILE_EXISTS:
    case ERROR_ALREADY_EXISTS:
      return BRM_RENAME_NAME_CONFLICT;
    case ERROR_FILE_NOT_FOUND:
    case ERROR_PATH_NOT_FOUND:
      return BRM_RENAME_NOT_FOUND;
    case ERROR_ACCESS_DENIED:
    case ERROR_PRIVILEGE_NOT_HELD:
    case ERROR_WRITE_PROTECT:
      return BRM_RENAME_PERMISSION_DENIED;
    case ERROR_CALL_NOT_IMPLEMENTED:
    case ERROR_NOT_SUPPORTED:
      return BRM_RENAME_UNSUPPORTED;
    default:
      return BRM_RENAME_IO;
  }
}

BRM_EXPORT int32_t brm_rename_no_replace_utf16(const uint16_t *source,
                                                const uint16_t *destination) {
  if (MoveFileW((LPCWSTR)source, (LPCWSTR)destination) != 0) {
    return BRM_RENAME_SUCCESS;
  }
  const DWORD error = GetLastError();
  return brm_result_from_windows_error(error);
}
#else
static int32_t brm_result_from_errno(int error) {
  switch (error) {
    case EEXIST:
#if ENOTEMPTY != EEXIST
    case ENOTEMPTY:
#endif
      return BRM_RENAME_NAME_CONFLICT;
    case ENOENT:
    case ENOTDIR:
      return BRM_RENAME_NOT_FOUND;
    case EACCES:
    case EPERM:
    case EROFS:
      return BRM_RENAME_PERMISSION_DENIED;
    case ENOSYS:
#ifdef ENOTSUP
    case ENOTSUP:
#endif
#if defined(__ANDROID__)
    /* renameat2 は、filesystem が flag を解釈できないとき EINVAL を返す。
     * Android では共有 storage が MediaProvider の FUSE を経由するため、この経路が
     * 現実的に起きる。013 REQ-005 は「フラグが使えない端末でも対応外にしない」と
     * 定めており、呼び出し側は UNSUPPORTED を見て実在確認による代替経路へ落とす。
     * **desktop では従来どおり IO のままにする**(013 は desktop の振る舞いを変えない)。 */
    case EINVAL:
#endif
      return BRM_RENAME_UNSUPPORTED;
    default:
      return BRM_RENAME_IO;
  }
}

BRM_EXPORT int32_t brm_rename_no_replace_utf8(const char *source,
                                               const char *destination) {
  int result;
#if defined(__APPLE__)
  result = renamex_np(source, destination, RENAME_EXCL);
#elif defined(__ANDROID__)
  /* wrapper ではなく生の syscall を呼ぶ。API level に依存しない(上の注記)。 */
  result = (int)syscall(SYS_renameat2, AT_FDCWD, source, AT_FDCWD, destination,
                        RENAME_NOREPLACE);
#else
  result = renameat2(AT_FDCWD, source, AT_FDCWD, destination,
                     RENAME_NOREPLACE);
#endif
  if (result == 0) {
    return BRM_RENAME_SUCCESS;
  }
  const int error = errno;
  return brm_result_from_errno(error);
}
#endif
