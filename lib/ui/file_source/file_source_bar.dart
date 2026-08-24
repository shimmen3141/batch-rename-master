import 'package:flutter/material.dart';

import '../../data/file_source/file_loading.dart';
import '../../data/file_source/file_source.dart';
import '../../data/permission/storage_permission.dart';
import '../file_list/file_list_controller.dart';
import '../permission/storage_permission_notice.dart';
import '../theme/app_colors.dart';
import 'file_kind.dart';

/// ファイルの読み込み入口(004 REQ-007/008/011/012)。
///
/// 「ファイルを選ぶ」→ **種類(画像 / 動画 / 文書 / すべて)を選ぶ** →
/// 種類に応じた選択 UI で**フォルダを辿ってファイルを複数選択** → 確定した集合で
/// 002 のリストを**置き換える**(蓄積しない)。
/// [Cancelled] はリスト無変化・通知なし、[Failed] は無変化のまま理由を通知する。
/// 選択が**複数の親フォルダに跨っていたら警告**する(REQ-012)。
///
/// **Android では全ファイルアクセスが要る**(013 REQ-001)。権限が無い間は
/// 読み込ませず、この位置に理由の説明と設定導線を出す。
/// 権限は**読み込みを始めるたびに確認する**(013 REQ-004) — 設定から取り消され
/// うるので、一度確認した結果を持ち回らない。**起動しただけでは確認も遷移も
/// しない**(013 REQ-002)。
class FileSourceBar extends StatefulWidget {
  const FileSourceBar({
    super.key,
    required this.source,
    required this.controller,
    this.permission = const UnrestrictedStoragePermission(),
  });

  /// 読み込み元(実装は Android SAF / デスクトップのピッカー、テストでは fake)。
  final FileSource source;

  /// 置き換え先のリスト。
  final FileListController controller;

  /// 全ファイルアクセスの判定(013 REQ-001〜004)。
  ///
  /// 既定は制限しない port である。**Android を制限するのは composition root の
  /// 仕事**で、ここが platform を判定しない。
  final StoragePermissionPort permission;

  @override
  State<FileSourceBar> createState() => _FileSourceBarState();

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

  /// リストに含まれる親フォルダ(表示用の場所)の種類数(REQ-012 の判定)。
  static int distinctLocationCount(FileListController controller) => controller
      .items
      .map((item) => item.sourceLocation)
      .whereType<String>()
      .toSet()
      .length;
}

class _FileSourceBarState extends State<FileSourceBar> {
  /// 直近の確認結果。**判定には使わない** — 表示を決めるためだけに持つ。
  ///
  /// 013 REQ-004 は「一度確認した結果を持ち回らない」と定めている。読み込みと
  /// 実行の可否は毎回 [StoragePermissionPort.check] を呼んで決める。ここに
  /// 残すのは「いま説明を出すべきか」という**表示上の状態**だけである。
  StoragePermissionState? _lastSeen;

  /// 直前に設定画面を開けなかったか。
  bool _settingsUnavailable = false;

  /// 権限を**その場で**確かめ、表示も更新する(013 REQ-004)。
  Future<StoragePermissionState> _checkPermission() async {
    final state = await widget.permission.check();
    if (mounted) setState(() => _lastSeen = state);
    return state;
  }

  /// 設定画面を開く。**利用者の操作からのみ呼ばれる**(013 REQ-003)。
  Future<void> _openSettings() async {
    final opened = await widget.permission.openSettings();
    if (!mounted) return;
    setState(() => _settingsUnavailable = !opened);
    // 戻ってきた直後に再確認する。設定画面から許可して戻る導線がこれである。
    await _checkPermission();
  }

  Future<void> _load(BuildContext context, FileKind kind) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final colors = context.colors;

    // 画像・動画は枠のみ(中身は写真機能)。未実装であることを伝える(REQ-011)。
    if (!kind.isImplemented) {
      messenger?.showSnackBar(
        SnackBar(
          key: const Key('file-kind-unimplemented'),
          content: Text('「${kind.label}」の読み込みは写真機能で対応予定です'),
          backgroundColor: colors.info,
        ),
      );
      return;
    }

    final error = await loadFilesInto(
      widget.source,
      widget.controller.setFiles,
      mimeTypes: kind.mimeTypes,
    );
    if (messenger == null) return;
    // Cancelled と成功は通知しない(REQ-008)。
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          key: const Key('file-source-error'),
          content: Text(FileSourceBar.messageOf(error)),
          backgroundColor: colors.danger,
        ),
      );
      return;
    }
    // 複数の親フォルダに跨っていたら警告する(REQ-012)。読み込み自体は行う。
    if (FileSourceBar.distinctLocationCount(widget.controller) > 1) {
      messenger.showSnackBar(
        SnackBar(
          key: const Key('multi-folder-warning'),
          content: const Text('複数のフォルダのファイルが含まれています。リネームしても同じ場所には集まりません。'),
          backgroundColor: colors.danger,
        ),
      );
    }
  }

  /// 種類を選ぶシートを開き、選ばれた種類で読み込みを始める(REQ-011)。
  ///
  /// **ここが権限を確認する唯一の入口である**(013 REQ-002: 利用者が読み込もうと
  /// したときに確認する / REQ-004: 毎回確認する)。未許可なら**シートを開かず**、
  /// 説明を出したまま留まる。**設定画面は自動で開かない**(013 REQ-003)。
  Future<void> _openKindSheet(BuildContext context) async {
    if (await _checkPermission() == StoragePermissionState.denied) return;
    if (!context.mounted) return;
    final colors = context.colors;
    final picked = await showModalBottomSheet<FileKind>(
      context: context,
      backgroundColor: colors.surface,
      builder: (sheetContext) => SafeArea(
        // 画面が低いときも溢れないようスクロールさせる。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'リネームしたいファイルの種類',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final kind in FileKind.values)
                ListTile(
                  key: Key('file-kind-${kind.name}'),
                  leading: Icon(_iconOf(kind), color: colors.primary, size: 20),
                  title: Text(
                    kind.label,
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  subtitle: Text(
                    kind.isImplemented
                        ? kind.description
                        : '${kind.description}（未実装）',
                    style: TextStyle(
                      color: kind.isImplemented
                          ? colors.textSecondary
                          : colors.textDisabled,
                      fontSize: 11.5,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(kind),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _load(context, picked);
  }

  static IconData _iconOf(FileKind kind) => switch (kind) {
    FileKind.image => Icons.image_outlined,
    FileKind.video => Icons.movie_outlined,
    FileKind.document => Icons.description_outlined,
    FileKind.all => Icons.folder_open,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final hasFiles = widget.controller.items.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 未許可のときだけ、読み込み導線の**上**に説明と設定導線を出す
            // (013 REQ-001 / REQ-003)。拒否後も出し続ける。
            if (_lastSeen == StoragePermissionState.denied)
              StoragePermissionNotice(
                onOpenSettings: _openSettings,
                settingsUnavailable: _settingsUnavailable,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('pick-files-button'),
                    onPressed: () => _openKindSheet(context),
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: const Text('ファイルを選ぶ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(
                        color: colors.primary.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('clear-files-button'),
                    onPressed: hasFiles ? widget.controller.clearFiles : null,
                    icon: const Icon(Icons.playlist_remove, size: 16),
                    label: const Text('すべて外す'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      disabledForegroundColor: colors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
