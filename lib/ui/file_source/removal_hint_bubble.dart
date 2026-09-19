import 'package:flutter/material.dart';

import '../file_list/header_metrics.dart';
import '../theme/app_colors.dart';

/// 除去のための選択モード中に、外すアイコンへ向けて出す補足(`008:T30`)。
const Key removalHintKey = Key('removal-hint');

/// 吹き出しのツノ。**位置を実測で確かめるための的**でもある。
const Key removalHintTailKey = Key('removal-hint-tail');

/// 吹き出しの文言(2026-09-19 の要望)。
///
/// **後半(実ファイルは消えない)を落とさない。** 外すのは rename の一覧からで、
/// ファイルそのものには触れない — 005 / 013 が守っている境界そのものである。
/// `008:T03` が「すべて外す」を「一覧を空にする」へ改名したのも同じ取り違えを
/// 避けるためだった。
///
/// **受領した原文は「押すとリネームリストから外されます。」だった。** `リネーム` を
/// 落としたのは**2行に収めるため**である — 3行になると吹き出しが `別フォルダへ` の枠より
/// 高くなり、**帯が通常表示でも太る**(吹き出しは高さを揃えるため通常表示でも layout
/// されるので、高いほうが帯の高さを決めてしまう)。何の一覧かはヘッダの `〇件選択中` と
/// アイコンの tooltip(`選んだファイルをリネーム候補から外す`)が示す。
const String removalHintText = '押すと一覧から外れます。\nファイルは削除されません。';

/// 吹き出しの幅の上限。
///
/// **`別フォルダへ` の枠(320dp で約133)より少しだけ広い**。ここを広げると通常表示でも
/// 場所の取り分が減る([RemovalHintBubble] は高さを揃えるために通常表示でも
/// layout され、枠の広いほうが末尾の取り分を決めるため)ので、文言が2行で収まる
/// 最小限に留める。
const double removalHintMaxWidth = 156;

/// ツノの底辺と高さ。
const double removalHintTailWidth = 14;
const double removalHintTailHeight = 7;

/// 読み込み帯の `別フォルダへ` があった場所へ出す吹き出し。
///
/// **ツノは一覧ヘッダの外すアイコンの中心へ向ける。** 帯とヘッダは別の widget なので
/// 位置を測り合わず、[removalHintTailInsetFromRight] という同じ数を使う
/// (合っているかは widget test が実測する)。
///
/// **この widget は通常表示でも layout される**(`IndexedStack`)。帯の高さを
/// モードの出入りで変えないためで、描画と hit test はモード中だけである。
class RemovalHintBubble extends StatelessWidget {
  const RemovalHintBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // **`Align` で包まない。** loose な制約の下では `Align` が使える幅いっぱいまで
    // 広がり、帯の末尾の枠(= 場所の取り分の裏返し)がそのぶん太る。横の位置は
    // `IndexedStack` の `alignment` が決める。
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: removalHintMaxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: removalHintKey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.primary.withValues(alpha: 0.45)),
            ),
            child: Text(
              removalHintText,
              // **`別フォルダへ` の枠(40)より低く収める。** 高いほうが帯の高さを
              // 決めるので、ここが伸びると通常表示の帯も太る。
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ),
          // ツノは**箱の外**へ出す。右端からの距離で置くので、帯の幅が変わっても
          // アイコンとの関係は変わらない。
          Row(
            children: [
              const Spacer(),
              CustomPaint(
                key: removalHintTailKey,
                size: const Size(removalHintTailWidth, removalHintTailHeight),
                painter: _TailPainter(
                  fill: colors.surfaceElevated,
                  edge: colors.primary.withValues(alpha: 0.45),
                ),
              ),
              SizedBox(
                width: removalHintTailInsetFromRight - removalHintTailWidth / 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 下向きのツノ。箱と同じ面の色で塗り、左右の辺だけ枠の色で描く。
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.fill != fill || old.edge != edge;
}
