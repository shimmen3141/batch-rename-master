#if !defined(_WIN32)
#define _GNU_SOURCE
#endif
#include <stdint.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <errno.h>
#include <stdio.h>
#if defined(__APPLE__)
#include <sys/attr.h>
#else
#include <fcntl.h>
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

#if defined(_WIN32)
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
