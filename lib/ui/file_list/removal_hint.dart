import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'header_metrics.dart';

/// 除去のための選択モード中に、外すアイコンへ向けて出す補足(`008:T30`)。
const Key removalHintKey = Key('removal-hint');

/// 吹き出しのツノ。**位置を実測で確かめるための的**でもある。
const Key removalHintTailKey = Key('removal-hint-tail');

/// 吹き出しの閉じる操作(`008:T30` の2回目の実機確認)。
const Key removalHintCloseKey = Key('removal-hint-close');

/// 吹き出しの文言(2026-09-19 の要望)。
///
/// **後半(実ファイルは消えない)を落とさない。** 外すのは rename の一覧からで、
/// ファイルそのものには触れない — 005 / 013 が守っている境界そのものである。
/// `008:T03` が「すべて外す」を「一覧を空にする」へ改名したのも同じ取り違えを
/// 避けるためだった。
///
/// **2回目の実機確認で受領した原文のままである。** 1回目は帯の中へ収めていたので
/// 2行に縮めていたが、**帯へ重ねる形にして高さの制約が消えた**ので戻した。
const String removalHintText = '押すとリネームリストから外されます。\nファイルは削除されません。';

/// 吹き出しが出ている時間。これを過ぎるとフェードアウトする。
const Duration removalHintLifetime = Duration(seconds: 3);

/// フェードアウトにかける時間。
const Duration removalHintFadeOut = Duration(milliseconds: 400);

/// 吹き出しの幅の上限。
const double removalHintMaxWidth = 232;

/// ツノの底辺と高さ。
const double removalHintTailWidth = 14;
const double removalHintTailHeight = 8;

/// 閉じる操作の円の直径。
const double removalHintCloseDiameter = 22;

/// 吹き出し全体の右端を、外すアイコンの右端からどれだけ右へ置くか。
///
/// ケバブの枠だけ右へ出すと、吹き出しの右端が画面の余白(ヘッダの padding)に揃う。
/// **「吹き出し全体」には角へ引っかけた閉じる操作の円まで含む** — 円は箱の外へ
/// はみ出すが、**枠の外へは出さない**。枠の外へ出すと、`Stack` が自分の大きさの外を
/// hit test しないので**押せない円**になる。
const double removalHintRightOffset = headerMenuExtent;

/// 吹き出し全体の右端から**ツノの中心**までの距離。
///
/// **合っているかは widget test が実測で確かめる**(ツノの中心 == アイコンの中心)ので、
/// ここの数が実体とずれたら落ちる。
const double removalHintTailInsetFromRight =
    removalHintRightOffset + headerIconExtent / 2;

/// 外すアイコンの上に**重ねて**出す補足。
///
/// **帯の中には置かない**(2026-09-19 の2回目の実機確認)。帯の中だと
/// ツノがアイコンから遠く、帯の高さや場所の取り分にも影響した。`Overlay` へ出すことで
/// 帯をまたいで重なり、**位置は [LayerLink] がアイコンから直に決める**。
class RemovalHintAnchor extends StatefulWidget {
  const RemovalHintAnchor({
    super.key,
    required this.link,
    required this.visible,
  });

  /// 外すアイコン側の [CompositedTransformTarget] と結ぶ。
  final LayerLink link;

  /// 選択モードに入っているか。**`false` になった瞬間に消える**(フェードしない)。
  final bool visible;

  @override
  State<RemovalHintAnchor> createState() => _RemovalHintAnchorState();
}

class _RemovalHintAnchorState extends State<RemovalHintAnchor>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _entry;
  Timer? _timer;

  /// アイコンの**下**へ出しているか(上に収まらなかったとき)。
  bool _below = false;

  /// 出した吹き出しの大きさを測るための鍵。
  final GlobalKey _bubbleKey = GlobalKey();

  /// **`late final ... = ` の遅延初期化にしない。** 一度も触れないまま dispose すると
  /// そこで初めて作られ、`TickerMode` を deactivated な木から探して落ちる。
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: removalHintFadeOut,
      value: 1,
    );
    if (widget.visible) _schedule();
  }

  @override
  void didUpdateWidget(RemovalHintAnchor old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    if (widget.visible) {
      _schedule();
    } else {
      // **モードをやめたらその瞬間に消える**(要望)。フェードは時間切れのときだけ。
      _remove();
    }
  }

  /// 出してから [removalHintLifetime] 後にフェードアウトさせる。
  void _schedule() {
    _fade.value = 1;
    _timer?.cancel();
    _timer = Timer(removalHintLifetime, () {
      if (!mounted) return;
      _fade.reverse().then((_) {
        if (mounted) _remove();
      });
    });
    _below = false;
    // **build の最中に `Overlay` を触らない。** frame の後へ回す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visible || _entry != null) return;
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return;
      _entry = OverlayEntry(builder: _build);
      overlay.insert(_entry!);
      // 出した直後の大きさが分かってから、上に収まるかを確かめる。
      WidgetsBinding.instance.addPostFrameCallback((_) => _flipIfClipped());
    });
  }

  /// **上に収まらなければアイコンの下へ回す**(独立review attempt 2 の P1)。
  ///
  /// 吹き出しの高さは文字倍率で伸びる。上へ伸ばし続けると、倍率2.0で閉じる操作が、
  /// 倍率3.0では**本文ごと画面の外へ出て**、誤解を防ぐための注記が最大倍率で
  /// 消えてしまう。**上端に収まらないと分かったら、ツノを上に向けて下へ出す。**
  ///
  /// 高さは出してみるまで分からないので、**1 frame 後に測って向きを決める**。
  void _flipIfClipped() {
    if (!mounted || _below || _entry == null) return;
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    // 端末の status bar の下までを安全な範囲とする(`Overlay` は AppBar より前に
    // 描かれるので、AppBar への重なりは許す)。
    final safeTop = MediaQuery.paddingOf(context).top;
    if (top >= safeTop) return;
    _below = true;
    _entry!.markNeedsBuild();
  }

  void _remove() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  Widget _build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    child: CompositedTransformFollower(
      link: widget.link,
      // **アイコンの右上へ吹き出しの右下を合わせる。** 右へ `headerMenuExtent` ずらすと
      // 吹き出しの右端がケバブの右端(= 画面の端から同じ余白)に揃う。
      // **上に収まらないときは上下を入れ替える**(下へ出してツノを上に向ける)。
      targetAnchor: _below ? Alignment.bottomRight : Alignment.topRight,
      followerAnchor: _below ? Alignment.topRight : Alignment.bottomRight,
      offset: Offset(removalHintRightOffset, _below ? 2 : -2),
      showWhenUnlinked: false,
      child: FadeTransition(
        opacity: _fade,
        child: _RemovalHintBubble(
          key: _bubbleKey,
          below: _below,
          onClose: _remove,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _remove();
    _fade.dispose();
    super.dispose();
  }

  // 自分自身は何も描かない(中身は `Overlay` にある)。
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 吹き出しの見た目。**面も枠もツノも同じ色で塗る**(2026-09-19 の2回目の実機確認。
/// 原文は「背景は枠線と同じシアンで塗りつぶしてよい(ツノとの境界線を見えなくする)」)。
class _RemovalHintBubble extends StatelessWidget {
  const _RemovalHintBubble({
    super.key,
    required this.onClose,
    required this.below,
  });

  final VoidCallback onClose;

  /// アイコンの**下**へ出しているか。ツノの向きと、箱とツノの並び順が入れ替わる。
  final bool below;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: removalHintMaxWidth),
        child: Stack(
          children: [
            // **円が入るぶんだけ内側へ寄せる。** 円は箱の角からはみ出すが、
            // 吹き出しの枠からは出さない(出すと押せなくなる)。
            Padding(
              padding: EdgeInsets.only(
                top: below ? 0 : removalHintCloseDiameter / 2,
                bottom: below ? removalHintCloseDiameter / 2 : 0,
                right: removalHintCloseDiameter / 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // **下へ出すときは箱とツノを入れ替える**(ツノが上を向く)。
                verticalDirection: below
                    ? VerticalDirection.up
                    : VerticalDirection.down,
                children: [
                  Container(
                    key: removalHintKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      removalHintText,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // ツノは**箱の外**へ出す。右端からの距離で置くので、吹き出しの幅が
                  // 変わってもアイコンとの関係は変わらない。
                  Row(
                    children: [
                      const Spacer(),
                      CustomPaint(
                        key: removalHintTailKey,
                        size: const Size(
                          removalHintTailWidth,
                          removalHintTailHeight,
                        ),
                        painter: RemovalHintTailPainter(
                          fill: colors.primary,
                          pointsUp: below,
                        ),
                      ),
                      // **閉じる操作のぶんの余白は既に引かれている**(この Row は
                      // 右へ寄せた `Padding` の中にある)ので、その分を戻して測る。
                      const SizedBox(
                        width:
                            removalHintTailInsetFromRight -
                            removalHintCloseDiameter / 2 -
                            removalHintTailWidth / 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // **円の中心を箱の右上の角へ置く**(円の1/4が角に重なる。要望)。
            // 下へ出したときも**箱の右上**なので、ツノのぶんだけ下がる。
            Positioned(
              top: below ? removalHintTailHeight : 0,
              right: 0,
              child: InkWell(
                key: removalHintCloseKey,
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: '閉じる',
                  child: Container(
                    width: removalHintCloseDiameter,
                    height: removalHintCloseDiameter,
                    decoration: BoxDecoration(
                      color: colors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.primary, width: 1.5),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ツノ。**箱と同じ色で塗るだけ**で、境界線は引かない
/// (引くと箱との継ぎ目が線になって見える)。
///
/// **公開しているのは向きを test から読むためである**(どちらを向いているかは
/// 利用者に見える性質で、描いた結果からは読み取れない)。
class RemovalHintTailPainter extends CustomPainter {
  const RemovalHintTailPainter({required this.fill, required this.pointsUp});

  final Color fill;

  /// 上を向くか(吹き出しをアイコンの下へ出したとき)。
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = pointsUp
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(RemovalHintTailPainter old) =>
      old.fill != fill || old.pointsUp != pointsUp;
}
