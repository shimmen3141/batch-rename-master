import 'dart:io';

import 'desktop_rename_executor.dart';
import 'rename_executor.dart';
import 'saf_rename_executor.dart';

/// どの platform がどの改名 adapter を使うかの写像。
///
/// **Android も desktop と同じ [DesktopRenameExecutor] を通る**(005 contract
/// revision 6、2026-08-24 承認。更新日時ずらしを見せないよう [RenameOnlyExecutor]
/// で包む)。`013:T07` が app 内 file browser を入れて
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
  // **Android では更新日時ずらしを出さない**(005 REQ-015、`013:T04`の決定4)。
  // 同じ実装は更新日時も書ける([ModifiedAtWriter])が、それを見せない形で渡す。
  // 以前は Android にもそのまま渡していたため、設定が Android の画面にも出ていた
  // (`008:T43`で見つけた)。
  if (isAndroid) return RenameOnlyExecutor(DesktopRenameExecutor());
  if (isDesktop) return DesktopRenameExecutor();
  return const UnsupportedRenameExecutor();
}

/// 改名だけを見せる包み(`008:T43`)。中身が [ModifiedAtWriter] でも、**包んだ側は
/// そうではない**ので、`executor is ModifiedAtWriter`(= この端末で更新日時ずらしを
/// 出すか)が偽になる。改名の振る舞いは中身と同じ。
class RenameOnlyExecutor implements RenameExecutor {
  const RenameOnlyExecutor(this.inner);

  /// 実際に改名する実装。
  final RenameExecutor inner;

  @override
  Future<RenameResult> rename(String handle, String newName) =>
      inner.rename(handle, newName);
}

/// 現在の OS に対応する実リネーム adapter を選ぶ composition root。
RenameExecutor createPlatformRenameExecutor() => renameExecutorFor(
  isAndroid: Platform.isAndroid,
  isDesktop: Platform.isWindows || Platform.isLinux || Platform.isMacOS,
);
