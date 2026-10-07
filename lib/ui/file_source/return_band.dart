import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// リネーム画面へ戻る帯(`015:T01`)。
const Key returnToRenameBandKey = Key('return-to-rename-band');

/// 帯の「リネーム画面へ戻る」。
const Key returnToRenameButtonKey = Key('return-to-rename');

/// 帯の高さ(status bar を除く)。button の押せる高さ(48)に上下 4 を足す。
const double returnBandHeight = 56;

/// 帯の文言(2026-10-06 の開発者の決定。**矢印を付けない** — header の `←` は
/// 「上のフォルダへ」のまま残すので、`←` が2つの意味を持たないようにする)。
const String returnToRenameLabel = 'リネーム画面へ戻る';

/// header([appBar])の**上に**、リネーム画面へ戻る帯を重ねた app bar(`015:T01`)。
///
/// リネーム画面で別の画面へ移る「別フォルダへ」は上部の帯にある。開いた画面から
/// 戻る操作も上部で見つかるよう、いちばん上に置く(2026-10-05 の開発者の決定 案A)。
/// browser と写真・動画の選択画面が**同じ部品**を使い、片方だけ変わらないようにする。
///
/// [appBar] は `primary: false` で渡す — status bar の分は帯が避ける。
class ReturnBandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReturnBandAppBar({
    super.key,
    required this.appBar,
    required this.onReturn,
  });

  final AppBar appBar;

  /// 押したとき。呼ぶ側が「決定していない」で閉じる(004 REQ-008)。
  final VoidCallback onReturn;

  @override
  Size get preferredSize =>
      Size.fromHeight(returnBandHeight + appBar.preferredSize.height);

  @override
  Widget build(BuildContext context) {
    assert(!appBar.primary, 'status bar は帯が避けるので appBar は primary: false にする');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReturnBand(onReturn: onReturn),
        appBar,
      ],
    );
  }
}

/// 帯そのもの。**header と色で見分けられる**ようにする(開発者の決定: 帯は色などで
/// しっかり区別する)。
///
/// 2026-10-07 のエミュレータ確認で開発者が見た目を決めた:
/// - 帯の色は **header(`colors.bar`)より一段薄い [AppColors.barLight]**。シアンを
///   薄く敷いた初めの案は違和感があった。
/// - button は **footer にあった「← リネーム画面へ」の形をそのまま**(背景色の地に
///   アクセント色の枠と文字)。文言は「リネーム画面へ戻る」のまま、矢印は付けない。
class _ReturnBand extends StatelessWidget {
  const _ReturnBand({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: returnToRenameBandKey,
      decoration: BoxDecoration(
        color: colors.barLight,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: returnBandHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: returnToRenameButtonKey,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.background,
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                ),
                onPressed: onReturn,
                child: const Text(
                  returnToRenameLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
