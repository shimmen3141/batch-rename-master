import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
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
              _CreatedAtFallbackBanner(
                warning: controller.createdAtSortWarning,
              ),
              Expanded(
                child: ReorderableListView.builder(
                  // ドラッグは行末尾のハンドルからのみ開始する(チェックボックスや
                  // 行タップと衝突させない)。
                  buildDefaultDragHandles: false,
                  itemCount: rows.length,
                  // onReorderItem は newIndex を削除後の挿入先へ調整済みで渡す。
                  onReorderItem: controller.reorder,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final handle = row.source.sourceHandle;
                    return _FileRow(
                      // ReorderableListView は各子に安定 Key を要求する。
                      // FileEntry は同一性で扱う値なので ValueKey で追従する。
                      key: ValueKey(row.source),
                      index: index,
                      row: row,
                      // 並び順が出力に効くのは連番があるときだけ(REQ-014)。
                      showDragHandle: controller.manualOrderMatters,
                      sortMode: controller.sortMode,
                      onToggle: () => controller.toggleSelection(row.source),
                      // 元場所ハンドルを持つ行だけ個別に外せる(004 REQ-006)。
                      onRemove: handle == null
                          ? null
                          : () => controller.removeFile(handle),
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

  /// 常に提示するソート(閲覧・確認の用途があるため。REQ-014)。
  static const List<(FileSortMode, String)> _alwaysModes = [
    (FileSortMode.name, '元の名前順'),
    (FileSortMode.createdAt, '作成日時順'),
    (FileSortMode.modifiedAt, '更新日時順'),
    (FileSortMode.size, 'サイズ順'),
  ];

  /// 連番トークンがあるときだけ提示する(並び順が出力に効くのはそのときだけ)。
  static const (FileSortMode, String) _customMode = (
    FileSortMode.custom,
    'カスタム順',
  );

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
            for (final (mode, label) in [
              ..._alwaysModes,
              if (controller.manualOrderMatters) _customMode,
            ]) ...[
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

/// 作成日時ソート時に「不明な件数を更新日時で代替した」ことを知らせる帯(REQ-011)。
///
/// [warning] が `null`(不明 0 件、または作成日時以外のソート)なら何も表示しない。
class _CreatedAtFallbackBanner extends StatelessWidget {
  const _CreatedAtFallbackBanner({required this.warning});

  final CreatedAtFallbackWarning? warning;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    if (warning == null) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      key: const Key('created-at-fallback-warning'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.danger.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '作成日時を取得できないファイルが ${warning.unknownCount} 件あります。'
              'それらは更新日時で代替して並べています。',
              style: TextStyle(color: colors.danger, fontSize: 11.5),
            ),
          ),
        ],
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

/// 1行: チェックボックス + 現在名(左) + 変更後名(右) + ドラッグハンドル。
class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.index,
    required this.row,
    required this.onToggle,
    required this.showDragHandle,
    required this.sortMode,
    this.onRemove,
  });

  /// ReorderableListView 内での行位置(ドラッグハンドルが使用)。
  final int index;
  final RowView row;

  /// 手動並び替えを提示するか(連番トークンがあるときだけ。REQ-014)。
  final bool showDragHandle;

  /// 現在のソート種別(作成日時が不明な行の強調条件に使う。REQ-013)。
  final FileSortMode sortMode;
  final VoidCallback onToggle;

  /// この行を作業セットから外す(元場所ハンドルを持たない行では `null`)。
  final VoidCallback? onRemove;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.currentName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
                _DateSubInfo(file: row.source, sortMode: sortMode),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 14, color: colors.textMuted),
          ),
          Expanded(child: _NewName(row: row)),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              color: colors.textMuted,
              tooltip: 'このファイルを外す',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.drag_handle,
                  size: 18,
                  color: colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 行のサブ情報: 場所(元フォルダ)と、作成日時・更新日時の双方(REQ-010 / REQ-013)。
///
/// 場所は同名・非同名に関わらず常時表示する(別フォルダの同名ファイルを見分ける
/// 手がかりになる)。作成日時が不明な行は「作成日時: 不明」を危険色+警告アイコンで
/// 示し、更新日時で代替されたことを行レベルで見分けられるようにする。見た目は
/// 非規範だが、色は [AppColors] のセマンティック名から取る(生の色値を書かない)。
class _DateSubInfo extends StatelessWidget {
  const _DateSubInfo({required this.file, required this.sortMode});

  final FileEntry file;

  /// 現在のソート種別。**作成日時ソートのときだけ**不明を強調する(REQ-013)。
  final FileSortMode sortMode;

  static String _format(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}/${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final createdAt = file.createdAt;
    final unknown = createdAt == null;
    // 表示は常にするが、強調(警告色+アイコン)は作成日時ソートのときだけ
    // (他のソートでは日時は単なる情報で、強調は不要な警告になる。REQ-013)。
    final emphasize = unknown && sortMode == FileSortMode.createdAt;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          if (emphasize) ...[
            Icon(Icons.warning_amber_rounded, size: 11, color: colors.danger),
            const SizedBox(width: 3),
          ],
          // 1つの Text にまとめ、狭幅では省略する(行内で溢れさせない)。
          // 色は span で分け、不明な作成日時だけを危険色にする。
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  // 場所(元フォルダ)。004 が供給する行だけ表示する(REQ-010)。
                  if (file.sourceLocation != null)
                    TextSpan(text: '${file.sourceLocation} · '),
                  TextSpan(
                    text: '作成日時: ${unknown ? '不明' : _format(createdAt)}',
                    style: TextStyle(
                      color: emphasize ? colors.danger : colors.textMuted,
                    ),
                  ),
                  TextSpan(text: ' / 更新日時: ${_format(file.modifiedAt)}'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 10.5),
            ),
          ),
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
