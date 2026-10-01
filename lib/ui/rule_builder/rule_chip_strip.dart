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
/// **入りきらないときは折り返さない**(折り返すと button が伸びて一覧を削る。`008:T16` の
/// 独立review attempt 4 が挙げた「ルールの長さ」の変数)。入る分を並べ、**次のチップを
/// 残りの幅で途切れさせてフェードする。それより後ろは出さず、数も出さない**
/// (2026-09-30 の開発者の決定)。以前は右端の「+N」にまとめていたが、ちょうど収まって
/// いたところへ1つ足すと「+1」が入らず「+2」へ飛び、違和感があった。
///
/// **フェードは列の右端まで描き、薄くするのは右端の [ruleChipFadeLength] だけにする**
/// (2026-10-01 の開発者の指定。実機確認4回目)。以前は途切れたチップの幅の 35% から
/// 薄くし始め、手前のチップをフェードにしたときはその右に空きが残ったので、消えるのが
/// 早く見えた。見えなくなる所から `編集` までが、✎ とチップの間と同じくらいになる。
class RuleChipStrip extends StatelessWidget {
  const RuleChipStrip({super.key, required this.rule, required this.sample});

  final RenameRule rule;

  /// 値を描く一覧の1件目。無ければ null。
  final FileEntry? sample;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    final tokens = rule.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = [
          for (final token in tokens)
            _chipWidth(context, base, scaler, token, sample),
        ];
        final layout = _layoutChips(widths, constraints.maxWidth);
        final shown = layout.full;
        final fadeWidth = layout.fadeWidth;
        // フェードの中に描くチップ。途切れたチップと、残りの幅がそれより広いときは
        // その次も(列の右端まで中身を届かせる)。
        final faded = <Token>[
          if (fadeWidth != null) tokens[shown],
          if (fadeWidth != null &&
              shown + 1 < tokens.length &&
              fadeWidth > widths[shown] + ruleChipGap)
            tokens[shown + 1],
        ];
        // **高さはチップ1つ分に固定する。** 以前の「+N」の形では、チップが1つも入らず
        // 「+N」だけになると列が文字の高さまで縮み、button が低くなって一覧の高さが
        // 変わった(`row_presentation_test`「増える高さは 1 行ぶんで止まる」)。フェードの
        // チップは `OverflowBox` で描くので、列の高さを決めておく必要もある。
        return SizedBox(
          height: _chipHeight(context, base, scaler),
          child: Row(
            children: [
              for (var i = 0; i < shown; i++) ...[
                if (i > 0) const SizedBox(width: ruleChipGap),
                RuleSummaryChip(token: tokens[i], sample: sample),
              ],
              if (fadeWidth != null) ...[
                if (shown > 0) const SizedBox(width: ruleChipGap),
                _FadedChip(
                  key: ruleChipFadeKey,
                  width: fadeWidth,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < faded.length; i++) ...[
                        if (i > 0) const SizedBox(width: ruleChipGap),
                        RuleSummaryChip(token: faded[i], sample: sample),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

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
      // チップの幅は種類名と値の広いほう。**値は中央に置く**(種類名のほうが長い
      // 区切り・1文字のテキストで、値が左へ寄っていた。2026-09-30 の開発者の指定)。
      // 設定画面のチップ(`TokenChip`)と同じ配置 — 種類名は左、値は中央。
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tokenKindLabel(token), maxLines: 1, style: _kindStyle(hue)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _valueMaxWidth),
              child: Text(
                tokenChipValue(token, sample),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _valueStyle,
              ),
            ),
          ],
        ),
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

/// チップ1つの高さ(上下の内側の余白 2 + 3、枠 1 + 1、種類名と値の1行ずつ)。
double _chipHeight(BuildContext context, TextStyle base, TextScaler scaler) {
  double lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'あ', style: base.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  return 2 +
      3 +
      2 * _chipBorder +
      lineHeight(_kindStyle(Colors.white)) +
      lineHeight(_valueStyle);
}

/// 途切れさせてフェードしたチップ(`008:T47`)。チップは本来の幅で描き、[width] で
/// 切って、右端の [ruleChipFadeLength] だけを右へ向かって透明にする。
class _FadedChip extends StatelessWidget {
  const _FadedChip({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [Colors.white, Colors.transparent],
            stops: [ruleChipFadeStart(bounds.width), 1],
          ).createShader(bounds),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// フェードしたチップ。
const Key ruleChipFadeKey = Key('rule-chip-fade');

/// 薄くし始める位置(フェードの幅に対する割合)。右端から [ruleChipFadeLength] の所。
double ruleChipFadeStart(double width) =>
    width > ruleChipFadeLength ? 1 - ruleChipFadeLength / width : 0;

/// 右端で薄くする長さ。透明に近い右端の数 px は見えないので、見えなくなる所から
/// `編集` までは、列と `編集` の間(8)より少し広い、✎ とチップの間(11)くらいになる。
const double ruleChipFadeLength = 20;

/// フェードのチップを置く最小の幅。これより狭いと途切れたチップだと読めないので、
/// 1つ手前のチップをフェードにする。
const double ruleChipFadeMinWidth = 24;

/// 並べ方: 全体を出すチップの数と、その次に出すフェードの幅(無ければ null)。
/// フェードの幅は常に列の右端まで(残りの幅)である。
typedef _ChipLayout = ({int full, double? fadeWidth});

_ChipLayout _layoutChips(List<double> widths, double maxWidth) {
  double total(int count) {
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      sum += widths[i] + (i > 0 ? ruleChipGap : 0);
    }
    return sum;
  }

  final n = widths.length;
  if (_fitsAll(total(n), maxWidth)) return (full: n, fadeWidth: null);
  // 入る分を並べ、次のチップ(k 番目)を残りの幅で途切れさせる。残りが下限に
  // 満たなければ1つ手前をフェードにする。手前のチップが丸ごと入る幅でもフェードに
  // する — **続きがあることは常にフェードで示す**(数は出さない)。そのときも
  // フェードは列の右端まで伸ばし、空きを残さない(右に次のチップの端が覗く)。
  for (var k = n - 1; k > 0; k--) {
    final rest = maxWidth - total(k) - ruleChipGap;
    if (rest >= ruleChipFadeMinWidth) {
      return (full: k, fadeWidth: rest);
    }
  }
  return (full: 0, fadeWidth: maxWidth);
}

bool _fitsAll(double total, double maxWidth) => total <= maxWidth;
