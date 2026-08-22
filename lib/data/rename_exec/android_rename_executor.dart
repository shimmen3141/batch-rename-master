import 'dart:io';

import 'desktop_rename_executor.dart';
import 'native_exclusive_rename.dart';
import 'rename_executor.dart';

/// 排他 rename が使えない環境で用いる**通常 rename**。
///
/// POSIX の `rename(2)` は既存 target を**黙って置換する**。したがってこれ単体は
/// 005 INV-002(既存 file を置換しない)を満たさない。
typedef PlainRenameOperation =
    Future<NativeRenameResult> Function(String source, String destination);

/// Android 用の改名操作(013 REQ-005 / REQ-006)。
///
/// `renameat2(RENAME_NOREPLACE)` を生の syscall で呼び、**flag が効かない環境では
/// 通常 rename へ落とす**。「この端末では改名できません」を利用者へ見せない
/// (013 REQ-005)。005 contract revision 4 で衝突は失敗ではなく採番で回避する
/// ものになったため、no-replace は破壊を防ぐ最後の砦ではなく、**すり抜けた衝突を
/// 捕まえて再採番へ戻す入口**である。効かなければ実在確認の水準へ**劣化するだけ**で、
/// 利用者から見た機能は同じ。変わるのは 005 INV-002 の成立範囲だけである。
///
/// **前提: 呼び出し側が直前に「目標名が実在しない」ことを確認していること。**
/// [DesktopRenameExecutor] は 005 REQ-025 により**すべての** rename の直前で実在
/// 確認を行うので、この前提はそこで満たされる。**単体で使わないこと** — 確認なしに
/// 使うと、劣化経路が既存 file を黙って置換する。
///
/// `EINVAL` / `ENOSYS` を [NativeRenameResult.unsupported] へ写すのは C 側である
/// (`src/native_exclusive_rename.c`。**Android のときだけ** `EINVAL` を含める)。
/// `EEXIST` は [NativeRenameResult.nameConflict] になり、呼び出し側が 005 contract
/// REQ-023 に従って再採番する(013 REQ-006。**Android 固有の失敗として見せない**)。
DesktopRenameOperation androidRenameOperation({
  DesktopRenameOperation exclusiveRename = _exclusiveRename,
  PlainRenameOperation plainRename = plainRenameFile,
}) {
  return (String source, String destination) async {
    final result = await exclusiveRename(source, destination);
    if (result != NativeRenameResult.unsupported) return result;
    // flag が効かない環境。**直前の実在確認だけを頼りに**通常 rename で進める。
    // ここが 005 INV-002 の TOCTOU の窓である(005 contract revision 4 が受容した)。
    return plainRename(source, destination);
  };
}

Future<NativeRenameResult> _exclusiveRename(
  String source,
  String destination,
) async => renameFileWithoutOverwrite(source, destination);

/// `dart:io` の通常 rename。**既存 target を置換しうる。**
///
/// 例外は投げず [NativeRenameResult] へ写す(005 REQ-017 と同じ約束を、この層でも
/// 守る)。分類は C 側の `errno` 写像と同じ意味にそろえる。
Future<NativeRenameResult> plainRenameFile(
  String source,
  String destination,
) async {
  try {
    await File(source).rename(destination);
    return NativeRenameResult.success;
  } on PathNotFoundException {
    return NativeRenameResult.notFound;
  } on PathAccessException {
    return NativeRenameResult.permissionDenied;
  } on FileSystemException {
    return NativeRenameResult.io;
  } catch (_) {
    // ここで捕らえるのは FileSystemException だけではない。この層は「例外を
    // 投げない」と約束しており、想定外の例外を通すと REQ-017 が破れる。
    return NativeRenameResult.io;
  }
}

/// Android の実 file 用リネーム adapter を組み立てる(013 REQ-005 / REQ-006)。
///
/// **経路は desktop と同じ** [DesktopRenameExecutor] を使う。005 contract の
/// REQ-025(常に実在確認してから改名する)、一時名を経由した自己衝突の観測、失敗時の
/// 巻き戻しは platform に依らない振る舞いで、**013 はそこを変えない**。Android
/// 固有なのは「排他 rename が使えないときの落とし方」だけなので、そこだけを
/// [androidRenameOperation] で差し替える。
///
/// **desktop の振る舞いは1文字も変わらない**(013 `spec.md` の範囲外)。
RenameExecutor createAndroidRenameExecutor({
  DesktopRenameOperation? rename,
  DesktopPathProbe? probe,
}) => DesktopRenameExecutor(
  rename: rename ?? androidRenameOperation(),
  probe: probe,
);
