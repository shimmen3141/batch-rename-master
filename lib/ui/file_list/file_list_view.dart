import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../../data/file_source/file_source.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../rename_exec/rename_execution_controller.dart';
import '../theme/app_colors.dart';
import 'file_list_controller.dart';
import 'file_sort.dart';
import 'rename_warning_view.dart';
import 'row_view.dart';

/// 更新日時ずらしの設定(005 REQ-014。書ける端末でだけ出る)。
const Key shiftModifiedAtKey = Key('shift-modified-at');

/// メイン画面のファイルリスト(002 spec の描画層)。
///
/// [FileListController] を購読して描画するだけの薄いウィジェット。ロジックは
/// 持たず、操作は controller のメソッドへ委譲する。左に現在名・右に変更後名の
/// 2カラム、各行にチェックボックス、上部にソート切替チップを置く(PRD §3.1)。
/// 視覚は参考デザインに準拠し、色は [AppColors] のセマンティック名で参照する。
class FileListView extends StatelessWidget {
  const FileListView({
    super.key,
    required this.controller,
    this.renameExecution,
    this.onEditRule,
  });

  final FileListController controller;
  final RenameExecutionController? renameExecution;

  /// ルール編集を開く導線(REQ-020 の「ルールを設定すれば進める」)。
  ///
  /// ルールビルダーが常時見えているレイアウト(デスクトップの 2 ペイン)では
  /// `null` を渡し、下部バーには実行だけを置く。
  final VoidCallback? onEditRule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?renameExecution]),
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
              // ルールが空なら警告ではなく未設定を提示する(005 REQ-020)。
              // トークンが加われば自動でこの分岐が戻り、通常の警告提示になる。
              if (controller.isRuleEmpty)
                const RuleNotConfiguredBanner()
              else
                // 001 の検証が返す警告(005 REQ-009 / REQ-010)。0 件なら出ない。
                RenameWarningPanel(warnings: controller.warnings),
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
              // 参考デザインどおり、ルール設定と実行はリストより下の固定バーへ
              // まとめる(T09 で T04 の上部配置から移設)。
              if (renameExecution != null || onEditRule != null)
                _RenameActionBar(
                  controller: controller,
                  execution: renameExecution,
                  onEditRule: onEditRule,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// リストの下に固定するアクションバー(参考デザインの下部バー)。
///
/// 上段にルール設定への導線、下段に実行を置く。ルールが空のときは実行を無効に
/// したうえで、ルール設定ボタンを主役の表示へ入れ替える(005 REQ-019 / REQ-020)。
class _RenameActionBar extends StatelessWidget {
  const _RenameActionBar({
    required this.controller,
    required this.execution,
    required this.onEditRule,
  });

  final FileListController controller;

  /// 実行境界。デモやリスト単体の描画では `null`(実行ボタンを出さない)。
  final RenameExecutionController? execution;
  final VoidCallback? onEditRule;

  Future<void> _request(BuildContext context) async {
    final execution = this.execution;
    // REQ-019: 空ルールでは実行を要求しても開始しない(controller 側でも止める)。
    if (execution == null || execution.isRunning || controller.isRuleEmpty) {
      return;
    }
    // REQ-028: 占有名を**実行を要求したこの時点で取り直す**。読み込み時の観測で
    // 判定すると、そのあと他processが作ったfileとの衝突が事前検出をすり抜ける。
    final prepared = await execution.prepare();
    if (prepared is OccupiedNamesUnavailable) {
      // REQ-027: 実在名を取得できなかったfolderがある。**実行を行わず理由を出す。**
      // 「取得できなかった」を「衝突が無い」と読まない。
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('rename-occupied-names-unavailable'),
          content: Text(_unavailableMessage(prepared.reasons)),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final occupiedNames = (prepared as OccupiedNamesReady).names;

    // 確認ダイアログも帯と同じ提示単位を使う(REQ-021 のまとめを両方へ効かせる)。
    // `prepare` が取り直した占有名を `controller` へ反映済みなので、この警告には
    // 占有名との衝突が含まれる(REQ-026 / REQ-028)。
    final warnings = presentWarnings(controller.warnings);
    if (warnings.isNotEmpty) {
      final force = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('rename-confirmation-dialog'),
          title: const Text('警告を確認してください'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final warning in warnings) Text('• ${warning.message}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('rename-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('rename-force'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('強制実行'),
            ),
          ],
        ),
      );
      if (force != true || !context.mounted) return;
      await _run(context, force: true, occupiedNames: occupiedNames);
      return;
    }
    await _run(context, force: false, occupiedNames: occupiedNames);
  }

  /// 実在名を取得できなかった folder の提示文(REQ-027)。
  ///
  /// **どのfolderがなぜ駄目かを出す。** 件数だけでは利用者が直しようがない。
  static String _unavailableMessage(Map<String?, PickError> reasons) {
    final lines = [
      for (final entry in reasons.entries)
        '${entry.key ?? '(場所不明)'}: ${entry.value.message ?? entry.value.kind.name}',
    ];
    return 'フォルダ内のファイル名を確認できないため実行しませんでした。'
        '${lines.join(' / ')}';
  }

  /// 結果の本文。再採番が起きた項目は**全件**を並べる(REQ-024)。
  ///
  /// 件数だけでは「どれが変わったか」が分からず、先頭数件で打ち切ると
  /// **残りは黙って別の名前になる**。多いときは高さを制限してスクロールさせ、
  /// 落とさない。
  Widget _resultContent(String summary, List<SuccessfulRename> renumbered) {
    if (renumbered.isEmpty) return Text(summary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 96),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in renumbered)
                  Text('${s.confirmedName} → ${s.newName}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context, {
    required bool force,
    required OccupiedNames occupiedNames,
  }) async {
    final execution = this.execution!;
    final outcome = await execution.execute(
      force: force,
      occupiedNames: occupiedNames,
    );
    if (outcome == null || !context.mounted) return;
    final message = StringBuffer('${outcome.successes.length} 件を改名しました');
    final excluded = execution.excludedEmptyNames.length;
    if (excluded > 0) message.write('。名前が空になるため $excluded 件を除外しました');
    // REQ-024: 実行中に再採番が起きた項目は、確認した名前と結果名が違う。
    // **黙って別の名前にしない** — 何件がどの名前になったかを示す。件数だけだと
    // 「どれが変わったか」が分からないので、少数なら名前を並べる。
    final renumbered = [
      for (final success in outcome.successes)
        if (success.renumbered) success,
    ];
    if (renumbered.isNotEmpty) {
      message.write('。実行中に名前が使われていたため ${renumbered.length} 件の名前が変わりました');
    }
    final failure = outcome.failure;
    if (failure != null) {
      message.write('。失敗: ${failure.error.message ?? failure.error.kind.name}');
    }
    // 更新日時の設定失敗は改名の失敗と分けて書く。混ぜると「改名できたのか」が
    // 読めなくなる(REQ-016)。
    final shiftFailures = execution.modifiedAtFailures.length;
    if (shiftFailures > 0) {
      message.write('。改名は成功しましたが、$shiftFailures 件の更新日時は変更できませんでした');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // 結果の提示(REQ-013)へ到達したことを観測できるようにする。実行ボタンは
        // fire-and-forget なので、途中で例外が抜けると**何も起きない**状態と
        // 区別が付かない。
        key: const Key('rename-result'),
        content: _resultContent(message.toString(), renumbered),
        // undo はこのトースト内に置く(参考デザインどおり)。下部バーへ置くと
        // 結果トーストがバーを覆い、取り消せる 5 秒の間だけ押せなくなる。
        duration: execution.undoWindow,
        // action があると既定で消えなくなる(persist)。undo は 5 秒で期限切れ
        // (REQ-007)なので、押せなくなった undo を残さないよう明示的に消す。
        persist: false,
        action: execution.canUndo
            ? SnackBarAction(
                key: const Key('rename-undo'),
                label: '元に戻す',
                onPressed: () => _undo(context),
              )
            : null,
      ),
    );
  }

  Future<void> _undo(BuildContext context) async {
    final outcome = await execution!.undo();
    if (outcome == null || !context.mounted) return;
    final message = StringBuffer('${outcome.successes.length} 件を元に戻しました');
    final failure = outcome.failure;
    if (failure != null) {
      message.write('。失敗: ${failure.error.message ?? failure.error.kind.name}');
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final execution = this.execution;
    final empty = controller.isRuleEmpty;
    final running = execution?.isRunning ?? false;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onEditRule != null) ...[
                _RuleButton(empty: empty, onPressed: onEditRule!),
                const SizedBox(height: 10),
              ],
              // 更新日時ずらし。設定できない端末では出さない(REQ-015)。
              if (execution != null && execution.canShiftModifiedAt) ...[
                _ShiftModifiedAtToggle(execution: execution),
                const SizedBox(height: 6),
              ],
              if (execution != null)
                FilledButton.icon(
                  key: const Key('rename-action'),
                  // REQ-019: ルールが空の間は実行を提示しない(押せない)。
                  onPressed: running || empty ? null : () => _request(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  icon: running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.drive_file_rename_outline),
                  label: Text(
                    running
                        ? '処理中…'
                        : empty
                        ? 'ルールを設定してください'
                        : '名前を変更',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 更新日時ずらしの入切(005 REQ-014)。
///
/// 設定できる端末でだけ [_RenameActionBar] が描画する(REQ-015)。既定は OFF で、
/// 入れると改名成功後に一覧の並び順で更新日時をずらす。
class _ShiftModifiedAtToggle extends StatelessWidget {
  const _ShiftModifiedAtToggle({required this.execution});

  final RenameExecutionController execution;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      key: shiftModifiedAtKey,
      onTap: () => execution.setShiftModifiedAt(!execution.shiftModifiedAt),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: execution.shiftModifiedAt,
                onChanged: (value) =>
                    execution.setShiftModifiedAt(value ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '更新日時を一覧の並び順にずらす',
                style: TextStyle(color: colors.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ルール編集への導線。未設定のときだけ主役の表示へ入れ替える(REQ-020)。
class _RuleButton extends StatelessWidget {
  const _RuleButton({required this.empty, required this.onPressed});

  final bool empty;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (empty) {
      return FilledButton.icon(
        key: const Key('configure-rule'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('変更する名前を設定する'),
      );
    }
    return OutlinedButton.icon(
      key: const Key('configure-rule'),
      onPressed: onPressed,
      icon: const Icon(Icons.tune, size: 18),
      label: const Text('ルールを編集'),
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
