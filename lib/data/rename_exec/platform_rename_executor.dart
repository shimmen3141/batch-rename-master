import 'dart:io';

import 'desktop_rename_executor.dart';
import 'rename_executor.dart';
import 'saf_rename_executor.dart';

/// どの platform がどの改名 adapter を使うかの写像。
///
/// **Android も desktop と同じ [DesktopRenameExecutor] を通る**(005 contract
/// revision 6、2026-08-24 承認)。`013:T07` が app 内 file browser を入れて
/// 元場所ハンドルが絶対 path になったので、revision 2 以来の「安全な未対応」を
/// 外した。**Android 専用の executor は存在しない** — 劣化は native が返す
/// `fallbackRequired` が駆動する(ADR-003)。
///
/// [SafRenameExecutor] は **wiring から外れるが削除しない**(ADR-002 の退避経路。
/// Play の宣言が却下されたら Android 未対応へ戻す)。negative test も維持する。
///
/// **純関数として切り出してある。** `Platform.isAndroid` を条件式へ直接書くと、
/// この写像を Linux 上の test で固定できない(ADR-003)。
RenameExecutor renameExecutorFor({
  required bool isAndroid,
  required bool isDesktop,
}) {
  if (isAndroid || isDesktop) return DesktopRenameExecutor();
  return const UnsupportedRenameExecutor();
}

/// 現在の OS に対応する実リネーム adapter を選ぶ composition root。
RenameExecutor createPlatformRenameExecutor() => renameExecutorFor(
  isAndroid: Platform.isAndroid,
  isDesktop: Platform.isWindows || Platform.isLinux || Platform.isMacOS,
);
