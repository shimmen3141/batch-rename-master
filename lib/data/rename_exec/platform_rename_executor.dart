import 'dart:io';

import 'desktop_rename_executor.dart';
import 'native_exclusive_rename.dart';
import 'rename_executor.dart';
import 'saf_rename_executor.dart';

/// 現在の OS に対応する実リネーム adapter を選ぶ composition root。
///
/// **Android はまだ [SafRenameExecutor](安全な未対応)のままである。**
/// `013:T05` が `renameat2` の port を用意したが、**ここを切り替えるのは
/// `013:T07` である。** 理由: 切り替えは「元場所ハンドルが絶対 path であること」を
/// 前提にするが、Android のハンドルはまだ SAF の document URI であり
/// (004 REQ-002 の注記は `T07` の実装で満たされる)、いま切り替えると path として
/// 解釈できない値を渡すことになる。**実体は壊れない**(対象が見つからず失敗する)が、
/// revision 2 以来の「理由付きの安全な未対応」より分かりにくい失敗になる。
/// `T07` が app 内 file browser で絶対 path を供給した時点で切り替える。
///
/// **切り替えは `Platform.isAndroid` の行を消すだけである**(ADR-003)。Android 専用の
/// executor は無く、[DesktopRenameExecutor] が native から
/// [NativeRenameResult.fallbackRequired] を受け取って劣化する。
RenameExecutor createPlatformRenameExecutor() {
  if (Platform.isAndroid) return const SafRenameExecutor();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return DesktopRenameExecutor();
  }
  return const UnsupportedRenameExecutor();
}
