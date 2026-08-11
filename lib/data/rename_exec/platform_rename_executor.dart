import 'dart:io';

import 'desktop_rename_executor.dart';
import 'rename_executor.dart';
import 'saf_rename_executor.dart';

/// 現在の OS に対応する実リネーム adapter を選ぶ composition root。
RenameExecutor createPlatformRenameExecutor() {
  if (Platform.isAndroid) return const SafRenameExecutor();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return DesktopRenameExecutor();
  }
  return const UnsupportedRenameExecutor();
}
