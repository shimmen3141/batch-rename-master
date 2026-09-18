import 'package:flutter/material.dart';

/// 場所の文字列を、**幅に入らないときは先頭を省略して**出す(008:T23)。
///
/// 場所は `保存場所名 + rootからの相対path`(004 REQ-009。
/// `storage_browser_view.dart` の `_displayPathOf`)である。保存場所名だけにする案は
/// **004 の独立review attempt 2 の P2-1 で否定されている** — どのfolderから読み込んでも
/// 同じ表示になるためである。その結果 `Internal shared storage/DCIM/t07-fixtures` のような
/// 長い文字列になり、`Text` の既定の省略は**末尾から削る**ので、実機では
/// `Internal shared st…` と**全folderで共通の接頭辞だけが残った**(2026-09-18 の実機確認)。
///
/// **判別に効くのは末尾**なので、こちらを残す。
class SourcePathText extends StatelessWidget {
  const SourcePathText({
    super.key,
    required this.text,
    required this.style,
    this.textKey,
  });

  /// 出したい場所の文字列。**加工前の値**を渡す(縮めるのはこのwidgetの仕事)。
  final String text;

  /// 文字の体裁。**測るときと描くときで同じものを使う** — 違うと予測が外れる。
  final TextStyle style;

  /// 実際に描く [Text] へ付ける鍵。
  ///
  /// **このwidgetではなく `Text` に付ける。** `RenderParagraph` を見て省略の有無を
  /// 確かめる検査があるので、鍵は段落そのものを指していないと掴めない。
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    // `Text` は `DefaultTextStyle` と混ぜてから描く。**同じものを測らないと予測が外れる**
    // ので、混ぜた結果を両方へ渡す。
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        visibleSourcePathOf(
          text,
          maxWidth: constraints.maxWidth,
          style: effective,
          textScaler: textScaler,
          textDirection: textDirection,
        ),
        key: textKey,
        maxLines: 1,
        // **最後の1 segmentすら入らないときの逃げ道**(下の関数がそこで諦める)。
        overflow: TextOverflow.ellipsis,
        style: effective,
      ),
    );
  }
}

/// 幅 [maxWidth] に**末尾を優先して**収めた表示文を返す(008:T23)。
///
/// - 全体が入るなら**そのまま**返す。
/// - 入らないなら先頭のsegmentを1つずつ落として `…/` を付け、**入る中で最も長いもの**を返す
///   (`…/DCIM/t07-fixtures` が入るなら `…/t07-fixtures` へは落とさない)。
/// - 最後のsegmentだけでも入らないときは、そのsegmentを返す。呼び出し側の
///   `TextOverflow.ellipsis` が末尾を削る — **folder名は頭のほうが判別に効く**ので、
///   ここだけは向きが逆になる。
/// - **`/` を含まない文言は形を変えない**(`未選択` / `複数のフォルダ` など)。
String visibleSourcePathOf(
  String text, {
  required double maxWidth,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) {
  bool fits(String candidate) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    // **`<=` である。** ぴったりの幅を「入らない」と読むと、省略が要らない場面で
    // 先頭を落としてしまう。
    return width <= maxWidth;
  }

  // 幅が決まっていないところでは縮めない(縮める根拠が無い)。
  if (!maxWidth.isFinite) return text;
  if (fits(text)) return text;
  // 空のsegmentは落とす(`a//b` や末尾の `/` で `…/` だけが残るのを避ける)。
  final segments = text.split('/').where((s) => s.isNotEmpty).toList();
  // 落とせる段が無いなら、形を変えずに返す。
  if (segments.length < 2) return text;
  for (var drop = 1; drop < segments.length; drop++) {
    final candidate = '…/${segments.sublist(drop).join('/')}';
    if (fits(candidate)) return candidate;
  }
  return segments.last;
}
