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
/// 「ファイルを選ぶ」→ **種類を選ぶ**(desktop は画像 / 動画 / 文書 / すべて、
/// **Android は文書を除く3つ**。004 REQ-011)→
/// 種類に応じた選択 UI(Android は app 内 browser)で**フォルダを辿って
/// ファイルを複数選択** → 確定した集合で
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
    required this.permission,
    required this.kinds,
  });

  /// 読み込み元(実装は **Android = app 内 file browser** / デスクトップのピッカー、
  /// テストでは fake)。
  final FileSource source;

  /// 置き換え先のリスト。
  final FileListController controller;

  /// このplatformで出す種類(004 REQ-011)。
  ///
  /// **Android は3つ、desktop は4つ。** 判定は composition root が行う —
  /// ここが platform を見ない。
  final List<FileKind> kinds;

  /// 全ファイルアクセスの判定(013 REQ-001〜004)。
  ///
  /// **Android を制限するのは composition root の仕事**で、ここが platform を
  /// 判定しない。
  ///
  /// **既定値を置かない。** 既定で「制限しない」にできると、結線を忘れた経路が
  /// 黙って REQ-001 を素通りする(独立review attempt 1 の P1-3)。
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

  /// 帯に出す「いま何がどこから入っているか」(008:T08 要望11・12)。
  ///
  /// - 読み込み前: `未選択`
  /// - 場所が1つ: **その folder 名**。行側は出さない(002 の決定。`008:T22`)
  /// - 場所が2つ以上: **具体名を出さず**複数であることだけを示す(要望12)。
  ///   どの行がどの folder かは行側が示す
  /// - ファイルはあるが場所を持たない(デモデータ等): **`null`**。
  ///   **嘘の場所も `未選択` も出さない** — ファイルは入っているので `未選択` は誤りである
  static String? locationLabelOf(FileListController controller) {
    if (controller.items.isEmpty) return '未選択';
    final names = controller.items
        .map((item) => item.sourceLocation)
        .whereType<String>()
        .toSet();
    if (names.isEmpty) return null;
    if (names.length == 1) return names.single;
    return '複数のフォルダ';
  }

  /// 読み込み button の文言(要望11)。
  ///
  /// **読み込み済みなら `別フォルダへ`。** 将来「同じ folder から追加する」button が
  /// できたときに使い分けられるよう、開発者が指定した文言である。
  /// **「選択されていないとき」は一覧が空のとき**と読む — 行の checkbox を全部外しても
  /// ファイルは入っているので、そこから読み込み先を選び直す導線は `別フォルダへ` のままが正しい。
  static String pickLabelOf(FileListController controller) =>
      controller.items.isEmpty ? 'ファイルを選ぶ' : '別フォルダへ';
}

/// 帯の場所の提示。
const Key sourceLocationLabelKey = Key('source-location-label');

/// 読み込み帯そのもの(幅と配置の検査に使う)。
const Key sourceBarKey = Key('file-source-bar');

class _FileSourceBarState extends State<FileSourceBar>
    with WidgetsBindingObserver {
  /// 直近の確認結果。**判定には使わない** — 表示を決めるためだけに持つ。
  ///
  /// 013 REQ-004 は「一度確認した結果を持ち回らない」と定めている。読み込みと
  /// 実行の可否は毎回 [StoragePermissionPort.check] を呼んで決める。ここに
  /// 残すのは「いま説明を出すべきか」という**表示上の状態**だけである。
  StoragePermissionState? _lastSeen;

  /// 直前に設定画面を開けなかったか。
  bool _settingsUnavailable = false;

  @override
  void initState() {
    super.initState();
    // **ここでは確認しない**(013 REQ-002: 起動しただけでは確認も遷移もしない)。
    // 登録するのは、設定画面から**戻ってきたとき**に気づくためである。
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 設定画面から戻ってきたら確認し直す(013 REQ-004)。
  ///
  /// **`openSettings` の直後では足りない。** `startActivity` は画面を出しただけで
  /// 即座に返るので、その時点ではまだ許可されていない。**利用者が許可して戻って
  /// きた瞬間**に気づくには、app の復帰を見るしかない(独立review attempt 2 の F1)。
  ///
  /// **一度も確認していないうちは何もしない**(013 REQ-002)。起動直後の復帰で
  /// 確認しに行くと、目的を持つ前に権限を問うことになる。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_lastSeen == null) return;
    _checkPermission();
  }

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
    // **ここでは確認し直さない。** `openSettings` は画面を出しただけで即座に返るので、
    // この時点の状態は押す前と同じである。許可して戻ってきたことに気づくのは
    // [didChangeAppLifecycleState] の仕事で、開けなかった端末では状態が変わらない。
    setState(() => _settingsUnavailable = !opened);
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
              for (final kind in widget.kinds)
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
        final locationLabel = FileSourceBar.locationLabelOf(widget.controller);
        return Column(
          mainAxisSize: MainAxisSize.min,
          // **`stretch` が要る。** 既定の `center` だと帯が中身の幅しか持たず、
          // 読み込み前に画面幅より短い帯が浮く(実機確認 2026-09-18 の手順2)。
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 未許可のときだけ、読み込み導線の**上**に説明と設定導線を出す
            // (013 REQ-001 / REQ-003)。拒否後も出し続ける。
            if (_lastSeen == StoragePermissionState.denied)
              StoragePermissionNotice(
                onOpenSettings: _openSettings,
                settingsUnavailable: _settingsUnavailable,
              ),
            Container(
              key: sourceBarKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              // **左に場所、右に読み込み button の固定配置**(実機確認 2026-09-18)。
              // folder 名の長さで button の位置が動くと、押す場所を毎回探すことになる。
              // 名前は `Expanded` 側で省略し、button は自分の幅を保つ。
              child: Row(
                children: [
                  Expanded(
                    child: locationLabel == null
                        // 場所を出さないときも**左側の取り分は残す** — button の位置を
                        // 状態によって動かさないためである。
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 14,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              // 入りきらない分は省略する(実機確認で「このままでよい」と
                              // 確認済み)。**button を押し出さない**のが要点である。
                              Flexible(
                                child: Text(
                                  locationLabel,
                                  key: sourceLocationLabelKey,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  // **button は右端に固定する**(実機確認 2026-09-18)。folder 名の
                  // 長さで位置が動くと、押す場所を毎回探すことになる。
                  OutlinedButton.icon(
                    key: const Key('pick-files-button'),
                    onPressed: () => _openKindSheet(context),
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: Text(
                      FileSourceBar.pickLabelOf(widget.controller),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  // 「すべて外す」は**一覧の件数と同じ階層へ置きたい**(2026-09-18 の
                  // 指摘)が、その帯は 320dp・文字倍率1.3 で余白がほぼ無く、icon だけに
                  // しても件数が切り詰められた(`008:T16` の N-9 の保証が壊れる)。
                  // **置き場所の決着まではこの帯に置いたままにする。**
                  TextButton.icon(
                    key: const Key('clear-files-button'),
                    onPressed: hasFiles ? widget.controller.clearFiles : null,
                    icon: const Icon(Icons.playlist_remove, size: 16),
                    label: const Text('すべて外す'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      disabledForegroundColor: colors.textDisabled,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
