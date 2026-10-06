import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// リネーム画面へ戻る帯(`015:T01`)。
const Key returnToRenameBandKey = Key('return-to-rename-band');

/// 帯の「リネーム画面へ戻る」。
const Key returnToRenameButtonKey = Key('return-to-rename');

/// 帯の高さ(status bar を除く)。
const double returnBandHeight = 40;

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
/// しっかり区別する) — アクセント色を薄く敷き、下端にアクセント色の線を引く。
class _ReturnBand extends StatelessWidget {
  const _ReturnBand({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: returnToRenameBandKey,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.18),
          colors.background,
        ),
        border: Border(
          bottom: BorderSide(color: colors.primary.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: returnBandHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: returnToRenameButtonKey,
              onPressed: onReturn,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text(
                returnToRenameLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
