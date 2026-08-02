import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'rule_controller.dart';
import 'token_editors.dart';
import 'token_presets.dart';

/// トークンビルダーの描画層(003 spec の VER-002 対象)。
///
/// [RuleController] を購読して描画するだけの薄いウィジェット。トークンを Chip
/// として横並び表示し、5 種の追加ボタン・各 Chip の削除・ドラッグ並び替えを
/// controller のメソッドへ委譲する。Chip タップは詳細エディタ([onEditToken])へ
/// つなぐ(エディタ本体は T4)。色は 002 の [AppColors] を再利用する。
class RuleBuilderView extends StatelessWidget {
  const RuleBuilderView({
    super.key,
    required this.controller,
    this.onEditToken,
  });

  final RuleController controller;

  /// Chip タップ時の編集をホスト側で差し替えたい場合に指定する。
  /// 省略時は既定の詳細エディタ([showTokenEditor])を開いて [RuleController]
  /// へ差し替える([replaceAt])。
  final void Function(int index)? onEditToken;

  /// index のトークンを編集する。onEditToken 指定時はそちらへ委譲し、
  /// 省略時は既定エディタを開いて確定結果を replaceAt する（REQ-005）。
  Future<void> _editAt(BuildContext context, int index) async {
    final override = onEditToken;
    if (override != null) {
      override(index);
      return;
    }
    final edited = await showTokenEditor(context, controller.tokens[index]);
    if (edited != null) controller.replaceAt(index, edited);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tokens = controller.tokens;
        return Container(
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: tokens.isEmpty
                    ? _EmptyHint(colors: colors)
                    : ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: tokens.length,
                        onReorderItem: controller.reorder,
                        itemBuilder: (context, index) {
                          // 操作は index ベース(controller も index 規約)。
                          // トークンは重複しうる const 値のため index を key にする。
                          return _TokenChip(
                            key: ValueKey('token-$index'),
                            index: index,
                            label: tokenLabel(tokens[index]),
                            onDelete: () => controller.removeAt(index),
                            onTap: () => _editAt(context, index),
                          );
                        },
                      ),
              ),
              _AddBar(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '↓ 下のボタンから要素を追加',
        style: TextStyle(color: colors.textMuted, fontSize: 12),
      ),
    );
  }
}

/// トークン1個の Chip(ラベル + 削除 + ドラッグハンドル)。
class _TokenChip extends StatelessWidget {
  const _TokenChip({
    super.key,
    required this.index,
    required this.label,
    required this.onDelete,
    required this.onTap,
  });

  final int index;
  final String label;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 15),
                  color: colors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: '削除',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 5 種のトークン追加ボタン列。
class _AddBar extends StatelessWidget {
  const _AddBar({required this.controller});

  final RuleController controller;

  static const List<(TokenKind, String)> _buttons = [
    (TokenKind.originalName, '＋ 元の名前'),
    (TokenKind.freeText, '＋ 自由テキスト'),
    (TokenKind.separator, '＋ 区切り'),
    (TokenKind.sequence, '＋ 連番'),
    (TokenKind.dateTime, '＋ 日時'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (kind, label) in _buttons)
            _AddButton(
              label: label,
              onTap: () => controller.addToken(defaultTokenFor(kind)),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
