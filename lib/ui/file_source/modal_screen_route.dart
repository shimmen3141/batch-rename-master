import 'package:flutter/material.dart';

/// リネーム画面から開く選択画面(app 内 browser・写真・動画の選択画面)の route。
///
/// **下からせり上がって開き、閉じると下へ下がる**(2026-10-07 の開発者の決定。
/// `015:T04`)。別の画面へ移るのではなく、リネーム画面の上に一時的に重なり、
/// 「確定」か「キャンセル」で元へ戻る画面だと動きで分かるようにする。
///
/// - 画面は**全画面のまま**にする。一部だけを覆うボトムシートや、下へ払って閉じる操作は
///   入れない — 一覧のスクロール・なぞって選ぶ操作と重なり、選んだものを誤って捨てうる。
/// - 閉じ方(「キャンセル」「確定」・Android のシステムバック)によらず同じ動きで下がる。
/// - **下のリネーム画面は動かさない**(`fullscreenDialog` にすると、下の
///   [MaterialPageRoute] が自分の退場の動きを止める)。2つの画面とも header の
///   leading を自分で描く(`automaticallyImplyLeading: false`)ので、`fullscreenDialog`
///   で header に × が出ることは無い。
/// - 端末で「アニメーションを削除」が有効なら、動かさずに出し入れする。
class ModalScreenRoute<T> extends MaterialPageRoute<T> {
  ModalScreenRoute({required super.builder}) : super(fullscreenDialog: true);

  /// 開くときの長さ。
  static const Duration enterDuration = Duration(milliseconds: 300);

  /// 閉じるときの長さ。開くときより少し短くする。
  static const Duration exitDuration = Duration(milliseconds: 250);

  @override
  Duration get transitionDuration => enterDuration;

  @override
  Duration get reverseTransitionDuration => exitDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    // 開くときは出だしが速く終わりがゆっくり。閉じるときは同じ curve を逆に辿るので、
    // ゆっくり動き出して速く下がる。
    return SlideTransition(
      position: animation
          .drive(CurveTween(curve: Curves.easeOutCubic))
          .drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
      child: child,
    );
  }
}
