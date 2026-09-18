import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import 'file_list_controller.dart';

/// 取り消しの通知(002 REQ-017)。
const Key removalUndoKey = Key('removal-undo');

/// 控えが古くなっていて取り消せなかったときの通知(002 REQ-017)。
const Key removalUndoStaleKey = Key('removal-undo-stale');

/// 一覧からの除去を、**取り消せる形で**行う(002 REQ-017)。
///
/// 行の checkbox を廃止して「一覧にあるファイル＝ rename 対象」にした
/// (002 REQ-016)ため、**外す操作は除去だけ**になった。戻す手段が無いと、
/// 誤って外したファイルを入れ直すのに**フォルダごと選び直す**ことになる
/// (004 は置き換え方式なので、004 REQ-004)。
///
/// **元の位置へ戻す。** [FileListController.items] を丸ごと控えてから [remove] を
/// 実行し、取り消しでは控えを `setFiles` で戻す — 末尾へ付け足すのではない(代表例 6c)。
/// 占有名も一緒に控える: `setFiles` は**置き換え後の folder と無関係になる占有名を捨てる**
/// ので、控えを戻さないと取り消しただけで一覧の警告が弱くなる(005 REQ-026)。
///
/// **状態層に新しい操作を足していない** — `setFiles` / `setOccupiedNames` は
/// 002 が既に持つ操作である。
void removeUndoably(
  BuildContext context,
  FileListController controller,
  VoidCallback remove,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final before = controller.items;
  final occupied = controller.occupiedNames;

  remove();

  // **除去した直後の一覧**。取り消しを押した時点でここから動いていたら、
  // 控えはもう現在の一覧の「1手前」ではない(下の [_sameItems])。
  final after = controller.items;
  // **並び順の種別も見る。** 並べ替えても順序が変わらないことがあり
  // (すでにその順だった場合)、項目だけを見ていると「動いていない」と読める。
  // そこで戻すと、`sortMode` と表示順が食い違った一覧ができる。
  final afterSortMode = controller.sortMode;
  final removed = before.length - controller.items.length;
  // **何も外れていないなら通知しない。** `removeFile` は一致が無ければ無変化で
  // (002 REQ-009)、そのとき「外しました」と出すのは嘘になる。
  if (messenger == null || removed <= 0) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: removalUndoKey,
        content: Text('$removed 件を一覧から外しました'),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            // **控えが古ければ戻さない。** 通知が出ている間に読み込み直しや
            // 並び替えが起きると、控えは**除去の1手前**ではなく**別の一覧**に
            // なっている。そのまま `setFiles` すると、読み込んだばかりの一覧を
            // 古い控えで**無断で置き換える**(独立review attempt 1 の N-1)。
            //
            // 002 REQ-017 は「次の操作の後は取り消せなくてよい」としているが、
            // **誤って戻すことまでは許していない。**
            if (controller.sortMode != afterSortMode ||
                !_sameItems(controller.items, after)) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    key: removalUndoStaleKey,
                    content: Text('一覧が変わったため、取り消せませんでした'),
                  ),
                );
              return;
            }
            controller.setFiles(before);
            controller.setOccupiedNames(occupied);
          },
        ),
      ),
    );
}

/// 2つの一覧が**同じ項目を同じ順で**持つか。
///
/// **同一性で比べる**(`==` ではない)。005 の改名は項目を新しいハンドルを持つ値へ
/// 差し替えるので(005 REQ-018)、内容が等しく見えても**別の項目**である。
/// 並び替えも順序で検出できる。
bool _sameItems(List<FileEntry> a, List<FileEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}
