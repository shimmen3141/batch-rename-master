import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../../data/file_source/file_source.dart';
import '../../data/preview/file_preview.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../rename_exec/rename_execution_controller.dart';
import '../theme/app_colors.dart';
import 'file_list_controller.dart';
import 'file_sort.dart';
import 'rename_warning_view.dart';
import 'row_preview_view.dart';
import 'row_view.dart';

/// 更新日時ずらしの設定(005 REQ-014。書ける端末でだけ出る)。
const Key shiftModifiedAtKey = Key('shift-modified-at');

/// 行サブ情報の場所(002 REQ-010)。行ごとに1つで、場所を持たない行には無い。
const Key rowLocationKey = Key('row-location');

/// 行サブ情報の作成日時(002 REQ-013)。**並び順chipや代替警告と同じ語を含む**ため、
/// testが行の中の日時だけを指せるようにkeyを持たせる。
const Key rowCreatedAtKey = Key('row-created-at');

/// 行サブ情報の更新日時。狭幅では作成日時より先に削られる側である(008:T07)。
const Key rowModifiedAtKey = Key('row-modified-at');

/// メイン画面のファイルリスト(002 spec の描画層)。
///
/// [FileListController] を購読して描画するだけの薄いウィジェット。ロジックは
/// 持たず、操作は controller のメソッドへ委譲する。各行はチェックボックスの右へ
/// 現在名・変更後名・サブ情報を**縦に積み**(参考designのリッチな行。008:T07 で
/// 横2カラムから移した)、上部にソート切替チップを置く。
/// 視覚は参考デザインに準拠し、色は [AppColors] のセマンティック名で参照する。
class FileListView extends StatelessWidget {
  const FileListView({
    super.key,
    required this.controller,
    this.renameExecution,
    this.onEditRule,
    this.filePreview,
  });

  final FileListController controller;
  final RenameExecutionController? renameExecution;

  /// 行の preview の供給元(008:T07)。`null` なら種別アイコンだけを出す。
  ///
  /// **`null` が既定である。** demo データや preview を持たない画面で、実 file を
  /// 触ろうとしないようにするためである。
  final FilePreviewPort? filePreview;

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
        // 行データと警告は同じ検証から作れる。ビルド1回につき一度だけ評価する
        // (`rows` と `warnings` を別々に呼ぶと 001 の検証が2回走る)。
        final preview = controller.preview;
        final rows = preview.rows;
        final warnings = preview.warnings;
        // 005 REQ-020: ルールが空なら警告を提示しない。**行にも出さない。**
        final ruleIsEmpty = controller.isRuleEmpty;
        return Container(
          color: colors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBar(
                controller: controller,
                // 一覧全体の件数(005 REQ-009 (3) の入口)。**常時 1 行に収まり、
                // 一覧を覆わない** — 集約帯を廃止した狙いがこれである。
                warnings: ruleIsEmpty ? const <Warning>[] : warnings,
              ),
              _SortBar(controller: controller),
              _CreatedAtFallbackBanner(
                warning: controller.createdAtSortWarning,
              ),
              // ルールが空なら警告ではなく未設定を提示する(005 REQ-020)。
              // トークンが加われば自動でこの分岐が戻り、通常の警告提示になる。
              if (ruleIsEmpty) const RuleNotConfiguredBanner(),
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
                      filePreview: filePreview,
                      // 005 REQ-009 (1): 種別が**展開操作を経ずに**読める。
                      warnings: rowWarningsOf(
                        row.warnings,
                        ruleIsEmpty: ruleIsEmpty,
                      ),
                      ruleIsEmpty: ruleIsEmpty,
                      onShowWarningDetail: () => showWarningDetail(
                        context,
                        warnings,
                        ruleIsEmpty: ruleIsEmpty,
                      ),
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
              //
              // 005 REQ-009 (2) の原因の提示は、**バーの手前へ積まない。**
              // 独立した子として積むと、原因の数 × 文字倍率で伸びて一覧と
              // 下部バーを押し出した(独立review attempt 3 のP1-1)。参考designの
              // ルール設定buttonが持つ「命名ルール」見出しの右へ、**種別だけ**を
              // 載せる。**広幅では下部バーに導線が無い**ため、
              // `RuleBuilderWorkspace` が右ペイン側へ同じものを描く。
              if (renameExecution != null || onEditRule != null)
                _RenameActionBar(
                  controller: controller,
                  execution: renameExecution,
                  onEditRule: onEditRule,
                  warnings: ruleIsEmpty ? const <Warning>[] : warnings,
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
    required this.warnings,
  });

  final FileListController controller;

  /// 実行境界。デモやリスト単体の描画では `null`(実行ボタンを出さない)。
  final RenameExecutionController? execution;
  final VoidCallback? onEditRule;

  /// ルール設定buttonへ載せる警告(005 REQ-009 (2))。ルールが空なら空で渡る。
  final List<Warning> warnings;

  Future<void> _request(BuildContext context) async {
    final execution = this.execution;
    // REQ-019: **変更が生じるファイルが0件なら実行を要求しても開始しない**
    // (controller 側でも止める)。空ルールはこの0件に含まれるが、それだけではない。
    if (execution == null ||
        execution.isRunning ||
        !controller.hasChangedFiles) {
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
    if (!context.mounted) return;
    // 権限が取り消されていた場合(013 REQ-004)。**黙って何も起きない**のは
    // 「壊れている」ように見えるので、理由を出す。実体には触れていない(INV-002)。
    if (execution.permissionDenied) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const Key('execute-permission-denied'),
          content: const Text(
            '「すべてのファイルへのアクセス」が許可されていないため、名前を変更できませんでした。'
            '端末の設定で許可してから、もう一度お試しください。',
          ),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    if (outcome == null) return;
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
        // **固定 key を付けない。** `showSnackBar` は key が null のときだけ
        // `UniqueKey` を fallback に入れ、連続する snackbar が構造的に一致した
        // ときの ink splash / highlight の持ち越しを防いでいる。結果トーストは
        // undo ボタンを含むので、固定 key を付けるとその持ち越しが起きうる。
        // 到達の観測は本文(「N 件を改名しました」)で足りる。
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
    final execution = this.execution!;
    final outcome = await execution.undo();
    if (!context.mounted) return;
    // undo も書き込みなので、権限が取り消されていれば断る(013 INV-002)。
    // **黙って何も起きない**のは「壊れている」ように見えるので理由を出す。
    if (execution.permissionDenied) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const Key('undo-permission-denied'),
          content: const Text(
            '「すべてのファイルへのアクセス」が許可されていないため、元に戻せませんでした。'
            '端末の設定で許可してから、もう一度お試しください。',
          ),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    if (outcome == null) return;
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
    // 005 REQ-019: 実行できるのは**変更が生じるファイルが1件以上ある**ときだけ。
    final changedCount = controller.changedFileCount;
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
                _RuleButton(
                  empty: empty,
                  onPressed: onEditRule!,
                  summary: describeRuleSummary(controller.rule),
                  warnings: warnings,
                ),
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
                  // REQ-019: 変更が生じるファイルが0件の間は押せない。
                  onPressed: running || changedCount == 0
                      ? null
                      : () => _request(context),
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

/// ルール編集への導線(参考designの2行button)。
///
/// design は `[✎] 命名ルール / <設定中のルール>` の2行に `編集` を添えた形で、
/// **「命名ルール」見出しの右に空きがある**。005 REQ-009 (2) の原因の提示を
/// そこへ置く(008:T15 が土台として申し送り、開発者が2026-08-31に選択)。
///
/// **載せるのは種別だけである。**説明そのものを載せると原因の数と文字倍率で
/// buttonが伸び、下部バーごと一覧を押し出す(独立review attempt 3 のP1-1)。
/// 種別は最大2つなので占有が定数に収まる。説明は詳細dialogが持つ。
///
/// ルールが空のときは design の2行ではなく**主役のbutton**へ入れ替える
/// (005 REQ-019 / REQ-020)。この状態では警告も出さない。
class _RuleButton extends StatelessWidget {
  const _RuleButton({
    required this.empty,
    required this.onPressed,
    required this.summary,
    required this.warnings,
  });

  final bool empty;
  final VoidCallback onPressed;

  /// 設定中のルールの1行要約(design の2行目)。
  final String summary;

  /// 見出しの右へ出す警告。ルールが空なら空で渡る。
  final List<Warning> warnings;

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
    return OutlinedButton(
      key: const Key('configure-rule'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 見出しと警告。**`Wrap` なので、入らなければ切らずに次の行へ
                // 落ちる**(切り詰めると種別が読めなくなる)。
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '命名ルール',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    RuleWarningNotice(
                      warnings: warnings,
                      ruleIsEmpty: empty,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  summary,
                  key: ruleSummaryKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '編集',
            style: TextStyle(
              color: colors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 全選択トグルと選択件数を表示するヘッダ。
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.controller, required this.warnings});

  final FileListController controller;

  /// 一覧全体の警告(005 REQ-009 (3) の入口。ルールが空なら空で渡る)。
  final List<Warning> warnings;

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
      // **`Row` ではなく `Wrap` である。** `Row` に並べると、幅が足りないときに
      // 「はみ出す」か「切り詰める」しかない。切り詰めは overflow を出さないので
      // 検査をすり抜けたうえ、`200 / 20…` のように**総数を誤読できる**形で壊れる
      // (独立reviewが見つけた)。`Wrap` なら**どちらも intrinsic 幅のまま次の行へ
      // 落ちる**ので、狭幅でも文字サイズを上げても数字が消えない。
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SelectAllButton(
                key: const Key('select-all-toggle'),
                allSelected: allSelected,
                enabled: total > 0,
                onPressed: allSelected
                    ? controller.clearAll
                    : controller.selectAll,
              ),
              const SizedBox(width: 12),
              // 極端な文字サイズでは自分の中で折り返す(次の行へ落ちても
              // なお入らないときの最後の逃げ道)。
              Flexible(
                child: Text(
                  key: const Key('selection-count'),
                  '$selected / $total 件を選択',
                  maxLines: 2,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          // 一覧全体の件数。押すと全件の詳細が開く(005 REQ-009 (3))。
          // **ルールが空のときは出さない** — 001 は空名と重複を返しているので
          // 「問題なし」は誤りになる。005 REQ-020 は「警告を提示せず、代わりに
          // 未設定であることを提示する」なので、案内帯だけが出る。
          if (!controller.isRuleEmpty)
            WarningCountView(
              warnings: warnings,
              onTap: () => showWarningDetail(
                context,
                warnings,
                ruleIsEmpty: controller.isRuleEmpty,
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
    required this.filePreview,
    required this.warnings,
    required this.onShowWarningDetail,
    required this.ruleIsEmpty,
    this.onRemove,
  });

  /// ReorderableListView 内での行位置(ドラッグハンドルが使用)。
  final int index;
  final RowView row;

  /// 手動並び替えを提示するか(連番トークンがあるときだけ。REQ-014)。
  final bool showDragHandle;

  /// 現在のソート種別(作成日時が不明な行の強調条件に使う。REQ-013)。
  final FileSortMode sortMode;

  /// 行の preview の供給元(008:T07)。`null` なら種別アイコンだけを出す。
  final FilePreviewPort? filePreview;

  /// この行に出す警告([rowWarningsOf] を通した後)。空なら何も出ない。
  final List<Warning> warnings;

  /// ルールにトークンが1つも無いか(005 REQ-020 / REQ-029)。空なら変更後名の
  /// 代わりに「変更なし」を出す。
  final bool ruleIsEmpty;

  /// 行の警告を押したときに全件の詳細を開く(005 REQ-009 (3))。
  final VoidCallback onShowWarningDetail;

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
          // 中身が見える行にする(参考designのリッチな行)。preview を出せない
          // file は種別アイコンになるが、**枠は必ず在る**ので行の高さも名前の
          // 開始位置も揃う。
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: RowPreviewView(file: row.source, preview: filePreview),
          ),
          // 現在名・変更後名・サブ情報を**縦に積む**(参考designのリッチな行)。
          //
          // 横2カラムだと各セルが行幅の半分しか使えず、狭幅ではサブ情報が
          // 収まらない((h)の見切れの根本)。縦に積むと3つとも行幅を丸ごと
          // 使える。002 specはレイアウトを非規範としている(「対象外」節)。
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 005 REQ-009 (1)。**現在名の上に1行設けて右寄せで置く**
                // (2026-09-02 の要望8。原文は「リネーム前の名前と同じ行の右の
                // スペースか、**さらにその上に1行設けてそこに右寄せで表示する**」で、
                // 参考designも両方の変種を持つ — リッチ案は現在名と同じ行、
                // コンパクト案は上の行に `text-align:right` で置いている)。
                //
                // **同じ行ではなく上の行を選んだ。** 008:T17 の改訂で桁不足が
                // 行へ来るようになり、種別は最大3つ併発する(重複・作成日時不明・
                // 連番の桁不足)。同じ行へ載せると、狭幅では現在名か種別の
                // どちらかが必ず切り詰められる。上の行なら行幅を丸ごと使える。
                // **行数は増えない** — 警告は元から変更後名の下で1行を占めていた。
                RowWarningView(warnings: warnings, onTap: onShowWarningDetail),
                Text(
                  row.currentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
                // 「現在名 → 変更後名」という読み方は矢印で残す。
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: colors.textMuted,
                      ),
                    ),
                    Expanded(
                      child: _NewName(
                        row: row,
                        ruleIsEmpty: ruleIsEmpty,
                        hasWarning: warnings.isNotEmpty,
                      ),
                    ),
                  ],
                ),
                _DateSubInfo(file: row.source, sortMode: sortMode),
              ],
            ),
          ),
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
    final base = TextStyle(color: colors.textMuted, fontSize: 10.5);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 場所(元フォルダ)。004 が供給する行だけ表示する(REQ-010)。
          //
          // **日時と同じ行に置かない。** 同居させると狭幅で場所が幅を使い切り、
          // 後ろにある `作成日時: 不明` から省略される(008:T07 の (h))。
          if (file.sourceLocation != null)
            Text(
              file.sourceLocation!,
              key: rowLocationKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base,
            ),
          // **2つの日時は `Wrap` に置く。** 横に並びきらなければ更新日時が
          // 次の行へ落ち、作成日時は丸ごと残る。
          //
          // `Row` で作成日時を「縮まない側」に置くと、幅が足りなくなった瞬間に
          // 省略ではなく **overflow** になる(独立review attempt 1 の P1-1)。
          // 更新日時を削るだけでは足りず、作成日時自身にも下限が要る。
          // ここでも「優先順位ではなく行数で解く」を一段深く適用している。
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (emphasize) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 11,
                      color: colors.danger,
                    ),
                    const SizedBox(width: 3),
                  ],
                  // 最後の砦として省略も持たせる。**1行に単独で置いても入らない**
                  // ほど狭いとき(極端な font scale など)に、はみ出させない。
                  Flexible(
                    child: Text(
                      '作成日時: ${unknown ? '不明' : _format(createdAt)}',
                      key: rowCreatedAtKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: emphasize ? colors.danger : colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              // 入りきらなければ**次の行へ落ちる**。作成日時を削らない。
              Text(
                '更新日時: ${_format(file.modifiedAt)}',
                key: rowModifiedAtKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 変更後名セル。未選択は対象外表示、変更なしはその旨、それ以外はアクセント色。
class _NewName extends StatelessWidget {
  const _NewName({
    required this.row,
    required this.ruleIsEmpty,
    required this.hasWarning,
  });

  final RowView row;

  /// ルールにトークンが1つも無いか(005 REQ-029)。
  final bool ruleIsEmpty;

  /// この行に警告が出ているか。**変更後名の色をこれで決める**(参考designの
  /// `newColor: bad ? 赤 : 緑`)。
  final bool hasWarning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final newName = row.newName;
    // 未選択行はプレビュー対象外(002 REQ-007)。「変更なし」とは別物なので
    // 区別する — 選べば変わりうる。
    if (newName == null) {
      return Text(
        '—',
        style: TextStyle(color: colors.textDisabled, fontSize: 13),
      );
    }
    // 005 REQ-029: **変更が生じない行は、生成後名の代わりに「変わらない」ことが
    // 読める。** 空のルールの生成後名(`.jpg` のような拡張子だけの名前)を変更後名
    // として出さない — REQ-019 によりその名前が実体に付くことはない。
    if (rowHasNoChange(row, ruleIsEmpty: ruleIsEmpty)) {
      return Text(
        unchangedLabel,
        key: rowUnchangedKey,
        overflow: TextOverflow.ellipsis,
        // **強調しない**(参考designも `（変更なし）` を弱い色で置いている)。
        style: TextStyle(color: colors.textMuted, fontSize: 13),
      );
    }
    return Text(
      newName,
      key: rowNewNameKey,
      overflow: TextOverflow.ellipsis,
      // 参考design: `newColor: bad ? '#f87171' : '#4ade80'`。
      // 正常なら success、警告対象なら danger(2026-09-02 の要望7)。
      style: TextStyle(
        color: hasWarning ? colors.danger : colors.success,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// 変更後名の代わりに出す文言(005 REQ-029)。
const String unchangedLabel = '（変更なし）';

/// 「変更なし」を出している変更後名。
const Key rowUnchangedKey = Key('row-unchanged');

/// 実際の変更後名を出している変更後名。
const Key rowNewNameKey = Key('row-new-name');
