import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/file_source/android_file_source.dart';
import '../../data/file_source/storage_browser.dart';
import '../common/drag_selection_controller.dart';
import '../theme/app_colors.dart';

/// 現在folderのfileだけを一操作で選ぶ(004 REQ-020)。
const Key browserSelectAllKey = Key('browser-select-all');

/// 支援技術が全選択の操作名とtap actionを認識するSemantics node。
const Key browserSelectAllSemanticsKey = Key('browser-select-all-semantics');

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
        title: const Text('ファイルを選ぶ'),
        leading: IconButton(
          key: const Key('browser-cancel'),
          icon: const Icon(Icons.close),
          tooltip: '閉じる',
          // **決定していない**(004 REQ-001)。`null` を返す。
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(colors),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(key: Key('browser-loading')),
              ),
            )
          else
            Expanded(child: _body(colors)),
          if (_location != null) _footer(colors),
        ],
      ),
    );
  }

  /// 現在の場所を**常に示す**(REQ-015)。
  Widget _header(AppColors colors) {
    final folder = _folder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // **root では出さない**(004 代表例 26d「上位へ戻る操作は無いか無効」)。
          // **向きは `←`**(`013:T07` の U3。`↑` より馴染むという指摘)。keyと
          // tooltipの意味は変えない — 辿る先は1つ上のfolderのままである。
          if (_location != null &&
              _folder != null &&
              canGoUp(folder: _folder!, root: _location!.root))
            IconButton(
              key: const Key('browser-up'),
              icon: const Icon(Icons.arrow_back, size: 18),
              tooltip: '上のフォルダへ',
              onPressed: _goUp,
            )
          // **保存場所が複数あるときだけ出す**(REQ-015)。
          else if (_location != null && _canSwitchLocation)
            IconButton(
              key: const Key('browser-locations'),
              icon: const Icon(Icons.sd_storage, size: 18),
              tooltip: '保存場所を選び直す',
              onPressed: _backToLocations,
            ),
          Expanded(
            child: Text(
              key: const Key('browser-current-location'),
              folder == null ? '保存場所' : _displayPath(folder),
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 表示用の場所。root は保存場所の名前に置き換える(生の path を主役にしない)。
  String _displayPath(String folder) => _displayPathOf(_location!, folder);

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
          // **`/Android/` 配下では、改名できない可能性を示す**(REQ-018)。
          // 注記であって判定ではないので、表示も選択も妨げない。
          if (showsRestrictedNotice(_folder!))
            Container(
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
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // **空のfolderは「何も無い」で終わらせない**(`013:T07` の U6)。
          // 「読み込み中」「開けなかった」「空」が同じ見た目になるのを避ける。
          // **`browser-listing-failed` とは別のkey**で、両者を区別できるようにする。
          if (entries.isEmpty)
            Padding(
              key: const Key('browser-listing-empty'),
              padding: const EdgeInsets.all(24),
              child: Text(
                'このフォルダにファイルはありません',
                style: TextStyle(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          for (final entry in entries)
            if (entry.isDirectory)
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
                  child: CheckboxListTile(
                    value: _selected.contains(entry.path),
                    onChanged: (_) => _toggle(entry),
                    title: Text(
                      entry.name,
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
              ),
        ],
      ),
    );
  }

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

  Widget _footer(AppColors colors) {
    final files = _selectableFiles;
    final allSelected =
        files.isNotEmpty &&
        files.every((entry) => _selected.contains(entry.path));
    final selectAll = files.isEmpty || allSelected ? null : _selectAll;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            key: const Key('browser-selected-count'),
            '${_selected.length} 件を選択中',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          Semantics(
            key: browserSelectAllSemanticsKey,
            container: true,
            button: true,
            enabled: selectAll != null,
            label: 'すべて選択',
            onTap: selectAll,
            child: ExcludeSemantics(
              child: TextButton(
                key: browserSelectAllKey,
                onPressed: selectAll,
                child: const Text('すべて選択'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('browser-confirm'),
            onPressed: _selected.isEmpty ? null : _confirm,
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
