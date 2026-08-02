import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'file_list_controller.dart';
import 'file_sort.dart';
import 'row_view.dart';

/// メイン画面のファイルリスト(002 spec の描画層)。
///
/// [FileListController] を購読して描画するだけの薄いウィジェット。ロジックは
/// 持たず、操作は controller のメソッドへ委譲する。左に現在名・右に変更後名の
/// 2カラム、各行にチェックボックス、上部にソート切替チップを置く(PRD §3.1)。
/// 視覚は参考デザインに準拠し、色は [AppColors] のセマンティック名で参照する。
class FileListView extends StatelessWidget {
  const FileListView({super.key, required this.controller});

  final FileListController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // rows ゲッターは呼ぶたびプレビューを再計算するため、ビルド1回につき
        // 一度だけ評価して使い回す(行ごとの再計算を避ける)。
        final rows = controller.rows;
        return Container(
          color: colors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBar(controller: controller),
              _SortBar(controller: controller),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _FileRow(
                      row: row,
                      onToggle: () => controller.toggleSelection(row.source),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 全選択トグルと選択件数を表示するヘッダ。
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.controller});

  final FileListController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = controller.items.length;
    final selected = controller.selectedCount;
    final allSelected = total > 0 && selected == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _SelectAllButton(
            key: const Key('select-all-toggle'),
            allSelected: allSelected,
            enabled: total > 0,
            onPressed: allSelected ? controller.clearAll : controller.selectAll,
          ),
          const SizedBox(width: 12),
          Text(
            '$selected / $total 件を選択',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 全選択/全解除を切り替える四角いチェックボタン(デザインの ✓ ボックス)。
class _SelectAllButton extends StatelessWidget {
  const _SelectAllButton({
    super.key,
    required this.allSelected,
    required this.enabled,
    required this.onPressed,
  });

  final bool allSelected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: allSelected ? '全解除' : '全選択',
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: allSelected ? colors.primary : Colors.transparent,
            border: Border.all(
              color: allSelected ? colors.primary : colors.textDisabled,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: allSelected
              ? Icon(Icons.check, size: 15, color: colors.onPrimary)
              : null,
        ),
      ),
    );
  }
}

/// ソート種別を切り替えるチップ列(横スクロール)。
class _SortBar extends StatelessWidget {
  const _SortBar({required this.controller});

  final FileListController controller;

  static const List<(FileSortMode, String)> _modes = [
    (FileSortMode.name, '元の名前順'),
    (FileSortMode.createdAt, '作成日時順'),
    (FileSortMode.size, 'サイズ順'),
    (FileSortMode.custom, 'カスタム順'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (final (mode, label) in _modes) ...[
              _SortChip(
                label: label,
                active: controller.sortMode == mode,
                onTap: () => controller.setSortMode(mode),
              ),
              const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colors.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? colors.primary.withValues(alpha: 0.45)
                : colors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? colors.primary : colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 1行: チェックボックス + 現在名(左) + 変更後名(右)。
class _FileRow extends StatelessWidget {
  const _FileRow({required this.row, required this.onToggle});

  final RowView row;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: row.selected,
            onChanged: (_) => onToggle(),
            activeColor: colors.primary,
            checkColor: colors.onPrimary,
          ),
          Expanded(
            child: Text(
              row.currentName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 14, color: colors.textMuted),
          ),
          Expanded(child: _NewName(row: row)),
        ],
      ),
    );
  }
}

/// 変更後名セル。未選択は対象外表示、変更なしはその旨、それ以外はアクセント色。
class _NewName extends StatelessWidget {
  const _NewName({required this.row});

  final RowView row;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final newName = row.newName;
    if (newName == null) {
      return Text(
        '—',
        style: TextStyle(color: colors.textDisabled, fontSize: 13),
      );
    }
    final unchanged = newName == row.currentName;
    return Text(
      newName,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: unchanged ? colors.textSecondary : colors.primary,
        fontSize: 13,
        fontWeight: unchanged ? FontWeight.w400 : FontWeight.w500,
      ),
    );
  }
}
