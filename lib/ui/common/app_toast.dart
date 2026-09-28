import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 通知の重大度(`008:T25`)。**見せ方は先頭のアイコンと左端の色帯**で、面の色は変えない。
///
/// 色だけに頼らない — アイコンの形でも区別できるようにする。
enum ToastTone { success, info, danger }

/// 通知の右上の「閉じる」(`008:T25`)。すべての通知に出る。
const Key toastCloseKey = Key('toast-close');

/// 通知の本文側に置く操作(「元に戻す」など)。
class ToastAction {
  const ToastAction({required this.label, required this.onPressed, this.key});

  final String label;
  final VoidCallback onPressed;

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
/// [persist] が `true` なら自動では消えない(閉じる円か操作で消える)。**`SnackBar` に
/// action を渡していた通知はFlutterの既定で残り続けていた**ので、それを保つために使う。
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  ScaffoldMessengerState messenger, {
  Key? key,
  required Widget content,
  required ToastTone tone,
  ToastAction? action,
  Duration duration = const Duration(milliseconds: 4000),
  bool replaceCurrent = false,
  bool persist = false,
}) {
  if (replaceCurrent) messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      key: key,
      behavior: SnackBarBehavior.floating,
      // **SnackBar 自身は透明にし、カードは [AppToastCard] が描く。** SnackBar の面に
      // 描くと、右上の円をカードの角へ重ねられない。
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      // 左右14・下18(design 土台)。右と上は閉じる円のための余白を [AppToastCard] が持つ。
      margin: const EdgeInsets.fromLTRB(
        14,
        0,
        14 - AppToastCard.closeOverhang,
        18,
      ),
      duration: duration,
      persist: persist,
      content: AppToastCard(
        tone: tone,
        action: action,
        onClose: () =>
            messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
        onAction: action == null
            ? null
            : () {
                // 押したら通知を下げてから操作する(押せる操作を残さない)。
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                action.onPressed();
              },
        child: content,
      ),
    ),
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
              border: Border.all(color: const Color(0x1AFFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: ColoredBox(
                color: colors.surfaceElevated,
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
                                fontSize: 12.5,
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
                                  fontSize: 11.5,
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

/// 左端の色帯。
const Key toastToneBandKey = Key('toast-tone-band');
