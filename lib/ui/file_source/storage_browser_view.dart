import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/file_source/android_file_source.dart';
import '../../data/file_source/storage_browser.dart';
import '../common/drag_selection_controller.dart';
import '../theme/app_colors.dart';

/// 現在folderのfileだけを一操作で選ぶ(004 REQ-020)。ケバブの項目である。
const Key browserSelectAllKey = Key('browser-select-all');

/// 現在folderの選択を一操作ですべて解除する、ケバブの項目(004 REQ-020)。
///
/// **1件でも選択があるときだけ出す。** `×`([browserClearSelectionKey])と同義だが、
/// こちらは**操作名で認識できる経路**である(`008:T38` の決定)。
const Key browserMenuClearSelectionKey = Key('browser-menu-clear-selection');

/// header 左の `×`。**選択中だけ出し、全解除だけを意味する**(`008:T38`)。
///
/// **画面は閉じない。** 閉じるのは [browserBackToRenameKey] だけである。
const Key browserClearSelectionKey = Key('browser-clear-selection');

/// header 右端のケバブ。**選択の有無にかかわらず常に同じ位置に出る**(`008:T38`)。
const Key browserMenuKey = Key('browser-menu');

/// header 中央。保存場所名、選択中は「N件選択中」、一覧では「ファイルを選ぶ」。
const Key browserTitleKey = Key('browser-title');

/// 現在地の帯(パンくず)。末尾以外の区切りは tap でその folder へ移る(`008:T40`)。
const Key browserBreadcrumbKey = Key('browser-breadcrumb');

/// footer 左下の「← リネーム画面へ」。**画面を閉じる唯一の導線**(`008:T38`)。
///
/// 文言は2026-09-23 のエミュレータ確認で「リネーム画面に戻る」から短くした。
///
/// 未確定の選択は捨て、「決定していない」を返す(004 REQ-001)。
const Key browserBackToRenameKey = Key('browser-cancel');

/// パンくずの [index] 番目の区切り(0 が保存場所の root)。
Key browserBreadcrumbSegmentKey(int index) => Key('browser-breadcrumb-$index');

/// パンくずの [index] 番目の区切りを押す対象(`008:T40`)。**末尾には無い。**
Key browserBreadcrumbButtonKey(int index) =>
    Key('browser-breadcrumb-button-$index');

/// パンくずの [index] 番目の区切りの前に置く `›`(1 から)。
Key browserBreadcrumbSeparatorKey(int index) =>
    Key('browser-breadcrumb-separator-$index');

/// app 内 file browser(004 REQ-015〜REQ-018)。
///
/// **保存場所から始まる**(REQ-015)。保存場所が複数あるときは一覧から始まり、
/// **1つだけのときは一覧を挟まずその保存場所の root から始まる**。複数あるときは
/// browser を閉じずに別の保存場所へ切り替えられる。現在の場所を常に示し、上位フォルダへ戻れる。
/// **辿れる上限は保存場所の root** で、`/storage` や `/` へは到達経路が無い
/// (絞り込みで隠すのではなく、辿れないことで達成する)。
///
/// **選択は同一フォルダ内に限る**(REQ-016)。フォルダを移動すると選択は解除され、
/// したがって確定した選択の親フォルダは常に1つである。
///
/// **entry は絞り込まずにそのまま見せる**(REQ-017)。隠しファイルもサブフォルダも
/// 並ぶ。不要なものは読み込んだあとに 002 で選択解除する。
///
/// **header・現在地の帯・footer の提示は `008:T38` の操作状態表が正本**である。
/// 要点: header 左の位置を `←` と `×` が共有し(選択中は `×` = 全解除)、ケバブは
/// 常に右端、画面を閉じるのは footer の「← リネーム画面へ」だけ。
class StorageBrowserView extends StatefulWidget {
  const StorageBrowserView({
    super.key,
    required this.browser,
    this.onLocationName,
  });

  final StorageBrowserPort browser;

  /// 辿った folder と、それが属する保存場所の名前を知らせる(004 REQ-009)。
  ///
  /// 行の「場所」を人間可読にするために composition root が受け取る。
  /// **browser 自身は使わない。**
  final void Function(String folder, String locationName)? onLocationName;

  @override
  State<StorageBrowserView> createState() => _StorageBrowserViewState();
}

class _StorageBrowserViewState extends State<StorageBrowserView> {
  StorageLocations? _locations;

  /// いま辿っている保存場所。`null` なら保存場所の一覧を出している。
  StorageLocation? _location;

  /// 現在のフォルダ。[_location] が決まっているときだけ意味を持つ。
  String? _folder;

  DirectoryListing? _listing;

  /// **同一フォルダ内の選択**(REQ-016)。フォルダを移ると捨てる。
  final _selected = <String>{};
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _listViewportKey = GlobalKey();
  late final DragSelectionController<String> _dragSelection =
      DragSelectionController<String>(
        scrollController: _listScrollController,
        viewportKey: _listViewportKey,
        select: _selectPath,
        deselect: _deselectPath,
        isMounted: () => mounted,
      );

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _dragSelection.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    // **port が投げても読み込み中で止まらない。** 製品の実装は投げない構造に
    // してあるが、**約束に頼らずここでも閉じる**(独立review attempt 1 の P3-1。
    // `013:T08` で「例外が保護の外にある」型を2回踏んでいる)。
    StorageLocations locations;
    try {
      locations = await widget.browser.locations();
    } catch (error) {
      locations = StorageLocations(
        const [],
        failure: '保存場所を取得できませんでした: $error',
      );
    }
    if (!mounted) return;
    // **保存場所が1つだけなら一覧を挟まない**(REQ-015)。
    final sole = soleLocation(locations);
    if (sole != null) {
      setState(() => _locations = locations);
      await _enter(sole);
      return;
    }
    setState(() {
      _locations = locations;
      _loading = false;
    });
  }

  /// 保存場所の一覧へ戻れるか(REQ-015)。
  ///
  /// **要求は「複数あるときは閉じずに切り替えられる」ことまで**で、切り替え先が
  /// 無い端末で導線を出すかは自由とされている。**出さない** — 押しても1件の一覧が
  /// 出るだけの空振りになるためで、これは `T11` が U1 で消した無駄な1手と同じものである。
  bool get _canSwitchLocation => (_locations?.locations.length ?? 0) >= 2;

  Future<void> _enter(StorageLocation location, {String? folder}) async {
    _dragSelection.finish();
    setState(() {
      _loading = true;
      _location = location;
      _folder = folder ?? location.root;
      // **移動したら選択を捨てる**(REQ-016)。
      _selected.clear();
    });
    final target = _folder!;
    final listing = await widget.browser.list(target);
    if (!mounted) return;
    // **場所は「保存場所名 + rootからの相対」**である(004 REQ-009)。
    // 保存場所名だけにすると、どのfolderから読み込んでも同じ表示になる
    // (独立review attempt 2 のP2-1)。root の basename `0` も出さない。
    widget.onLocationName?.call(target, _displayPathOf(location, target));
    setState(() {
      _listing = listing;
      _loading = false;
    });
  }

  /// 上位フォルダへ戻る。**root では呼ばない**(そこでは button を出さない)。
  Future<void> _goUp() async {
    final location = _location!;
    final folder = _folder!;
    // **上限は保存場所の root**(REQ-015)。`/storage` や `/` へは辿れない。
    if (!canGoUp(folder: folder, root: location.root)) return;
    await _enter(location, folder: parentOf(folder));
  }

  /// 保存場所の一覧へ戻る。**上位 path へ辿るのではない**(REQ-015)。
  ///
  /// **ここで選択を捨てる必要は無い。** 次に保存場所を選べば [_enter] が捨てる
  /// (REQ-016)。観測できない処理を残さない。
  void _backToLocations() {
    _dragSelection.finish();
    setState(() {
      _location = null;
      _folder = null;
      _listing = null;
    });
  }

  void _toggle(BrowserEntry entry) {
    setState(() {
      if (!_selected.remove(entry.path)) _selected.add(entry.path);
    });
  }

  void _selectPath(String path) {
    if (_selected.add(path) && mounted) setState(() {});
  }

  void _deselectPath(String path) {
    if (_selected.remove(path) && mounted) setState(() {});
  }

  void _startDragSelection(BrowserEntry entry, Offset position) {
    _dragSelection.start(
      entry.path,
      position,
      baseline: Set<String>.of(_selected),
    );
  }

  List<BrowserEntry> get _selectableFiles {
    final listing = _listing;
    if (listing is! DirectoryListed) return const [];
    return listing.entries.where((entry) => !entry.isDirectory).toList();
  }

  void _selectAll() {
    final paths = _selectableFiles.map((entry) => entry.path);
    setState(() => _selected.addAll(paths));
  }

  /// 現在folderの選択をすべて解除する(004 REQ-020)。**画面は閉じない。**
  ///
  /// 選択は同一folder内に限る(REQ-016)ので、「現在folderの選択」は選択の全部である。
  void _clearSelection() {
    _dragSelection.finish();
    setState(_selected.clear);
  }

  /// 選択中か。**保存場所の一覧では選択を持たない**(`008:T38` の状態表の1行目)。
  bool get _hasSelection => _location != null && _selected.isNotEmpty;

  /// 「すべて選択」を押せるか。対象が無いか、全件選択済みなら押せない。
  bool get _canSelectAll {
    final files = _selectableFiles;
    return files.isNotEmpty &&
        !files.every((entry) => _selected.contains(entry.path));
  }

  void _confirm() {
    Navigator.of(
      context,
    ).pop(BrowserSelection(folder: _folder!, paths: _selected.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        // **暗黙の戻るを出さない。** header 左は `←` と `×` が共有する位置で、
        // 画面を閉じる導線は footer の「← リネーム画面へ」だけにする(`008:T38`)。
        automaticallyImplyLeading: false,
        leading: _leading(),
        title: Text(
          key: browserTitleKey,
          _title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [_menu(colors)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 現在の場所を**常に示す**(REQ-015)。保存場所の一覧には現在地が無い。
          if (_location != null) _breadcrumb(colors),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(key: Key('browser-loading')),
              ),
            )
          else
            Expanded(child: _body(colors)),
          _footer(colors),
        ],
      ),
    );
  }

  /// header 中央(`008:T38` の状態表)。
  String get _title {
    if (_hasSelection) return '${_selected.length}件選択中';
    return _location?.name ?? 'ファイルを選ぶ';
  }

  /// header 左。**`←` と `×` は同じ位置を共有する**(`008:T38`)。
  ///
  /// 選択中は `×`(全解除)になり、`←` は消える(`T38` が受け入れた代償)。
  /// 選択したまま上へ移るには**パンくずの区切りを押す**(`008:T40`。移動すると
  /// 選択は解除される。004 REQ-016)。
  Widget? _leading() {
    if (_hasSelection) {
      return IconButton(
        key: browserClearSelectionKey,
        icon: const Icon(Icons.close),
        tooltip: '選択をすべて解除',
        onPressed: _clearSelection,
      );
    }
    final location = _location;
    final folder = _folder;
    if (location == null || folder == null) return null;
    // **root では出さない**(004 代表例 26d「上位へ戻る操作は無いか無効」)。
    // **向きは `←`**(`013:T07` の U3。`↑` より馴染むという指摘)。
    if (canGoUp(folder: folder, root: location.root)) {
      return IconButton(
        key: const Key('browser-up'),
        icon: const Icon(Icons.arrow_back),
        tooltip: '上のフォルダへ',
        onPressed: _goUp,
      );
    }
    // **保存場所が複数あるときだけ出す**(REQ-015)。行き先は保存場所の一覧で、
    // 上位 path へ辿るのではない。
    if (_canSwitchLocation) {
      return IconButton(
        key: const Key('browser-locations'),
        icon: const Icon(Icons.arrow_back),
        tooltip: '保存場所の一覧へ',
        onPressed: _backToLocations,
      );
    }
    return null;
  }

  /// header 右端のケバブ。**常に同じ位置に出る**(`008:T38`)。
  ///
  /// 「すべて選択」は常設し、押せないときは無効にする。「選択をすべて解除」は
  /// **1件でも選択があるときだけ**出す(004 REQ-020)。どちらも項目名が操作名に
  /// なるので、支援技術から名前で実行できる。
  Widget _menu(AppColors colors) => PopupMenuButton<VoidCallback>(
    key: browserMenuKey,
    icon: Icon(Icons.more_vert, color: colors.textSecondary),
    tooltip: 'その他の操作',
    onSelected: (action) => action(),
    itemBuilder: (context) => [
      PopupMenuItem<VoidCallback>(
        key: browserSelectAllKey,
        value: _selectAll,
        enabled: _canSelectAll,
        child: const Text('すべて選択'),
      ),
      if (_hasSelection)
        PopupMenuItem<VoidCallback>(
          key: browserMenuClearSelectionKey,
          value: _clearSelection,
          child: const Text('選択をすべて解除'),
        ),
    ],
  );

  /// 現在地の帯(`008:T38`)。末尾以外の区切りは tap で移動できる(`008:T40`)。
  ///
  /// **header ではなく一覧の上の帯として見せる**(2026-09-23 のエミュレータ確認)。
  /// header と同じ面の色を敷かず、一覧と同じ背景に置く。**一覧と一緒には流さない** —
  /// 現在地を常に示すため(004 REQ-015)。
  ///
  /// **左寄せ**にする。はみ出す深さでは**現在の folder が見えるよう末尾側へ寄せる**
  /// (`reverse`)。`reverse` だけだと短いときに右寄せになるので、帯の幅いっぱいの
  /// `Row` を左から詰める。
  Widget _breadcrumb(AppColors colors) {
    final segments = breadcrumbOf(_location!, _folder!);
    // **マウスのドラッグでも横へ送れる**ようにする。Flutter の既定はタッチ等だけで、
    // エミュレータのマウス操作では先頭の保存場所名まで戻れなかった
    // (2026-09-23 のエミュレータ確認2回目)。帯には選択の操作が無いので、
    // ドラッグの意味は横送りだけである。
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      child: Container(
        key: browserBreadcrumbKey,
        // 区切りの当たり判定の余白(左右4・上下6)を足した分だけ減らし、文字の位置は保つ。
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                children: [
                  for (final (index, segment) in segments.indexed) ...[
                    if (index > 0)
                      ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          // **区切りは`textSecondary`**。`textMuted`では薄くて見づらかった
                          // (2026-09-23 のエミュレータ確認)。
                          child: Text(
                            key: browserBreadcrumbSeparatorKey(index),
                            '›',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    _breadcrumbSegment(
                      colors,
                      index,
                      segment,
                      isCurrent: index == segments.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// パンくずの1区切り。**末尾(いま居る folder)以外は tap でその folder へ移る**(`008:T40`)。
  ///
  /// 先頭の保存場所名は**その保存場所の root** へ移る — 保存場所の一覧へ戻る操作
  /// (root(複数)の `←`)とは別物である(2026-09-23 の開発者の決定)。移動は
  /// [_enter] を通るので、**選択は解除され**(004 REQ-016)、行き先は `breadcrumbOf` が
  /// 作った root 以下の path だけである(REQ-015 の上限)。
  ///
  /// **末尾は button にしない。** 押すと同じ folder へ入り直し、選択が消えるだけになる。
  Widget _breadcrumbSegment(
    AppColors colors,
    int index,
    BreadcrumbSegment segment, {
    required bool isCurrent,
  }) {
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        key: browserBreadcrumbSegmentKey(index),
        segment.name,
        style: TextStyle(
          color: isCurrent ? colors.textPrimary : colors.textSecondary,
          fontSize: 13,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
    if (isCurrent) return label;
    return Semantics(
      button: true,
      child: InkWell(
        key: browserBreadcrumbButtonKey(index),
        borderRadius: BorderRadius.circular(4),
        onTap: () => _enter(_location!, folder: segment.path),
        child: label,
      ),
    );
  }

  /// 表示用の場所。root は保存場所の名前に置き換える(生の path を主役にしない)。
  static String _displayPathOf(StorageLocation location, String folder) {
    if (folder == location.root) return location.name;
    return '${location.name}/${p.relative(folder, from: location.root)}';
  }

  Widget _body(AppColors colors) {
    if (_location == null) return _locationList(colors);
    final listing = _listing;
    if (listing is DirectoryListingFailed) {
      return Center(
        key: const Key('browser-listing-failed'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'このフォルダを開けませんでした'
            '${listing.error.message == null ? '' : '（${listing.error.message}）'}',
            style: TextStyle(color: colors.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final entries = (listing as DirectoryListed).entries;
    // **空のfolderは「何も無い」で終わらせない**(`013:T07` の U6)。
    // 「読み込み中」「開けなかった」「空」が同じ見た目になるのを避ける。
    // **`browser-listing-failed` とは別のkey**で、両者を区別できるようにする。
    // **一覧の領域の中央に出す**(2026-09-23 のエミュレータ確認)。
    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showsRestrictedNotice(_folder!)) _restrictedNotice(colors),
          Expanded(
            child: Center(
              child: Padding(
                key: const Key('browser-listing-empty'),
                padding: const EdgeInsets.all(24),
                child: Text(
                  'このフォルダにファイルはありません',
                  style: TextStyle(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _dragSelection.onPointerDown,
      onPointerMove: _dragSelection.onPointerMove,
      onPointerUp: _dragSelection.onPointerUp,
      onPointerCancel: _dragSelection.onPointerCancel,
      child: ListView(
        key: _listViewportKey,
        controller: _listScrollController,
        children: [
          if (showsRestrictedNotice(_folder!)) _restrictedNotice(colors),
          for (final entry in entries)
            if (entry.isDirectory)
              // **folder は navigation として識別できる形を保つ**(`008:T38` の6)。
              // checkbox は持たない — 全選択の対象でもない(REQ-020)。
              ListTile(
                key: Key('browser-folder-${entry.name}'),
                leading: Icon(
                  Icons.folder,
                  color: colors.textSecondary,
                  size: 20,
                ),
                title: Text(
                  entry.name,
                  style: TextStyle(color: colors.textPrimary),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.textMuted,
                  size: 20,
                ),
                onTap: () => _enter(_location!, folder: entry.path),
              )
            else
              GestureDetector(
                key: Key('browser-file-${entry.name}'),
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (details) =>
                    _startDragSelection(entry, details.globalPosition),
                child: Container(
                  key: _dragSelection.rowGeometryKey(entry.path),
                  child: _fileRow(colors, entry),
                ),
              ),
        ],
      ),
    );
  }

  /// **`/Android/` 配下では、改名できない可能性を示す**(REQ-018)。
  /// 注記であって判定ではないので、表示も選択も妨げない。
  Widget _restrictedNotice(AppColors colors) => Container(
    key: const Key('browser-restricted-notice'),
    padding: const EdgeInsets.all(12),
    color: colors.surfaceElevated,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: colors.info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'この場所のファイルは、名前を変更できないことがあります。'
            'アプリごとの保存領域のため、許可があっても書き込めない場合があります。',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _locationList(AppColors colors) => ListView(
    children: [
      // **取れなかったことを黙らせない。** 「媒体が無い端末」と「列挙できていない」を
      // 利用者が区別できないと、装着している SD カードが並ばないことに気づけない
      // (`013:T08` の実機観測で実際に起きた)。
      if (_locations?.failure case final failure?)
        Container(
          key: const Key('browser-locations-failure'),
          padding: const EdgeInsets.all(12),
          color: colors.surfaceElevated,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$failure。ここに出ていない保存場所があるかもしれません。',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      for (final location in _locations?.locations ?? const <StorageLocation>[])
        ListTile(
          key: Key('browser-location-${location.name}'),
          leading: Icon(Icons.sd_storage, color: colors.primary, size: 20),
          title: Text(
            location.name,
            style: TextStyle(color: colors.textPrimary),
          ),
          onTap: () => _enter(location),
        ),
    ],
  );

  /// file 行。**checkbox と選択済みの面はメイン一覧(`008:T29`)へ揃える**
  /// (右端・円・アクセント色。`008:T38` の決定)。
  ///
  /// 行と checkbox を**1つの semantics node** にまとめる — 支援技術から見て
  /// 1行が1つの「選択できる項目」になる。
  Widget _fileRow(AppColors colors, BrowserEntry entry) {
    final selected = _selected.contains(entry.path);
    return MergeSemantics(
      child: ListTile(
        dense: true,
        tileColor: selected ? colors.selectedSurface : null,
        title: Text(entry.name, style: TextStyle(color: colors.textPrimary)),
        trailing: Checkbox(
          value: selected,
          onChanged: (_) => _toggle(entry),
          shape: const CircleBorder(),
          side: BorderSide(color: colors.textMuted, width: 1.5),
          activeColor: colors.selectionMark,
          checkColor: colors.onPrimary,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => _toggle(entry),
      ),
    );
  }

  /// footer。**左下の「← リネーム画面へ」が画面を閉じる唯一の導線**(`008:T38`)。
  ///
  /// 状態表のすべての行に出る。「確定」は選択があるときだけ押せる。
  Widget _footer(AppColors colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border(top: BorderSide(color: colors.border)),
    ),
    // **「確定」の残りを全部「リネーム画面へ」が使える**ようにする。`Spacer`と
    // 分け合うと半分の幅しか無く、通常の文字サイズでも「リネーム画面...」と
    // 切れていた(2026-09-23 のエミュレータ確認)。
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: OutlinedButton.icon(
            key: browserBackToRenameKey,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.background,
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
            ),
            // **決定していない**(004 REQ-001)。`null` を返し、未確定の選択は捨てる。
            // rename 画面の既存状態は呼び出し側が保つ。
            onPressed: () => Navigator.of(context).pop(),
            // **`←`付きの短い文言**(2026-09-23 の開発者の決定。`T38`の
            // 「リネーム画面に戻る」を置き換えた)。
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('リネーム画面へ', overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('browser-confirm'),
          onPressed: _hasSelection ? _confirm : null,
          child: const Text('確定'),
        ),
      ],
    ),
  );
}
