import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';
import '../theme/token_colors.dart';
import 'token_presets.dart';

/// 下部のルール設定buttonに並べる、設定中のルールのチップ(`008:T47`)。
///
/// **ルール設定画面のチップ([tokenKindLabel] の種類名と、1件目で描いた
/// [tokenChipValue] の値の2段。色は [tokenHue])と同じ見え方にする**
/// (2026-09-30 の開発者の決定)。削除の×は持たず、そのぶん幅を詰める。
/// 押せない(button 全体が一つの押下対象。2026-09-02 の要望9)。
///
/// **入りきらないチップは右端の「+N」にまとめる。** 折り返すと button が伸びて
/// 一覧を削る(`008:T16` の独立review attempt 4 が挙げた「ルールの長さ」の変数)。
class RuleChipStrip extends StatelessWidget {
  const RuleChipStrip({super.key, required this.rule, required this.sample});

  final RenameRule rule;

  /// 値を描く一覧の1件目。無ければ null。
  final FileEntry? sample;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    final tokens = rule.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = [
          for (final token in tokens)
            _chipWidth(context, base, scaler, token, sample),
        ];
        final shown = _fitCount(
          context,
          base,
          scaler,
          widths,
          constraints.maxWidth,
        );
        final hidden = tokens.length - shown;
        return Row(
          children: [
            for (var i = 0; i < shown; i++) ...[
              if (i > 0) const SizedBox(width: ruleChipGap),
              RuleSummaryChip(token: tokens[i], sample: sample),
            ],
            if (hidden > 0) ...[
              if (shown > 0) const SizedBox(width: ruleChipGap),
              Text(
                '+$hidden',
                key: ruleChipOverflowKey,
                style: _overflowStyle(colors),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 入りきらなかったチップの数(`+N`)。
const Key ruleChipOverflowKey = Key('rule-chip-overflow');

/// チップどうしの間。
const double ruleChipGap = 4;

/// チップの横の内側の余白(左右それぞれ)と枠。
const double _chipHorizontalPadding = 7;
const double _chipBorder = 1;

/// 値の最大幅(設定画面のチップと同じ)。
const double _valueMaxWidth = 132;

TextStyle _kindStyle(Color hue) =>
    TextStyle(color: hue.withValues(alpha: 0.85), fontSize: 9);

const TextStyle _valueStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  fontFamily: 'monospace',
);

TextStyle _overflowStyle(AppColors colors) => TextStyle(
  color: colors.textSecondary,
  fontSize: 13,
  fontWeight: FontWeight.w700,
);

/// 1つのチップ。設定画面の [TokenChip] から削除の×と、そのための幅を除いた形。
class RuleSummaryChip extends StatelessWidget {
  const RuleSummaryChip({super.key, required this.token, required this.sample});

  final Token token;
  final FileEntry? sample;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hue = tokenHue(token);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        _chipHorizontalPadding,
        2,
        _chipHorizontalPadding,
        3,
      ),
      decoration: BoxDecoration(
        // 設定画面のチップの面(種類の色を薄く敷いた暗い面)と枠。
        color: Color.alphaBlend(hue.withValues(alpha: 0.10), colors.background),
        border: Border.all(color: hue.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tokenKindLabel(token), maxLines: 1, style: _kindStyle(hue)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _valueMaxWidth),
            child: Text(
              tokenChipValue(token, sample),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

double _textWidth(
  BuildContext context,
  TextStyle base,
  TextScaler scaler,
  String text,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: base.merge(style)),
    textDirection: Directionality.of(context),
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

double _chipWidth(
  BuildContext context,
  TextStyle base,
  TextScaler scaler,
  Token token,
  FileEntry? sample,
) {
  final kind = _textWidth(
    context,
    base,
    scaler,
    tokenKindLabel(token),
    _kindStyle(tokenHue(token)),
  );
  final value = _textWidth(
    context,
    base,
    scaler,
    tokenChipValue(token, sample),
    _valueStyle,
  ).clamp(0.0, _valueMaxWidth);
  return (kind > value ? kind : value) +
      2 * _chipHorizontalPadding +
      2 * _chipBorder;
}

/// [maxWidth] に入るチップの数。全部は入らないときは、`+N` の幅を残して数える。
int _fitCount(
  BuildContext context,
  TextStyle base,
  TextScaler scaler,
  List<double> widths,
  double maxWidth,
) {
  double total(int count) {
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      sum += widths[i] + (i > 0 ? ruleChipGap : 0);
    }
    return sum;
  }

  if (total(widths.length) <= maxWidth) return widths.length;
  for (var count = widths.length - 1; count >= 0; count--) {
    final overflow =
        _textWidth(
          context,
          base,
          scaler,
          '+${widths.length - count}',
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ) +
        (count > 0 ? ruleChipGap : 0);
    if (total(count) + overflow <= maxWidth) return count;
  }
  return 0;
}
