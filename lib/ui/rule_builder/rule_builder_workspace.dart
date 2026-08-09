import 'package:flutter/material.dart';

import '../file_list/file_list_controller.dart';
import '../file_list/file_list_view.dart';
import '../rename_exec/rename_execution_controller.dart';
import '../theme/app_colors.dart';
import 'rule_builder_view.dart';
import 'rule_controller.dart';

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
    this.breakpoint = 840,
  });

  final FileListController fileList;
  final RuleController rule;
  final RenameExecutionController? renameExecution;

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
    _scheduleSyncRule(); // 初期ルールをプレビューへ反映(フレーム後)。
  }

  @override
  void didUpdateWidget(RuleBuilderWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) {
      oldWidget.rule.removeListener(_syncRule);
      widget.rule.addListener(_syncRule);
      _scheduleSyncRule();
    }
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
    super.dispose();
  }

  /// 現在のルールをファイルリストへ渡す(プレビュー更新)。
  void _syncRule() => widget.fileList.setRule(widget.rule.rule);

  void _openRuleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      builder: (_) => RuleBuilderView(controller: widget.rule),
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
          ),
        ),
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(left: BorderSide(color: colors.border)),
          ),
          child: RuleBuilderView(controller: widget.rule),
        ),
      ],
    );
  }

  /// モバイル: リスト全面 + 下部の「ルールを編集」でボトムシートを開く。
  Widget _buildNarrow(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FileListView(
            controller: widget.fileList,
            renameExecution: widget.renameExecution,
          ),
        ),
        Material(
          color: colors.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _openRuleSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('ルールを編集'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
