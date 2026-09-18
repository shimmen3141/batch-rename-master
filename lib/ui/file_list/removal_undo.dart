import 'package:flutter/material.dart';

import 'file_list_controller.dart';

/// 取り消しの通知(002 REQ-017)。
const Key removalUndoKey = Key('removal-undo');

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
            controller.setFiles(before);
            controller.setOccupiedNames(occupied);
          },
        ),
      ),
    );
}
