import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 選択の印(丸いチェックボックス)。
///
/// **選択するUIはすべてこれを使う** — 一覧の除去のための選択モード(002 REQ-018)、
/// 読み込み画面のファイル選択(004)、並び順のメニュー(002 REQ-020。`008:T02`)。
/// 選ばれていると円を [AppColors.selectionMark] で塗り、チェックを
/// [AppColors.onPrimary] で描く(2026-09-19 の要望2 で円にした。2026-09-30 の
/// 開発者の指定で並び順のメニューも同じにした)。
///
/// [onChanged] が `null` なら押せない(無効の見た目になる)。メニュー項目のように
/// **項目全体で選ぶ**ときは、印を [IgnorePointer] で包んで押下を項目へ通す。
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Checkbox(
      value: value,
      onChanged: onChanged,
      shape: const CircleBorder(),
      side: BorderSide(color: colors.textMuted, width: 1.5),
      activeColor: colors.selectionMark,
      checkColor: colors.onPrimary,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
