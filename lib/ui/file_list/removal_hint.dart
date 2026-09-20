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
/// 文と文の間へ明示的な改行を入れず、幅に応じて自然に折り返す(`008:T34`)。
const String removalHintText = '押すとファイルをリネームリストから外します。削除はされません。';

/// 表示開始からフェード完了までの時間。
const Duration removalHintLifetime = Duration(seconds: 7);

/// フェードアウトにかける時間。
const Duration removalHintFadeOut = Duration(milliseconds: 400);

/// フェードを始めるまでの表示時間。
const Duration removalHintVisibleDuration = Duration(milliseconds: 6600);

/// 吹き出しの幅の上限。
///
/// 通常倍率では日本語を約16文字ずつ、自然に2行へ折り返す幅にする。
const double removalHintMaxWidth = 180;

/// ツノの底辺と高さ。
const double removalHintTailWidth = 14;
const double removalHintTailHeight = 8;

/// アイコン枠の中心から、字面の見た目に合わせてツノを左へ寄せる量。
///
/// `Icons.playlist_remove` の字面は 40dp のtap target内で左寄りに見えるため、幾何学的な
/// 中心ではツノが右へずれて見える。右から測る距離を増やすことで、ツノの中心を3dp左へ
/// 補正する(`008:T34`)。
const double removalHintTailVisualInsetFromRight = 3;

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

/// ツノの先端をアイコンへ少し近づける、縦方向の補正(`008:T34`)。
const double removalHintVerticalOffset = 2;

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

  /// 表示開始から [removalHintLifetime] で完全に消えるようにフェードアウトさせる。
  void _schedule() {
    _fade.value = 1;
    _timer?.cancel();
    _timer = Timer(removalHintVisibleDuration, () {
      if (!mounted) return;
      _fade.reverse().then((_) {
        if (mounted) _remove();
      });
    });
    // **測るまでは透明にしておく。** 収まるかどうかは出してみないと分からないので、
    // 判定が済むまで見せない(`_showIfItFits` が 1 へ戻すか、取り下げる)。
    _fade.value = 0;
    // **build の最中に `Overlay` を触らない。** frame の後へ回す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visible || _entry != null) return;
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return;
      _entry = OverlayEntry(builder: _build);
      overlay.insert(_entry!);
      // 出した直後の大きさが分かってから、画面に収まるかを確かめる。
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIfItFits());
    });
  }

  /// **画面に収まらなければ出さない**(2026-09-19 の開発者の判断)。
  ///
  /// 箱の高さは文字倍率で伸びる(幅を固定しているので折り返しが増える)。
  /// 320×800・倍率1.0 で高さ59 のものが、倍率3.0 では **284** になる。
  /// 置き場所を解こうとすると、上へ伸ばせば上端から出て、下へ回せば
  /// **横向きの低い画面で下端から出る**(732×360・倍率3.0 で 132px はみ出した)。
  /// そのとき見えるのは箱の上半分だけで、**切れて消えるのは
  /// 「ファイルは削除されません。」の側**である。
  ///
  /// **半分だけ見せるくらいなら出さない。** 判定は上下左右をまとめて1回だけ行い、
  /// 収まらなければ取り下げる(アイコンの tooltip は残るので、意味への入口は消えない)。
  ///
  /// 大きさは出してみるまで分からないので、**1 frame 後に測る**。それまでは
  /// 透明にしておく(**測る前の位置がちらつかない**)。
  void _showIfItFits() {
    if (!mounted || _entry == null) return;
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final rect = origin & box.size;
    final media = MediaQuery.of(context);
    // **画面の内側。上だけは status bar の下から数える。**
    //
    // `Overlay` は AppBar より前に描かれるので AppBar への重なりは許すが、
    // status bar の下へ潜り込むと本当に読めなくなる。
    //
    // **左右と下の inset は数えない。** この app は画面の端まで使う作りで、
    // ヘッダのケバブも外すアイコンも inset の内側へは寄せていない。ここだけ
    // 厳しくすると、横向き + ジェスチャーナビ(右に 40 程度の inset)の端末で
    // **普通の文字でも一度も出なくなる**(実測で確認した)。
    final safe = Rect.fromLTRB(
      0,
      media.padding.top,
      media.size.width,
      media.size.height,
    );
    if (!safe.contains(rect.topLeft) || !safe.contains(rect.bottomRight)) {
      _remove();
      return;
    }
    _fade.value = 1;
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
      // **置き場所はここ1つだけである**(2026-09-19 の開発者の判断)。収まらない画面では
      // 別の場所を探さず、`_showIfItFits` が取り下げる。
      targetAnchor: Alignment.topRight,
      followerAnchor: Alignment.bottomRight,
      offset: const Offset(removalHintRightOffset, removalHintVerticalOffset),
      showWhenUnlinked: false,
      child: FadeTransition(
        opacity: _fade,
        child: _RemovalHintBubble(key: _bubbleKey, onClose: _remove),
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

/// 吹き出しの見た目。
///
/// 黒い面をシアンの一筆書きの外枠で囲む。箱の下辺をツノの底辺で分断しないので、
/// ツノと箱の継ぎ目に横線が出ない(`008:T34`)。
class _RemovalHintBubble extends StatelessWidget {
  const _RemovalHintBubble({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: removalHintMaxWidth),
        child: Stack(
          children: [
            // **飾りは pointer を取らない。** `Text` は `hitTestSelf` が常に `true` で、
            // 描画範囲のtapを**無条件に吸う**。吹き出しがアイコンの下へ回ると一覧の行に
            // 重なるので、そのままだと**重なった行のcheckboxが押しても反応しない**
            // (独立review attempt 3 の P1。エラーも出ないので気づけない)。
            // 押せる必要があるのは閉じる操作だけなので、そこだけ外に出す。
            IgnorePointer(
              // **円が入るぶんだけ内側へ寄せる。** 円は箱の角からはみ出すが、
              // 吹き出しの枠からは出さない(出すと押せなくなる)。
              child: Padding(
                padding: const EdgeInsets.only(
                  top: removalHintCloseDiameter / 2,
                  right: removalHintCloseDiameter / 2,
                ),
                child: CustomPaint(
                  key: removalHintKey,
                  painter: RemovalHintFramePainter(
                    fill: colors.background,
                    edge: colors.primary,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 7,
                        ),
                        child: Text(
                          removalHintText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.25,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // [RemovalHintFramePainter] が、ここで取る大きさに合わせて
                      // 箱と一体のツノを描く。SizedBox は位置を測るための的だけを置く。
                      Row(
                        children: [
                          const Spacer(),
                          const SizedBox(
                            key: removalHintTailKey,
                            width: removalHintTailWidth,
                            height: removalHintTailHeight,
                          ),
                          // **閉じる操作のぶんの余白は既に引かれている**(この Row は
                          // 右へ寄せた `Padding` の中にある)ので、その分を戻して測る。
                          const SizedBox(
                            width:
                                removalHintTailInsetFromRight +
                                removalHintTailVisualInsetFromRight -
                                removalHintCloseDiameter / 2 -
                                removalHintTailWidth / 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // **円の中心を箱の右上の角へ置く**(円の1/4が角に重なる。要望)。
            Positioned(
              top: 0,
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

/// 箱とツノを連続した一つの外形として描く painter。
///
/// `Container` と三角を別々に枠線で囲むと、接する下辺が二重に見える。このpathはツノの
/// 両辺だけを外形に含めるので、継ぎ目を作らない。
class RemovalHintFramePainter extends CustomPainter {
  const RemovalHintFramePainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final boxBottom = size.height - removalHintTailHeight;
    final radius = 8.0;
    final tailCenter =
        size.width -
        (removalHintTailInsetFromRight +
            removalHintTailVisualInsetFromRight -
            removalHintCloseDiameter / 2);
    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, boxBottom - radius)
      ..quadraticBezierTo(size.width, boxBottom, size.width - radius, boxBottom)
      ..lineTo(tailCenter + removalHintTailWidth / 2, boxBottom)
      ..lineTo(tailCenter, size.height)
      ..lineTo(tailCenter - removalHintTailWidth / 2, boxBottom)
      ..lineTo(radius, boxBottom)
      ..quadraticBezierTo(0, boxBottom, 0, boxBottom - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25,
      );
  }

  @override
  bool shouldRepaint(RemovalHintFramePainter old) =>
      old.fill != fill || old.edge != edge;
}
