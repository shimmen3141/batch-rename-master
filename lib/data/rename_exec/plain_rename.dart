import 'dart:io';

import 'native_exclusive_rename.dart';

/// 排他 rename が使えない環境で用いる**通常 rename**。
///
/// POSIX の `rename(2)` は既存 target を**黙って置換する**。したがってこれ単体は
/// 005 INV-002(既存 file を置換しない)を満たさない。**単体で使わないこと** —
/// 目標名が実在しないことを確認済みの呼び出し側だけが使ってよい。
typedef PlainRenameOperation =
    Future<NativeRenameResult> Function(String source, String destination);

/// `dart:io` の通常 rename。**既存 target を置換しうる。**
///
/// 例外は投げず [NativeRenameResult] へ写す(005 REQ-017 と同じ約束を、この層でも
/// 守る)。分類は C 側の `errno` 写像と同じ意味にそろえる。
///
/// **完全に同じではない。** `dart:io` の `File.rename` は regular file 以外を拒み、
/// directory を渡すと `EISDIR` を投げるので [NativeRenameResult.io] になる。
/// `renameat2` は directory も改名する。005 の対象は「1 file の改名」なので製品影響は
/// 無いが、**劣化したときだけ directory の扱いが変わる**。
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
