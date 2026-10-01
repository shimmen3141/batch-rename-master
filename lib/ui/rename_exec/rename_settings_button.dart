import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'rename_execution_controller.dart';

/// 歯車(`008:T43`)。key は test が押すためのもの。
const Key renameSettingsButtonKey = Key('rename-settings-button');

/// 歯車のメニューの「更新日時を一覧の並び順にずらす」(005 REQ-014)。
const Key shiftModifiedAtKey = Key('shift-modified-at');

/// 更新日時ずらしの項目の文言。
const String shiftModifiedAtLabel = '更新日時を一覧の並び順にずらす';

/// リネームの設定を開く歯車(`008:T43`。2026-09-29 の開発者の決定)。
///
/// folder の帯の右端に置き(`008:T10` で見出しの帯を削除したので、そこから移した)、
/// 押すと**メニュー**を出す。今の項目は更新日時ずらし
/// (005 REQ-014)だけで、**有効な設定が1つも無い端末では歯車そのものを出さない**
/// (REQ-015。Android では出ない)。以前はフッターのチェックボックスだった。
/// ON のときの印は出さない(開発者の決定)。
///
/// 項目は**トグルスイッチ**(ON は緑、OFF はグレー)で、切り替えても**メニューを
/// 閉じない**(manual 1回目の開発者の要望。チェックの無いチェック項目では何をする
/// 項目か分からなかった)。
class RenameSettingsButton extends StatelessWidget {
  const RenameSettingsButton({super.key, required this.execution});

  final RenameExecutionController execution;

  @override
  Widget build(BuildContext context) {
    if (!execution.canShiftModifiedAt) return const SizedBox.shrink();
    return PopupMenuButton<Never>(
      key: renameSettingsButtonKey,
      icon: const Icon(Icons.settings_outlined),
      tooltip: '設定',
      itemBuilder: (context) => [_ShiftModifiedAtItem(execution: execution)],
    );
  }
}

/// メニューの中のトグル。[PopupMenuItem] は押すとメニューを閉じるので使わず、
/// 選べない項目([represents] が常に偽)としてスイッチだけを置く。
class _ShiftModifiedAtItem extends PopupMenuEntry<Never> {
  const _ShiftModifiedAtItem({required this.execution});

  final RenameExecutionController execution;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(Never? value) => false;

  @override
  State<_ShiftModifiedAtItem> createState() => _ShiftModifiedAtItemState();
}

class _ShiftModifiedAtItemState extends State<_ShiftModifiedAtItem> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: widget.execution,
      builder: (context, _) => SwitchListTile(
        key: shiftModifiedAtKey,
        value: widget.execution.shiftModifiedAt,
        onChanged: widget.execution.setShiftModifiedAt,
        title: const Text(shiftModifiedAtLabel),
        activeThumbColor: Colors.white,
        activeTrackColor: colors.success,
        inactiveThumbColor: colors.textSecondary,
        inactiveTrackColor: colors.textMuted,
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
