import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import '../../data/file_source/file_loading.dart';
import '../../data/file_source/file_source.dart';
import '../../data/permission/storage_permission.dart';
import '../common/app_toast.dart';
import '../file_list/file_list_controller.dart';
import '../file_list/header_metrics.dart';
import '../file_list/removal_selection.dart';
import '../permission/storage_permission_notice.dart';
import '../theme/app_colors.dart';
import 'file_kind.dart';
import 'list_origin.dart';
import 'same_folder_reopen.dart';
import 'source_path_text.dart';
import '../theme/app_typography.dart';

/// ファイルの読み込み入口(004 REQ-007/008/011/012)。
///
/// 「ファイルを選ぶ」→ **種類を選ぶ**(desktop は写真・動画 / 文書 / すべて、
/// **Android は文書を除く2つ**。004 REQ-011)→
/// 種類に応じた選択 UI(Android の「写真・動画」は選択画面、「すべて」は app 内
/// browser)で**ファイルを複数選択** → 確定した集合で
/// 002 のリストを**置き換える**(蓄積しない)。
/// [Cancelled] はリスト無変化・通知なし、[Failed] は無変化のまま理由を通知する。
/// 選択が**複数の親フォルダに跨っていたら警告**する(REQ-012。写真・動画の選択画面
/// からの読み込みを除く)。
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
    this.removalSelection,
    this.trailing,
    this.reopen,
    this.listOrigin,
  });

  /// 一覧の先頭の行から読み込み元を開き直す受け口(004 REQ-021。`008:T56` /
  /// REQ-024。`010:T09`)。
  ///
  /// 帯が**自分の開き直しの処理を登録する**。権限の確認と説明・失敗の通知を
  /// 読み込みと同じ経路に載せるためで、先頭の行はこれを呼ぶだけである。
  /// 読み込み元が写真・動画の選択画面なら選択画面を、そうでなければ同じ folder を
  /// browser で開き直す。[source] が開き直せなければ(desktop)何もしない。
  final SameFolderReopen? reopen;

  /// 一覧の読み込み元(004 REQ-024)。帯が一覧を置き換えるたびに記録する。
  /// `null` なら記録せず、場所の表示も読み込み元を見ない。
  final ListOriginState? listOrigin;

  /// 帯の右端、読み込み button の右に置くもの(`008:T10`)。
  ///
  /// composition root が**歯車**(`008:T43`)を渡す。見出しの帯を削除したので
  /// (2026-10-01 の開発者の決定)、歯車の置き場所がここへ移った。**モードの出入りで
  /// 消さない** — 以前の見出しの帯でもモード中に出ていた。
  final Widget? trailing;

  /// 読み込み元(実装は **Android = app 内 file browser** / デスクトップのピッカー、
  /// テストでは fake)。
  final FileSource source;

  /// 置き換え先のリスト。
  final FileListController controller;

  /// このplatformで出す種類(004 REQ-011)。
  ///
  /// **Android は2つ、desktop は3つ。** 判定は composition root が行う —
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

  /// 一覧の**除去のための選択モード**(002 REQ-018)。`null` なら常に通常表示として扱う。
  ///
  /// **モード中は `別フォルダへ` を隠す**(2026-09-19 の要望7)。外す作業の最中に
  /// 読み込み直しの導線が並んでいると、一覧が丸ごと置き換わる操作(004 REQ-004)と
  /// 取り違えやすい。**帯そのもの(場所の表示)は隠さない** — いまどこを扱っているかは
  /// モード中こそ読みたい。
  ///
  /// **隠しても帯の寸法は変えない**(`008:T30` の要望1)。
  final RemovalSelection? removalSelection;

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
  /// - 写真・動画の選択画面から読み込んだ一覧: `写真・動画`(004 REQ-024。folder 名や
  ///   `複数のフォルダ` ではない)
  /// - 場所が1つ: **その folder 名**。行側は出さない(002 の決定。`008:T22`)
  /// - 場所が2つ以上: **具体名を出さず**複数であることだけを示す(要望12)。
  ///   どの行がどの folder かは行側が示す
  /// - ファイルはあるが場所を持たない(デモデータ等): **`null`**。
  ///   **嘘の場所も `未選択` も出さない** — ファイルは入っているので `未選択` は誤りである
  static String? locationLabelOf(
    FileListController controller, {
    ListOrigin? origin,
  }) {
    if (controller.items.isEmpty) return '未選択';
    if (origin == ListOrigin.mediaPicker) return mediaPickerOriginLabel;
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

/// 帯の場所(folder 名)の文字の大きさ(`008:T10`)。以前は 12。
const double sourceLocationFontSize = AppFontSize.bodyLarge;

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
    widget.reopen?.attach(_reopen);
    widget.controller.addListener(_closeWarningIfSingleFolder);
  }

  @override
  void didUpdateWidget(FileSourceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_closeWarningIfSingleFolder);
      widget.controller.addListener(_closeWarningIfSingleFolder);
    }
    if (oldWidget.reopen != widget.reopen) {
      oldWidget.reopen?.detach(_reopen);
      widget.reopen?.attach(_reopen);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_closeWarningIfSingleFolder);
    widget.reopen?.detach(_reopen);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 一覧の読み込み元を、一覧の状態を初期値にして開き直す(004 REQ-021 / REQ-024)。
  ///
  /// 読み込み元が写真・動画の選択画面なら選択画面を、そうでなければ所属 folder を
  /// browser で開き直す。
  Future<void> _reopen() => widget.listOrigin?.current == ListOrigin.mediaPicker
      ? _reopenMediaPicker()
      : _reopenSameFolder();

  /// 写真・動画の選択画面を、一覧にあるファイルを選択済みにして開き直す(004 REQ-024)。
  ///
  /// 権限・確定(置き換え。並びは 002 REQ-021)・`Cancelled`・`Failed` の扱いは
  /// [_reopenSameFolder] と同じ。
  Future<void> _reopenMediaPicker() async {
    final source = widget.source;
    if (source is! MediaPickSource) return;
    final picker = source as MediaPickSource;
    final items = widget.controller.items;
    if (items.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (await _checkPermission() == StoragePermissionState.denied) return;
    final selected = {for (final item in items) ?item.sourceHandle};
    final error = await applyPick(() => picker.pickMedia(selected: selected), (
      entries,
    ) {
      widget.listOrigin?.record(ListOrigin.mediaPicker);
      widget.controller.reselectFiles(entries);
    });
    _notifyError(messenger, error);
  }

  /// 一覧の所属 folder を、一覧の状態を初期値にして開き直す(004 REQ-021)。
  ///
  /// **読み込みと同じく、開く前に権限を確かめる**(013 REQ-004)。未許可なら開かず、
  /// 帯の位置に説明を出す(013 REQ-001 / REQ-003)。確定は置き換え(004 REQ-004)で、
  /// 並びだけ 002 REQ-021 に従う([FileListController.reselectFiles])。
  /// `Cancelled` は無変化、`Failed`(folder が無いなど)は無変化のまま理由を通知する。
  Future<void> _reopenSameFolder() async {
    final source = widget.source;
    final items = widget.controller.items;
    final folder = soleFolderOf(items);
    if (source is! FolderReopenSource || folder == null) return;
    final reopener = source as FolderReopenSource;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (await _checkPermission() == StoragePermissionState.denied) return;
    final selected = {for (final item in items) ?item.sourceHandle};
    final error = await applyPick(
      () => reopener.reopenFolder(folder, selected: selected),
      (entries) {
        widget.listOrigin?.record(ListOrigin.browser);
        widget.controller.reselectFiles(entries);
      },
    );
    _notifyError(messenger, error);
  }

  /// 開き直しの失敗を通知する(004 REQ-008)。
  void _notifyError(ScaffoldMessengerState? messenger, PickError? error) {
    if (error == null || messenger == null) return;
    showAppToast(
      messenger,
      key: const Key('file-source-error'),
      tone: ToastTone.danger,
      content: Text(FileSourceBar.messageOf(error)),
    );
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

  /// 出している複数フォルダの警告(REQ-012)。閉じたら `null`。
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _multiFolderWarning;

  /// 警告の本文に付ける key。**本文が描かれている = 警告がいま出ている**ことを
  /// 確かめるのに使う(表示待ちの通知は描かれない)。
  final GlobalKey _multiFolderWarningContent = GlobalKey();

  /// 前の一覧についての警告を閉じる(REQ-012)。
  ///
  /// この警告はエラーと同じく**閉じるまで残る**(2026-09-28 の決定)ので、一覧が
  /// 変わっても残り続け、もう当てはまらない警告を出したままになっていた
  /// (2026-10-05 の `010:T07` の実機確認で見つかった)。
  ///
  /// **いま出ているときだけ閉じる。** `close` は先頭の通知を下げるので、表示待ちの
  /// ときに呼ぶと別の通知を下げてしまう。
  void _closeMultiFolderWarning() {
    final warning = _multiFolderWarning;
    _multiFolderWarning = null;
    if (warning == null) return;
    if (_multiFolderWarningContent.currentContext != null) warning.close();
  }

  /// 一覧が単一フォルダ(または空)になったら警告を閉じる。除去・全消去・開き直しで
  /// 一覧が変わったときも、当てはまらない警告を残さない。
  void _closeWarningIfSingleFolder() {
    if (_multiFolderWarning == null) return;
    if (FileSourceBar.distinctLocationCount(widget.controller) <= 1) {
      _closeMultiFolderWarning();
    }
  }

  Future<void> _load(BuildContext context, FileKind kind) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final source = widget.source;
    final fromMediaPicker = kind == FileKind.media && source is MediaPickSource;
    // **置き換えたかどうかを持つ。** `applyPick` は確定と `Cancelled` のどちらも
    // `null` を返すので、それだけでは区別できない。
    var replaced = false;
    void setFiles(List<FileEntry> entries) {
      replaced = true;
      // 読み込み元は置き換える**前に**記録する(置き換えた結果が空なら読み込み元は
      // 無い。REQ-024)。app 内 browser を持つ source(Android)なら browser、
      // そうでなければ OS のファイル選択画面である。
      widget.listOrigin?.record(
        fromMediaPicker
            ? ListOrigin.mediaPicker
            : source is FolderReopenSource
            ? ListOrigin.browser
            : ListOrigin.systemPicker,
      );
      widget.controller.setFiles(entries);
    }

    final error = fromMediaPicker
        ? await applyPick((source as MediaPickSource).pickMedia, setFiles)
        : await loadFilesInto(source, setFiles, mimeTypes: kind.mimeTypes);
    // 一覧を置き換えたら、前の一覧についての警告は当てはまらない。
    if (replaced) _closeMultiFolderWarning();
    if (messenger == null) return;
    // Cancelled と成功は通知しない(REQ-008)。
    if (error != null) {
      showAppToast(
        messenger,
        key: const Key('file-source-error'),
        tone: ToastTone.danger,
        content: Text(FileSourceBar.messageOf(error)),
      );
      return;
    }
    // 複数の親フォルダに跨っていたら警告する(REQ-012)。読み込み自体は行う。
    // **写真・動画の選択画面から読み込んだときは警告しない** — 跨いで選ぶことが
    // その画面の目的であり、どの folder のファイルかは行の場所で分かる
    // (REQ-012。2026-10-05 開発者の決定)。
    //
    // **`Cancelled` では警告しない**(REQ-008: 無変化・通知なし)。一覧が初めから
    // 複数フォルダ(デモの初期値など)のとき、何も選ばずに戻っただけで警告が出ていた
    // (2026-10-05 の `010:T07` の実機確認で見つかった)。
    if (replaced &&
        !fromMediaPicker &&
        FileSourceBar.distinctLocationCount(widget.controller) > 1) {
      _multiFolderWarning = showAppToast(
        messenger,
        key: const Key('multi-folder-warning'),
        tone: ToastTone.danger,
        content: Text(
          key: _multiFolderWarningContent,
          '複数のフォルダのファイルが含まれています。リネームしても同じ場所には集まりません。',
        ),
      );
      final warning = _multiFolderWarning!;
      // 利用者が閉じたら忘れる。
      warning.closed.then((_) {
        if (identical(_multiFolderWarning, warning)) _multiFolderWarning = null;
      });
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
                    fontSize: AppFontSize.title,
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
                    // 「写真・動画」は選択画面を持つ source(Android)かどうかで
                    // 開くものが違う(REQ-011 / REQ-022)。
                    kind.descriptionFor(
                      mediaPicker: widget.source is MediaPickSource,
                    ),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: AppFontSize.label,
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
    FileKind.media => Icons.photo_library_outlined,
    FileKind.document => Icons.description_outlined,
    FileKind.all => Icons.folder_open,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        ?widget.removalSelection,
        ?widget.listOrigin,
      ]),
      builder: (context, _) {
        final hasFiles = widget.controller.items.isNotEmpty;
        // 一覧が空ならモードは成り立たない(一覧側と同じ判定。002 REQ-018)。
        final selecting =
            (widget.removalSelection?.selecting ?? false) && hasFiles;
        final origin = widget.listOrigin?.current;
        final locationLabel = FileSourceBar.locationLabelOf(
          widget.controller,
          origin: origin,
        );
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
              // 左右の padding は**吹き出しのツノの位置にも効く**ので共有する
              // (`008:T30`)。
              padding: const EdgeInsets.symmetric(
                horizontal: sourceBarHorizontalPadding,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              // **左に場所、右に読み込み button の固定配置**(実機確認 2026-09-18)。
              // folder 名の長さで button の位置が動くと、押す場所を毎回探すことになる。
              // 名前は `Expanded` 側で省略し、button は自分の幅を保つ。
              //
              // **button 群は `Wrap` に入れ、上限を帯の75%で切る。** `Row` へ直に並べると
              // 狭幅 + 文字倍率で intrinsic 幅の合計が帯を超えて **overflow する**
              // (320dp・倍率1.3 で17px。独立review attempt 3 の N-1)。`Row` は
              // **非flexの子へ無限幅の制約を渡す**ので、`Wrap` に入れるだけでは折り返さない。
              // 上限を与えて初めて次の行へ落ち、**幅は max(各行) に縮む**ので場所の取り分も残る。
              // **位置が folder 名に依存しないこと**は変わらない — button 群の幅は名前と
              // 無関係だからである。
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: locationLabel == null
                          // 場所を出さないときも**左側の取り分は残す** — button の位置を
                          // 状態によって動かさないためである。
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // folder のアイコンは残す(2026-10-01 に消したのは
                                // 読み込み button のアイコンだけ)。
                                Icon(
                                  origin == ListOrigin.mediaPicker
                                      ? Icons.photo_library_outlined
                                      : Icons.folder_outlined,
                                  size: 14,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                // 入りきらない分は省略する。**button を押し出さない**のが
                                // 要点である。**省略するのは先頭側**で、判別に効く末尾を残す
                                // (`…/DCIM/t07-fixtures`。2026-09-18 の実機確認 → `008:T23`)。
                                Flexible(
                                  child: SourcePathText(
                                    text: locationLabel,
                                    textKey: sourceLocationLabelKey,
                                    // **白で、少し大きく**(`008:T10`。2026-10-01 の要望。
                                    // 以前は薄い灰色の 12 で読みにくかった)。
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: sourceLocationFontSize,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.75,
                      ),
                      // **`IndexedStack` は出さない側も layout する。** これが
                      // 「モードの出入りで帯の高さが変わらない」の作り方である
                      // (`008:T30` の要望1)。`if (!selecting)` で button を外すと、
                      // 枠(縦 padding 8 + 枠線を持つ `OutlinedButton`)が丸ごと消えて
                      // 帯が場所のラベルの高さまで縮み、**下の一覧が跳ねる**。
                      //
                      // もう一方は**空の箱**である。`IndexedStack` は全部の子を
                      // layout して**いちばん大きい子に合わせる**ので、帯の高さも幅も
                      // 通常表示のまま動かない(場所の取り分も変わらない)。
                      //
                      // **描画と hit test と semantics は出している側だけ**である
                      // (`IndexedStack` は index の子しか辿らない)。モード中に
                      // `別フォルダへ` を押せず、読み上げもされず、既定の finder からも
                      // 見つからない。
                      //
                      child: IndexedStack(
                        alignment: Alignment.centerRight,
                        index: selecting ? 1 : 0,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // **button は右端に固定する**(実機確認 2026-09-18)。
                              // folder 名の長さで位置が動くと、押す場所を毎回探すことになる。
                              // **アイコンは置かない**(`008:T10`。2026-10-01 の要望。
                              // 参考designも文字だけの button)。
                              OutlinedButton(
                                key: const Key('pick-files-button'),
                                onPressed: () => _openKindSheet(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.primary,
                                  side: BorderSide(
                                    color: colors.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  FileSourceBar.pickLabelOf(widget.controller),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // **`一覧を空にする` はここには無い。** `008:T29` で
                              // 一覧のケバブの「すべてをリネーム対象から外す」へ移した
                              // (`file_list_view.dart` の `menuClearAllKey`)。操作の
                              // 意味は変えていない(`clearFiles` + 取り消し。002 REQ-017)。
                            ],
                          ),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                    ?widget.trailing,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
