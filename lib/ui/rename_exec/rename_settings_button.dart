import 'package:flutter/material.dart';

import 'rename_execution_controller.dart';

/// ヘッダーの歯車(`008:T43`)。key は test が押すためのもの。
const Key renameSettingsButtonKey = Key('rename-settings-button');

/// 歯車のメニューの「更新日時を一覧の並び順にずらす」(005 REQ-014)。
const Key shiftModifiedAtKey = Key('shift-modified-at');

/// 更新日時ずらしの項目の文言。
const String shiftModifiedAtLabel = '更新日時を一覧の並び順にずらす';

/// リネームの設定を開く歯車(`008:T43`。2026-09-29 の開発者の決定)。
///
/// ヘッダーの右端に置き、押すと**メニュー**を出す。今の項目は更新日時ずらし
/// (005 REQ-014)だけで、**有効な設定が1つも無い端末では歯車そのものを出さない**
/// (REQ-015。Android では出ない)。以前はフッターのチェックボックスだった。
/// ON のときの印は出さない(開発者の決定)。
class RenameSettingsButton extends StatelessWidget {
  const RenameSettingsButton({super.key, required this.execution});

  final RenameExecutionController execution;

  @override
  Widget build(BuildContext context) {
    if (!execution.canShiftModifiedAt) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: execution,
      builder: (context, _) => PopupMenuButton<_Setting>(
        key: renameSettingsButtonKey,
        icon: const Icon(Icons.settings_outlined),
        tooltip: '設定',
        onSelected: (setting) => switch (setting) {
          _Setting.shiftModifiedAt => execution.setShiftModifiedAt(
            !execution.shiftModifiedAt,
          ),
        },
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            key: shiftModifiedAtKey,
            value: _Setting.shiftModifiedAt,
            checked: execution.shiftModifiedAt,
            child: const Text(shiftModifiedAtLabel),
          ),
        ],
      ),
    );
  }
}

enum _Setting { shiftModifiedAt }
