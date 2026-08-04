import 'package:flutter/material.dart';

import '../../data/file_source/file_loading.dart';
import '../../data/file_source/file_source.dart';
import '../file_list/file_list_controller.dart';
import '../theme/app_colors.dart';

/// ファイルの読み込み入口(004 REQ-007/008)。
///
/// 「フォルダを開く」「ファイルを選ぶ」で [FileSource] を呼び、結果を 002 の
/// 作業セットへ**追加**する(差し替えない)。複数回押せば別フォルダ分も蓄積される。
/// [Cancelled] は無変化・通知なし、[Failed] は無変化のまま理由を通知する。
/// 「すべて外す」で作業セットを空にする(004 REQ-006)。
class FileSourceBar extends StatelessWidget {
  const FileSourceBar({
    super.key,
    required this.source,
    required this.controller,
  });

  /// 読み込み元(実装は T4 の実 SAF / ピッカー、テストでは fake)。
  final FileSource source;

  /// 追加先の作業セット。
  final FileListController controller;

  /// 失敗理由の表示文(004 REQ-008: 理由が伝わること)。
  static String messageOf(PickError error) {
    final reason = switch (error.kind) {
      PickErrorKind.permissionDenied => 'アクセスが許可されませんでした',
      PickErrorKind.io => 'ファイルの読み込みに失敗しました',
      PickErrorKind.unknown => 'ファイルを読み込めませんでした',
    };
    final detail = error.message;
    return detail == null ? reason : '$reason（$detail）';
  }

  Future<void> _run(
    BuildContext context,
    Future<PickError?> Function(FileSource, AddFiles) load,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final colors = context.colors;
    final error = await load(source, controller.addFiles);
    // Cancelled と成功は通知しない(REQ-008)。
    if (error == null || messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('file-source-error'),
        content: Text(messageOf(error)),
        backgroundColor: colors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 作業セットの件数に応じて「すべて外す」の有効/無効を切り替えるため購読する。
    // (003 T6 で初期ルール同期がフレーム後に回り、ビルド中の通知が無くなったため
    //  同一フレームに並べても安全になった。)
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasFiles = controller.items.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              _SourceButton(
                key: const Key('open-folder-button'),
                icon: Icons.folder_open,
                label: 'フォルダを開く',
                onPressed: () => _run(context, loadFolderInto),
              ),
              const SizedBox(width: 8),
              _SourceButton(
                key: const Key('pick-files-button'),
                icon: Icons.note_add_outlined,
                label: 'ファイルを選ぶ',
                onPressed: () => _run(context, loadFilesInto),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('clear-files-button'),
                onPressed: hasFiles ? controller.clearFiles : null,
                icon: const Icon(Icons.playlist_remove, size: 16),
                label: const Text('すべて外す'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  disabledForegroundColor: colors.textDisabled,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 読み込み導線のボタン(アクセント枠)。
class _SourceButton extends StatelessWidget {
  const _SourceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
