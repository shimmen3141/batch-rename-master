import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../../data/preview/file_preview.dart';
import '../common/app_toast.dart';
import '../file_list/file_list_controller.dart';
import '../file_list/removal_selection.dart';
import '../file_list/file_list_view.dart';
import '../file_list/row_view.dart';
import '../rename_exec/rename_execution_controller.dart';
import '../theme/app_colors.dart';
import 'rule_builder_view.dart';
import 'rule_controller.dart';
import '../theme/app_typography.dart';

/// ファイルリスト(002)とルールビルダー(003)を束ねるワークスペース外殻。
///
/// [rule](003)の変更を [fileList](002)の `setRule` に流してプレビューを更新し
/// (003 REQ-006 → 002 の行データ)、画面幅で表示方式を切り替える(PRD §3.2):
/// 幅 < [breakpoint] はモバイル(リスト全面 + ボトムシートでルール編集)、
/// 幅 ≥ [breakpoint] はデスクトップ(左リスト + 右ルールの 2 ペイン)。
class RuleBuilderWorkspace extends StatefulWidget {
  const RuleBuilderWorkspace({
    super.key,
    required this.fileList,
    required this.rule,
    this.renameExecution,
    this.filePreview,
    this.removalSelection,
    this.breakpoint = 840,
  });

  final FileListController fileList;
  final RuleController rule;
  final RenameExecutionController? renameExecution;

  /// 行の preview の供給元(008:T07)。[FileListView] へそのまま渡す。
  final FilePreviewPort? filePreview;

  /// 一覧の**除去のための選択モード**(002 REQ-018)。読み込み帯と共有するため
  /// composition root から通す(`008:T29`)。ここでは中身を見ず、一覧へ渡すだけである。
  final RemovalSelection? removalSelection;

  /// モバイル/デスクトップの境界幅(dp)。既定 840(003 spec 決定済み)。
  final double breakpoint;

  @override
  State<RuleBuilderWorkspace> createState() => _RuleBuilderWorkspaceState();
}

class _RuleBuilderWorkspaceState extends State<RuleBuilderWorkspace> {
  @override
  void initState() {
    super.initState();
    widget.rule.addListener(_syncRule);
    widget.rule.addListener(_scheduleRaiseDigits);
    widget.fileList.addListener(_scheduleRaiseDigits);
    // 初期ルールをプレビューへ反映(フレーム後)。**復元したルールと最初の一覧の
    // 組み合わせ(003 代表例15c)もこれで見る** — `setRule` が一覧を通知し、上の
    // 一覧の購読が引き上げを起こす。別に呼ぶと同じことを2回書くことになる
    // (mutation で等価と分かった。`008:T52`)。
    _scheduleSyncRule();
  }

  @override
  void didUpdateWidget(RuleBuilderWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) {
      oldWidget.rule.removeListener(_syncRule);
      oldWidget.rule.removeListener(_scheduleRaiseDigits);
      widget.rule.addListener(_syncRule);
      widget.rule.addListener(_scheduleRaiseDigits);
      _scheduleSyncRule();
      _scheduleRaiseDigits();
    }
    if (oldWidget.fileList != widget.fileList) {
      oldWidget.fileList.removeListener(_scheduleRaiseDigits);
      widget.fileList.addListener(_scheduleRaiseDigits);
      _scheduleRaiseDigits();
    }
  }

  /// 連番の桁数の自動の引き上げを、フレーム後に1回だけ行う(003 REQ-015)。
  ///
  /// **件数(002)とルール(003)のどちらが変わっても見る** — 件数が増えたときと、
  /// ルールが置き換わったとき(前回ルールの復元を含む)の両方で起きるためである。
  /// 引き上げはルールを変えるので、**通知の最中に同期で変えない**(同じフレームで
  /// 一覧とルールが互いの通知の中で書き換わる)。フレーム後へ回し、同じフレームの
  /// 何度もの通知は1回にまとめる。
  bool _raiseScheduled = false;
  void _scheduleRaiseDigits() {
    if (_raiseScheduled) return;
    _raiseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _raiseScheduled = false;
      if (mounted) _raiseDigits();
    });
    // フレームが要求されていないと post-frame は来ない(通知だけで画面が変わらない
    // 場合)。ここで要求しておく。
    WidgetsBinding.instance.scheduleFrame();
  }

  void _raiseDigits() {
    // 件数は連番のエディタの下限と同じもの(一覧 = rename 対象。`008:T03`)。
    final raises = widget.rule.raiseSequenceDigits(
      widget.fileList.selectedCount,
    );
    if (raises.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // **黙って変えない**(003 REQ-015)。何桁から何桁へ変えたかを読ませる。
    showAppToast(
      messenger,
      key: sequenceDigitsRaisedToastKey,
      tone: ToastTone.info,
      content: Text(sequenceDigitsRaisedMessage(raises)),
    );
  }

  /// 初期同期をフレーム後へ回す(003 T6)。
  ///
  /// `initState` / `didUpdateWidget` はビルド中に走るため、その場で
  /// [FileListController] へ通知すると、同じフレームで同じコントローラを購読して
  /// いる他のウィジェット(読み込み入口のバー等)が「ビルド中の `setState`」に
  /// なって落ちる。ユーザー操作由来の [_syncRule] はビルド外なので同期実行のまま。
  void _scheduleSyncRule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRule();
    });
  }

  @override
  void dispose() {
    widget.rule.removeListener(_syncRule);
    widget.rule.removeListener(_scheduleRaiseDigits);
    widget.fileList.removeListener(_scheduleRaiseDigits);
    super.dispose();
  }

  /// 選択されている最初のファイル(表示順)= 連番の1番目が振られるファイル。
  /// トークンのエディタの表示例(008:T44)とチップの値(008:T45)に使う。
  FileEntry? _firstFile() => firstSelectedRow(widget.fileList)?.source;

  /// 現在のルールをファイルリストへ渡す(プレビュー更新)。
  void _syncRule() => widget.fileList.setRule(widget.rule.rule);

  /// 狭幅のルール構築シート(参考デザインのボトムシート。008:T45)。
  ///
  /// 取っ手・見出し「命名ルール」・上端の角丸と、下部に1つ目のファイルの
  /// プレビューを置く。**「閉じる」ボタンは置かない**(開発者の決定: 逆に混乱を
  /// 招く)。閉じるのは外のタップ・下へのスワイプ・戻る操作。
  void _openRuleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: ruleSheetKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHeader(),
              RuleBuilderView(
                controller: widget.rule,
                itemCount: () => widget.fileList.selectedCount,
                sampleFile: _firstFile,
                sampleListenable: widget.fileList,
              ),
              _SheetPreview(fileList: widget.fileList),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= widget.breakpoint;
        return wide ? _buildWide(context) : _buildNarrow(context);
      },
    );
  }

  /// デスクトップ: 左にファイルリスト、右にルールビルダーの 2 ペイン。
  Widget _buildWide(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FileListView(
            controller: widget.fileList,
            renameExecution: widget.renameExecution,
            filePreview: widget.filePreview,
            removalSelection: widget.removalSelection,
            // ルールビルダーが右ペインに常時見えているので、下部バーには
            // 実行だけを置く(ルール設定への導線は重複させない)。
          ),
        ),
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(left: BorderSide(color: colors.border)),
          ),
          // **ルール単位の警告表示はここに無い**(2026-09-02 の開発者の決定。
          // 原文は「**ルールの警告は無くす。**これによって、ルールの警告と個々の
          // ファイルへの警告の2つに分かれていたものが、個々のファイルへの警告
          // だけになって認知負荷が下がると思う」)。**警告はファイル単位へ
          // 一本化した** — 種別は各行が出し(005 REQ-009 (1)。008:T18)、原因の
          // 説明は詳細dialogが持つ(同 (3) / (4))。
          //
          // **狭幅のルール設定buttonからも同時に外している**(008:T20)。片方に
          // だけ残すと、開発者が減らそうとした「警告が散らばっている」状態が
          // desktop 側に残る。
          child: RuleBuilderView(
            controller: widget.rule,
            itemCount: () => widget.fileList.selectedCount,
            sampleFile: _firstFile,
            sampleListenable: widget.fileList,
          ),
        ),
      ],
    );
  }

  /// モバイル: リスト全面 + 下部バー(ルール設定 + 実行)。
  ///
  /// ルール編集と実行は参考デザインどおり同じ下部バーへ集約し、[FileListView] が
  /// リストの下に描画する。ここで別のバーを持つと、未設定の案内と実行が上下に
  /// 分かれてしまう。
  Widget _buildNarrow(BuildContext context) {
    return FileListView(
      controller: widget.fileList,
      renameExecution: widget.renameExecution,
      filePreview: widget.filePreview,
      removalSelection: widget.removalSelection,
      onEditRule: _openRuleSheet,
    );
  }
}

/// 選択されている最初の行(表示順)。無ければ null。連番の1番目が振られる行で、
/// ルール構築のプレビュー・チップの値・エディタの表示例が揃って指す(008:T45)。
RowView? firstSelectedRow(FileListController fileList) {
  for (final row in fileList.rows) {
    if (row.selected) return row;
  }
  return null;
}

/// ルール構築シートの key(008:T45)。
const Key ruleSheetKey = Key('rule-sheet');

/// シートのプレビューの key(008:T45)。
const Key ruleSheetPreviewKey = Key('rule-sheet-preview');

/// プレビューの2行目(変更あり / 変更なし)の箱の key。高さを揃える(008:T45)。
const Key ruleSheetPreviewResultKey = Key('rule-sheet-preview-result');

/// シートの見出し「命名ルール」(参考デザイン)。区切り線の上に置く。
class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
      ),
      child: Text(
        '命名ルール',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: AppFontSize.titleLarge,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// シートの下部のプレビュー: 1つ目のファイルの元の名前 → 新しい名前(参考デザイン)。
///
/// シートを開いている間は一覧が隠れるので、ルールの結果をここで見せる。一覧が
/// 空なら出さない。名前が変わらなければ元の名前を灰色で出し「（変更なし）」と書く。
class _SheetPreview extends StatelessWidget {
  const _SheetPreview({required this.fileList});

  final FileListController fileList;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: fileList,
      builder: (context, _) {
        // チップの値と同じファイル(選択されている最初のファイル)を見せる。
        // 未選択の行は変更後名を持たない(002 REQ-007)ので、1件目が未選択でも
        // 「変更なし」と取り違えない(008:T45 独立review attempt 1 の指摘)。
        final row = firstSelectedRow(fileList);
        if (row == null) return const SizedBox.shrink();
        final newName = row.newName!;
        final changed = newName != row.currentName;
        return Container(
          key: ruleSheetPreviewKey,
          // 画面の下端に寄りすぎないよう、下に少し余白を足した(manual 1回目の
          // 開発者の要望)。
          margin: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'プレビュー（1つ目のファイル）',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: AppFontSize.caption,
                ),
              ),
              const SizedBox(height: 7),
              // 名前は1行に収める。折り返すと、ルールを変えるたびに新しい名前の長さで
              // シートの高さが変わってガタつく(manual 2回目の開発者の指摘)。
              Text(
                row.currentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: changed
                      ? colors.danger.withValues(alpha: 0.85)
                      : colors.textSecondary,
                  decoration: changed ? TextDecoration.lineThrough : null,
                  decorationColor: colors.danger.withValues(alpha: 0.85),
                  fontSize: AppFontSize.small,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              // 2行目は変更あり(矢印と新しい名前)でも変更なしでも同じ高さの箱に
              // 入れる。行の高さが違うと、切り替わるたびにシートがガタつく
              // (manual 2回目の開発者の指摘)。
              SizedBox(
                key: ruleSheetPreviewResultKey,
                // 文字の拡大に合わせる(独立review attempt 4 の指摘)。
                height: MediaQuery.textScalerOf(context).scale(20),
                child: changed
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '→ ',
                            style: TextStyle(
                              // 薄くて見えづらかった(manual 1回目の開発者の要望)。
                              color: colors.textPrimary,
                              fontSize: AppFontSize.small,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Expanded(
                            child: Text(
                              newName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.success,
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '（変更なし）',
                          style: TextStyle(
                            color: colors.textDisabled,
                            fontSize: AppFontSize.caption,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 連番の桁数を自動で引き上げたときの通知(003 REQ-015)。
const Key sequenceDigitsRaisedToastKey = Key('sequence-digits-raised');

/// 通知の文言。**何桁から何桁へ変えたかを読ませる**(003 REQ-015)。連番が複数なら
/// 変えたものを順に並べる。
String sequenceDigitsRaisedMessage(List<SequenceDigitsRaise> raises) {
  if (raises.length == 1) {
    final r = raises.single;
    return 'ファイルの数に合わせて、連番の桁数を${r.from}桁から${r.to}桁へ増やしました';
  }
  final parts = [for (final r in raises) '${r.from}桁→${r.to}桁'].join('、');
  return 'ファイルの数に合わせて、連番の桁数を増やしました($parts)';
}
