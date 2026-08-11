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
          child: RuleBuilderView(controller: widget.rule),
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
      onEditRule: _openRuleSheet,
    );
  }
}
