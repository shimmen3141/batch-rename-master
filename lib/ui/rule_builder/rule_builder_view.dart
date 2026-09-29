import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';
import '../theme/token_colors.dart';
import 'rule_controller.dart';
import 'token_editors.dart';
import 'token_presets.dart';

/// トークンビルダーの描画層(003 spec の VER-002 対象)。
///
/// [RuleController] を購読して描画するだけの薄いウィジェット。トークンを Chip
/// として横並び表示し、5 種の追加ボタン・各 Chip の削除・ドラッグ並び替えを
/// controller のメソッドへ委譲する。追加と Chip タップはエディタを開き、**確定した
/// ときだけ** controller を変える(003 REQ-008〜REQ-011)。面と文字の色は 002 の
/// [AppColors] を再利用し、チップの種類ごとの色は `tokenHue`(008:T45)を使う。
class RuleBuilderView extends StatelessWidget {
  const RuleBuilderView({
    super.key,
    required this.controller,
    this.onEditToken,
    this.itemCount,
    this.sampleFile,
    this.sampleListenable,
  });

  final RuleController controller;

  /// 一覧の件数を返す。連番のエディタが桁数の下限に使う(003 REQ-014)。
  /// エディタを開くときに読むので、件数の変化に追随する。省略時は0件。
  final int Function()? itemCount;

  /// 一覧の1件目を返す。日時のエディタが表示例に使う(008:T44)。無ければ null。
  final FileEntry? Function()? sampleFile;

  /// 一覧の1件目が変わったことを知らせるもの(一覧の controller)。チップの値を
  /// 描き直すのに使う(008:T45)。無ければルールの変化でだけ描き直す。
  final Listenable? sampleListenable;

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
    final edited = await showTokenEditor(
      context,
      controller.tokens[index],
      itemCount: itemCount?.call() ?? 0,
      sampleFile: sampleFile?.call(),
    );
    if (edited != null) controller.replaceAt(index, edited);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      // チップの値は一覧の1件目で描く(008:T45)ので、一覧の変化でも描き直す。
      listenable: Listenable.merge([controller, ?sampleListenable]),
      builder: (context, _) {
        final tokens = controller.tokens;
        final sample = sampleFile?.call();
        return Container(
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 並べ替えの案内は枠の外、見出しの下の線と枠の間に置く(manual 1回目の
              // 開発者の要望)。チップが無いときは同じ高さの空きだけ残す。
              SizedBox(
                key: tokenReorderHintKey,
                height: 44,
                child: tokens.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: Text(
                          tokenReorderHint,
                          maxLines: 2,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: Container(
                    key: tokenFrameKey,
                    color: colors.background,
                    height: 76,
                    child: tokens.isEmpty
                        ? _EmptyHint(colors: colors)
                        : ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            itemCount: tokens.length,
                            onReorderItem: controller.reorder,
                            itemBuilder: (context, index) {
                              // 操作は index ベース(controller も index 規約)。
                              // トークンは重複しうる const 値のため index を key にする。
                              return TokenChip(
                                key: ValueKey('token-$index'),
                                index: index,
                                token: tokens[index],
                                sample: sample,
                                onDelete: () => controller.removeAt(index),
                                onTap: () => _editAt(context, index),
                              );
                            },
                          ),
                  ),
                ),
              ),
              _AddBar(
                controller: controller,
                itemCount: itemCount,
                sampleFile: sampleFile,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// トークンを並べる点線の枠の key(008:T45)。
const Key tokenFrameKey = Key('token-frame');

/// 並べ替えの案内の置き場の key(008:T45)。
const Key tokenReorderHintKey = Key('token-reorder-hint');

/// 並べ替えの案内(manual 1回目の開発者の指定)。
const String tokenReorderHint = 'チップを押すと各設定が開けます。チップを長押ししてドラッグすると並び替えられます。';

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        '↓ 下のボタンから要素を追加',
        style: TextStyle(color: colors.textDisabled, fontSize: 11),
      ),
    );
  }
}

/// 点線の枠(参考デザインの `border: 1px dashed`)。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    void line(Offset from, Offset to) {
      final length = (to - from).distance;
      final dir = (to - from) / length;
      for (var d = 0.0; d < length; d += dash + gap) {
        final end = d + dash < length ? d + dash : length;
        canvas.drawLine(from + dir * d, from + dir * end, paint);
      }
    }

    final r = Offset.zero & size;
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// トークン1個のチップ(参考デザイン。008:T45)。
///
/// 種類ごとの色の面に、上段は小さな種類名と削除、下段は一覧の1件目で描いた値を
/// 大きく出す。**タップで設定、長押しして動かすと並べ替え**(横スクロールの枠の中
/// なので、押してすぐのドラッグはスクロールに使う)。[description] は従来のチップ
/// の文言(`連番(2桁)` など)で、読み上げと test が同じトークンを指すのに使う。
class TokenChip extends StatelessWidget {
  const TokenChip({
    super.key,
    required this.index,
    required this.token,
    required this.sample,
    required this.onDelete,
    required this.onTap,
  });

  final int index;
  final Token token;

  /// 値を描く一覧の1件目。無ければ null。
  final FileEntry? sample;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  /// トークンの説明(`連番(2桁)`・`日時 YYYYMMDD` など。[tokenLabel])。
  String get description => tokenLabel(token);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hue = tokenHue(token);
    // チップの面の見え方(枠の暗い面に種類の色を薄く敷いた色)。削除の円の中も
    // 同じ色にする(manual 1回目の開発者の要望)。
    final face = Color.alphaBlend(
      hue.withValues(alpha: 0.10),
      colors.background,
    );
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          label: description,
          button: true,
          child: Stack(
            children: [
              // 削除の円がチップから少しはみ出すよう、チップの上と右に円のはみ出し
              // ぶんの余白を持たせる(manual 2回目の開発者の要望)。余白は Stack の
              // 内側なので、はみ出した部分も押せる。
              Padding(
                padding: const EdgeInsets.only(
                  top: tokenChipDeleteOverhang,
                  right: tokenChipDeleteOverhang,
                ),
                child: Material(
                  color: face,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: hue.withValues(alpha: 0.35)),
                  ),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 上段: 種別名を左寄せ。右は削除の円のぶん空ける。
                            SizedBox(
                              height: tokenChipDeleteSize,
                              child: Row(
                                children: [
                                  Text(
                                    tokenKindLabel(token),
                                    style: TextStyle(
                                      color: hue.withValues(alpha: 0.85),
                                      fontSize: 9,
                                    ),
                                  ),
                                  const SizedBox(width: tokenChipDeleteSize),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 132),
                              child: Text(
                                tokenChipValue(token, sample),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 削除は右上の円。チップの上辺と右辺に重なり、少しはみ出す。
              Positioned(
                top: 0,
                right: 0,
                child: _DeleteCircle(
                  accent: hue,
                  face: face,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// チップの削除の円の直径(008:T45)。×の大きさは変えず、押せる範囲を円のぶん広げる。
const double tokenChipDeleteSize = 22;

/// 削除の円がチップの上辺・右辺からはみ出す量(008:T45。manual 2回目の開発者の要望)。
const double tokenChipDeleteOverhang = 5;

/// チップの削除(円の中に×)。円の縁と×はチップの色、円の中はチップの面の色。
class _DeleteCircle extends StatelessWidget {
  const _DeleteCircle({
    required this.accent,
    required this.face,
    required this.onPressed,
  });

  final Color accent;
  final Color face;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '削除',
      child: Material(
        key: tokenChipDeleteKey,
        color: face,
        shape: CircleBorder(side: BorderSide(color: accent)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: tokenChipDeleteSize,
            height: tokenChipDeleteSize,
            child: Icon(Icons.close, size: 12, color: accent),
          ),
        ),
      ),
    );
  }
}

/// チップの削除の円の key(008:T45)。
const Key tokenChipDeleteKey = Key('token-chip-delete');

/// 5 種のトークン追加ボタン列。
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.controller,
    required this.itemCount,
    required this.sampleFile,
  });

  final RuleController controller;
  final int Function()? itemCount;
  final FileEntry? Function()? sampleFile;

  /// [kind] を追加する。設定項目を持つ種別はエディタを開き、確定したときだけ
  /// 末尾へ入れる(003 REQ-008 / REQ-009)。元の名前はエディタを開かない(REQ-010)。
  Future<void> _add(BuildContext context, TokenKind kind) async {
    final initial = initialTokenFor(kind);
    if (kind == TokenKind.originalName) {
      controller.addToken(initial);
      return;
    }
    final confirmed = await showTokenEditor(
      context,
      initial,
      confirmLabel: '追加',
      itemCount: itemCount?.call() ?? 0,
      sampleFile: sampleFile?.call(),
      literalEntry: kind == TokenKind.separator
          ? LiteralEntry.separator
          : LiteralEntry.freeText,
    );
    if (confirmed != null) controller.addToken(confirmed);
  }

  static const List<(TokenKind, String)> _buttons = [
    (TokenKind.originalName, '＋ 元の名前'),
    (TokenKind.freeText, '＋ 自由テキスト'),
    (TokenKind.separator, '＋ 区切り'),
    (TokenKind.sequence, '＋ 連番'),
    (TokenKind.dateTime, '＋ 日時'),
  ];

  @override
  Widget build(BuildContext context) {
    // 参考デザイン: 点線の枠のすぐ下に、区切り線なしで並べる(008:T45)。
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (kind, label) in _buttons)
            _AddButton(label: label, onTap: () => _add(context, kind)),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  /// 参考デザイン: 枠線だけの控えめなボタン(008:T45)。
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
