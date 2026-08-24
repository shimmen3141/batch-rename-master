import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 全ファイルアクセスが無い間、読み込み導線の位置に出す説明と設定導線
/// (013 REQ-001 / REQ-003)。
///
/// **黙らない。** 拒否されたあとも同じ説明と導線を出し続ける(REQ-003)。
/// **設定画面を自動で開かない。** 開くのは利用者が `open-storage-settings` を
/// 押したときだけである。
class StoragePermissionNotice extends StatelessWidget {
  const StoragePermissionNotice({
    super.key,
    required this.onOpenSettings,
    this.settingsUnavailable = false,
  });

  /// 設定画面を開く操作。**利用者の操作からのみ呼ばれる。**
  final Future<void> Function() onOpenSettings;

  /// 直前に設定画面を開けなかったか。開けない端末でも導線は消さない(REQ-003)。
  final bool settingsUnavailable;

  /// なぜこの権限が要るかの説明(013 REQ-001)。
  ///
  /// **「すべてのファイルへのアクセス」は強い権限**なので、求める理由を先に書く。
  /// 名前は端末の設定画面での表記に合わせる(013 spec 用語)。
  static const explanation =
      'ファイルの名前を安全に変更するには、端末の「すべてのファイルへのアクセス」が必要です。'
      'この許可がないと、アプリはファイルの保存場所を特定できず、名前を変更できません。';

  /// 開けなかったときの補足。**導線は残したまま**、次の手を示す。
  static const settingsUnavailableHint =
      '設定画面を開けませんでした。端末の「設定」→「アプリ」→このアプリ→'
      '「すべてのファイルへのアクセス」から許可してください。';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const Key('storage-permission-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.folder_off_outlined, size: 18, color: colors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  explanation,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
          if (settingsUnavailable) ...[
            const SizedBox(height: 8),
            Text(
              settingsUnavailableHint,
              key: const Key('storage-settings-unavailable'),
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('open-storage-settings'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('設定を開いて許可する'),
            ),
          ),
        ],
      ),
    );
  }
}
