import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 通知の重大度(`008:T25`)。**見せ方は先頭のアイコンと左端の色帯**で、面の色は変えない。
///
/// 色だけに頼らない — アイコンの形でも区別できるようにする。
enum ToastTone { success, info, danger }

/// 通知の右上の「閉じる」(`008:T25`)。すべての通知に出る。
const Key toastCloseKey = Key('toast-close');

/// 通知とフッターのあいだの隙間。
const double toastGapAboveFooter = 8;

/// 通知の面。**一覧の行([AppColors.surfaceElevated])より一段明るくする** — 同じ色だと
/// 暗い背景と行に埋もれて見づらかった(2026-09-28 のエミュレータ確認。design 土台の
/// トーンに寄せる)。
const Color toastSurface = Color(0xFF262C36);

/// 通知の枠線(白16%)。
const Color toastBorder = Color(0x29FFFFFF);

/// **通知の置き場**(`008:T25`)。一覧とフッター(ルール設定とリネームのbutton)を含む
/// 領域を包み、通知を**フッターの少し上・この領域の幅の中**に出す。
///
/// 内側に専用の [ScaffoldMessenger] と [Scaffold] を持ち、フッターをその
/// `bottomNavigationBar` にする。**浮いた通知をフッターの上へ置くのは Scaffold 自身の
/// 配置**なので、表示中にフッターの高さが変わっても毎 frame 追随する。通知はこの領域の
/// 幅に収まり、desktop の2ペインでも右ペインを覆わない(独立review attempt 2 の P1 2件)。
///
/// **画面にある置き場は [showAppToast] が優先して使う。** 置き場の外(画面上部の
/// 読み込みバーなど)から出した通知も、フッターに重ならないようここへ送る。
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.body, this.footer});

  final Widget body;

  /// 通知をその上に出すフッター。`null`(除去の選択モードなど)なら通知は領域の下端近く。
  final Widget? footer;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

/// 画面にある置き場。後から出来たものを優先する(通常は1つ)。
final List<_ToastHostState> _hosts = [];

class _ToastHostState extends State<ToastHost> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  ScaffoldMessengerState? get _messenger => _messengerKey.currentState;

  bool get _hasFooter => widget.footer != null;

  @override
  void initState() {
    super.initState();
    _hosts.add(this);
  }

  @override
  void dispose() {
    _hosts.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    key: _messengerKey,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      // 外側の Scaffold が入力欄の扱いを持つ。ここでは本文を縮めない。
      resizeToAvoidBottomInset: false,
      body: widget.body,
      bottomNavigationBar: widget.footer,
    ),
  );
}

/// 通知の本文側に置く操作(「元に戻す」など)。
class ToastAction {
  const ToastAction({
    required this.label,
    required this.onPressed,
    this.key,
    this.expiresAfter,
  });

  final String label;
  final VoidCallback onPressed;

  /// 操作が押せる期間。過ぎたら**通知は残したまま操作だけを消す**(`008:T14`)。
  ///
  /// 閉じるまで残る通知([showAppToast] の `persist`)に期限のある操作(改名の
  /// 「元に戻す」は5秒)を載せるとき、押しても何も起きない操作を残さないためである。
  /// `null` なら通知が出ている間ずっと押せる。
  final Duration? expiresAfter;

  /// 操作の button に付ける key(test と既存の観測点のため)。
  final Key? key;
}

/// **通知を出す唯一の入口**(`008:T25`)。
///
/// 見た目は design 土台(`docs/design/Bulk Renamer.html` の toast)に寄せる: 下から浮いた
/// 暗いカード、先頭のアイコン、本文、本文側の操作。**右上に閉じる円**を足した。
///
/// **何を伝えるか・いつ出すか・どれくらいで消えるかは呼び出し側が決める**
/// (004 REQ-008/011/012、002 REQ-017、005 REQ-007/024/027 など)。ここは形だけを持つ。
///
/// [replaceCurrent] が `true` なら、出ている通知を先に下げる(取り消しの結果など、
/// 前の通知を置き換える場面)。
///
/// **エラー([ToastTone.danger])は既定で閉じるまで残る**(2026-09-28 の開発者の決定)。
/// 読み落とすと何が起きたか分からないためである。それ以外は [duration] で消える。
/// [persist] を渡すとこの既定を上書きする — 期限のある操作(改名の「元に戻す」は5秒)を
/// 持つ通知は、押せなくなった操作を残さないよう `false` にする。
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  ScaffoldMessengerState messenger, {
  Key? key,
  required Widget content,
  required ToastTone tone,
  ToastAction? action,
  Duration duration = const Duration(milliseconds: 4000),
  bool replaceCurrent = false,
  bool? persist,
}) {
  // **画面に置き場があればそこへ出す**(フッターの少し上、領域の幅の中)。
  final host = _hosts.isEmpty ? null : _hosts.last;
  final target = host?._messenger ?? messenger;
  final aboveFooter = host != null && host._hasFooter;
  if (replaceCurrent) {
    target.hideCurrentSnackBar();
    // 呼び出し側の messenger に前の通知が残っていれば、それも下げる。
    if (!identical(target, messenger)) messenger.hideCurrentSnackBar();
  }
  return target.showSnackBar(
    SnackBar(
      key: key,
      behavior: SnackBarBehavior.floating,
      // **SnackBar 自身は透明にし、カードは [AppToastCard] が描く。** SnackBar の面に
      // 描くと、右上の円をカードの角へ重ねられない。
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      // 左右14(design 土台)。右と上は閉じる円のための余白を [AppToastCard] が持つ。
      // **下はフッターとの隙間**(フッターの上へ置くのは [ToastHost] の Scaffold)。
      // フッターが無ければ design 土台の18。
      margin: EdgeInsets.fromLTRB(
        14,
        0,
        14 - AppToastCard.closeOverhang,
        aboveFooter ? toastGapAboveFooter : 18,
      ),
      duration: duration,
      persist: persist ?? tone == ToastTone.danger,
      content: _ExpiringToastCard(
        tone: tone,
        action: action,
        onClose: () =>
            target.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
        onAction: action == null
            ? null
            : () {
                // 押したら通知を下げてから操作する(押せる操作を残さない)。
                target.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                action.onPressed();
              },
        child: content,
      ),
    ),
  );
}

/// [ToastAction.expiresAfter] を過ぎたら操作を外す [AppToastCard](`008:T14`)。
class _ExpiringToastCard extends StatefulWidget {
  const _ExpiringToastCard({
    required this.tone,
    required this.child,
    required this.onClose,
    this.action,
    this.onAction,
  });

  final ToastTone tone;
  final Widget child;
  final VoidCallback onClose;
  final ToastAction? action;
  final VoidCallback? onAction;

  @override
  State<_ExpiringToastCard> createState() => _ExpiringToastCardState();
}

class _ExpiringToastCardState extends State<_ExpiringToastCard> {
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    final expiresAfter = widget.action?.expiresAfter;
    if (expiresAfter != null) {
      _timer = Timer(expiresAfter, () {
        if (mounted) setState(() => _expired = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppToastCard(
    tone: widget.tone,
    onClose: widget.onClose,
    action: _expired ? null : widget.action,
    onAction: _expired ? null : widget.onAction,
    child: widget.child,
  );
}

/// 通知のカード(`008:T25`)。[showAppToast] の外では使わない。
class AppToastCard extends StatelessWidget {
  const AppToastCard({
    super.key,
    required this.tone,
    required this.child,
    required this.onClose,
    this.action,
    this.onAction,
  });

  final ToastTone tone;
  final Widget child;
  final VoidCallback onClose;
  final ToastAction? action;
  final VoidCallback? onAction;

  /// 閉じる円がカードの角からはみ出す量。**この分の余白をカードの外に取る** —
  /// 親の範囲の外は押せないので、はみ出した部分も当たり判定に入れるためである。
  static const double closeOverhang = 14;

  /// 閉じる円の当たり判定の一辺。
  static const double closeHitExtent = 32;

  /// 操作があるときのカードの右の余白。閉じる円の当たり判定がカードの内側へ入る
  /// 幅([closeHitExtent] - [closeOverhang])より広く取る。
  static const double actionClearance = closeHitExtent - closeOverhang + 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toneColor = switch (tone) {
      ToastTone.success => colors.success,
      ToastTone.info => colors.info,
      ToastTone.danger => colors.danger,
    };
    final toneIcon = switch (tone) {
      ToastTone.success => Icons.check,
      ToastTone.info => Icons.info_outline,
      ToastTone.danger => Icons.error_outline,
    };
    final action = this.action;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: closeOverhang,
            right: closeOverhang,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            // **枠線は面の上に描く**(design 土台の `border:1px solid`)。背面に描くと
            // 不透明な面に隠れて見えなかった(2026-09-28 のエミュレータ確認)。
            child: DecoratedBox(
              key: toastBorderKey,
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: toastBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: ColoredBox(
                  color: toastSurface,
                  // **左端の色帯は重ねて描く。** 角丸の枠線は四辺同じ色しか持てない。
                  child: Stack(
                    children: [
                      Padding(
                        // **操作があるときは右を空ける**: 閉じる円の当たり判定(角から
                        // [closeHitExtent] 四方)と「元に戻す」を重ねない — 押し間違いで
                        // 取り消しを失わないため(`008:T25`)。
                        padding: EdgeInsets.fromLTRB(
                          15,
                          13,
                          action == null ? 13 : actionClearance,
                          13,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              key: toastToneIconKey(tone),
                              toneIcon,
                              size: 18,
                              color: toneColor,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: AppFontSize.body,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                child: child,
                              ),
                            ),
                            if (action != null) ...[
                              const SizedBox(width: 11),
                              TextButton(
                                key: action.key,
                                onPressed: onAction,
                                style: TextButton.styleFrom(
                                  backgroundColor: colors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  foregroundColor: colors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: AppFontSize.label,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(action.label),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: ColoredBox(
                          key: toastToneBandKey,
                          color: toneColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // **右上の閉じる円は、カードの角へ一部重なる**(2026-09-18 の要望)。
        Positioned(
          top: 0,
          right: 0,
          width: closeHitExtent,
          height: closeHitExtent,
          child: Tooltip(
            message: '通知を閉じる',
            child: InkResponse(
              key: toastCloseKey,
              onTap: onClose,
              radius: closeHitExtent / 2,
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 重大度のアイコン。test が重大度を見るための key。
Key toastToneIconKey(ToastTone tone) => Key('toast-tone-${tone.name}');

/// 通知の枠線(面の上に描く)。
const Key toastBorderKey = Key('toast-border');

/// 左端の色帯。
const Key toastToneBandKey = Key('toast-tone-band');
