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
/* ABI 定数は includes を持たない header が正本である(そこの注記を読むこと)。
 * ここでは system 定義があるときに一致を compile 時に確かめる。 */
#include "brm_renameat2_abi.h"
#ifdef RENAME_NOREPLACE
_Static_assert(BRM_RENAME_NOREPLACE == RENAME_NOREPLACE,
               "BRM_RENAME_NOREPLACE does not match the kernel header");
#endif
#ifdef __NR_renameat2
_Static_assert(BRM_SYS_RENAMEAT2 == __NR_renameat2,
               "BRM_SYS_RENAMEAT2 does not match __NR_renameat2 for this arch");
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
  BRM_RENAME_IO = 5,
  /* このplatformでは排他的renameを利用できなかった。呼び出し側は実在確認を済ませた
   * うえで通常renameへ落としてよい(013 REQ-005)。**UNSUPPORTEDとは意味が違う** —
   * UNSUPPORTEDは「この機能自体を提供しない」で、落としてよいとは言っていない。
   * 現状これを返すのはAndroidだけである。desktopは従来どおりUNSUPPORTEDを返す。 */
  BRM_RENAME_FALLBACK_REQUIRED = 6
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
/* 「排他 rename が使えない」を表す errno。ここから先の分岐だけが platform 依存である。
 *
 * Android: 通常 rename へ落としてよい(013 REQ-005)。renameat2 は filesystem が flag を
 *   解釈できないとき EINVAL を返し、Android では共有 storage が MediaProvider の FUSE を
 *   経由するのでこの経路が現実に起きる。**この判断は OS を知っている唯一の層である
 *   ここで行い、Dart へは OS ではなく「落としてよい」という結果だけを渡す**(ADR-003)。
 * desktop: 従来どおり UNSUPPORTED。落としてよいとは言わない(005 INV-002 を保つ)。
 *   EINVAL は desktop では IO のままである(013 は desktop の振る舞いを変えない)。 */
#if defined(__ANDROID__)
    case EINVAL:
    case ENOSYS:
#ifdef ENOTSUP
    case ENOTSUP:
#endif
      return BRM_RENAME_FALLBACK_REQUIRED;
#else
    case ENOSYS:
#ifdef ENOTSUP
    case ENOTSUP:
#endif
      return BRM_RENAME_UNSUPPORTED;
#endif
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
  result = (int)syscall(BRM_SYS_RENAMEAT2, AT_FDCWD, source, AT_FDCWD, destination,
                        BRM_RENAME_NOREPLACE);
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
