import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// ---------------------------------------------------------------------------
// design 土台のdialogの部品(`008:T14` で作り、`008:T53` で共有へ切り出した)。
//
// 実行前の確認・再採番の結果の詳細・警告の詳細が同じ枠を使う。**形だけを持ち、
// 何を書くかは呼び出し側が決める。**
// ---------------------------------------------------------------------------

/// dialogの外側を暗くする色(design 土台)。
const Color designDialogBarrierColor = Color(0xA8000000);

/// design 土台のdialogの枠(見出しと説明、本文、区切り線の下のbutton列)。
///
/// tokenのエディタ(`008:T44`)と同じ形。**本文だけをscrollさせる** — 件数が多くても
/// 見出しとbuttonは画面に残り、何を選ぶのかを見失わない。
class DesignDialog extends StatelessWidget {
  const DesignDialog({
    super.key,
    required this.title,
    this.description,
    required this.body,
    required this.actions,
  });

  final String title;

  /// 見出しの下の説明。無ければ出さない。
  final String? description;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final description = this.description;
    return Dialog(
      insetPadding: const EdgeInsets.all(26),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppFontSize.titleLarge,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppFontSize.label,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
              child: Row(children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

/// [DesignDialog] の下のbutton。
class DialogButton extends StatelessWidget {
  const DialogButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.bold = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        textStyle: TextStyle(
          fontSize: AppFontSize.body,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

/// 問題の種類1つ分の枠(design 土台の `issues`: 薄い赤の面と枠、⚠、見出し、説明)。
///
/// 見出しと説明の下に [child](対象の並び)を置く。
class IssueCard extends StatelessWidget {
  const IssueCard({
    super.key,
    required this.title,
    required this.description,
    this.descriptionKey,
    this.child,
  });

  final String title;
  final String description;

  /// 説明の [Text] に付ける key(数えるtestのため)。
  final Key? descriptionKey;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = this.child;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: colors.danger,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: AppFontSize.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  key: descriptionKey,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppFontSize.small,
                    height: 1.6,
                  ),
                ),
                if (child != null) ...[const SizedBox(height: 4), child],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
