import 'package:path/path.dart' as p;

import '../../core/rename_engine.dart';

/// 一覧の folder 行(`008:T56`)から、読み込み帯の結線で同じ folder を開き直す
/// (004 REQ-021)。
///
/// **開き直しも読み込みである。** 権限の確認と説明(013 REQ-001〜004)、失敗の通知
/// (004 REQ-008)は読み込み帯([FileSourceBar])が持っている。folder 行は一覧の側に
/// あるので、帯が自分の処理をここへ登録し、行はここを呼ぶ。二重に持たない。
class SameFolderReopen {
  Future<void> Function()? _handler;

  void attach(Future<void> Function() handler) => _handler = handler;

  /// [handler] が登録中のものなら外す(後から登録した帯を外さない)。
  void detach(Future<void> Function() handler) {
    if (_handler == handler) _handler = null;
  }

  /// 登録された処理を呼ぶ。帯が無ければ何もしない。
  Future<void> call() async => _handler?.call();
}

/// 一覧の所属 folder が**1つ**ならそれを返す(004 REQ-021 の入口を出す条件)。
///
/// 一覧が空、所属 folder を持たない item がある、2つ以上に分かれていれば `null`。
String? soleFolderOf(Iterable<FileEntry> items) {
  String? folder;
  for (final item in items) {
    final own = item.sourceFolder;
    if (own == null) return null;
    if (folder != null && folder != own) return null;
    folder = own;
  }
  return folder;
}

/// folder 行に出す名前。表示用の場所(004 REQ-009)が揃っていればそれ、
/// 無ければ所属 folder の basename。
String folderLabelOf(Iterable<FileEntry> items, String folder) {
  final locations = items.map((item) => item.sourceLocation).toSet();
  final single = locations.length == 1 ? locations.single : null;
  return single ?? p.basename(folder);
}
