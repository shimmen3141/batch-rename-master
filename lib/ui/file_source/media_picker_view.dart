import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/file_source/media_library.dart';
import '../common/drag_selection_controller.dart';
import '../common/selection_checkbox.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// header 中央。選択が無ければ「写真・動画」、あれば「N件選択中」。
const Key mediaPickerTitleKey = Key('media-picker-title');

/// header 左の `×`。**選択中だけ出し、見えていない選択も含めて全解除する**(REQ-023)。
const Key mediaPickerClearSelectionKey = Key('media-picker-clear-selection');

/// header 右端のケバブ。
const Key mediaPickerMenuKey = Key('media-picker-menu');

/// ケバブの「すべて選択」。**今の絞り込みで並ぶ item** を選択に足す(REQ-023)。
const Key mediaPickerSelectAllKey = Key('media-picker-select-all');

/// ケバブの「選択をすべて解除」。**1件でも選択があるときだけ出す**(REQ-023)。
const Key mediaPickerMenuClearSelectionKey = Key(
  'media-picker-menu-clear-selection',
);

/// アルバムの切り替え(押すと下からアルバムの一覧が出る)。
const Key mediaPickerAlbumButtonKey = Key('media-picker-album-button');

/// アルバムの一覧の「すべてのアルバム」。
const Key mediaPickerAllAlbumsKey = Key('media-picker-album-all');

/// アルバムの一覧の1件。
Key mediaPickerAlbumKey(int id) => Key('media-picker-album-$id');

/// 種類の切り替え(すべて|写真|動画)。
const Key mediaPickerKindKey = Key('media-picker-kind');

/// 種類の切り替えの1つ。
Key mediaPickerKindSegmentKey(MediaKindFilter kind) =>
    Key('media-picker-kind-${kind.name}');

/// 格子の1件。key は path で作る(表示中の item を test が特定するため)。
Key mediaPickerItemKey(String path) => Key('media-picker-item-$path');

/// 日付の見出し。`day` が `null` なら「日付不明」。
Key mediaPickerDayHeaderKey(DateTime? day) => Key(
  day == null
      ? 'media-picker-day-unknown'
      : 'media-picker-day-${day.year}-${day.month}-${day.day}',
);

/// 動画の再生時間の表示。
Key mediaPickerDurationKey(String path) => Key('media-picker-duration-$path');

/// 一覧を取れなかったときの表示と、やり直しの button。
const Key mediaPickerFailedKey = Key('media-picker-failed');
const Key mediaPickerRetryKey = Key('media-picker-retry');

/// 並ぶものが無いときの表示。
const Key mediaPickerEmptyKey = Key('media-picker-empty');

/// footer 左下の「← リネーム画面へ」。閉じると「決定していない」(REQ-008)。
const Key mediaPickerBackKey = Key('media-picker-back');

/// footer 右下の「確定」。1件以上選んでいるときだけ押せる(REQ-023)。
const Key mediaPickerConfirmKey = Key('media-picker-confirm');

/// 見出しの日付(004 REQ-022: 撮影日ごとの見出し)。
///
/// **今年なら年を省く。** `day` が `null`(MediaStore に日時が無い)なら「日付不明」。
String mediaDayLabel(DateTime? day, {required DateTime now}) {
  if (day == null) return '日付不明';
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  final weekday = weekdays[day.weekday - 1];
  final monthDay = '${day.month}月${day.day}日($weekday)';
  return day.year == now.year ? monthDay : '${day.year}年$monthDay';
}

/// 動画の再生時間(004 REQ-022: 写真と見分けられるよう示す)。`1:05`、`1:02:03`。
String mediaDurationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// 写真・動画の選択画面(004 REQ-022 / REQ-023。`010:T07`)。
///
/// 確定すると**選んだすべての写真・動画の path** を返す — 絞り込みで見えていない
/// 選択も含む(REQ-023)。閉じると `null`(決定していない。REQ-008)。
///
/// **形は app 内 browser に揃える**(`T07` の task.md の想定。2026-10-05 に開発者が
/// 「いったんこの案で」とした): header に `×`(選択中だけ)・題名・ケバブ、その下に
/// アルバムと種類の切り替え、日付の見出しの下にサムネイルの格子、footer に
/// 「← リネーム画面へ」と「確定」。**日付の見出しを押してその日をまとめて選ぶ
/// 操作は `T08`** で足す。
class MediaPickerView extends StatefulWidget {
  const MediaPickerView({
    super.key,
    required this.library,
    this.pageSize = 120,
    this.now,
  });

  final MediaLibraryPort library;

  /// 1回に取る件数。少しずつ読む(004「自由とする点」)。
  final int pageSize;

  /// 見出しの「今年」の判定に使う(test 用)。`null` なら現在時刻。
  final DateTime Function()? now;

  @override
  State<MediaPickerView> createState() => _MediaPickerViewState();
}

class _MediaPickerViewState extends State<MediaPickerView> {
  MediaFilter _filter = const MediaFilter();

  /// 今の絞り込みで読み込んだ item(新しい順)。
  final List<MediaItem> _items = [];
  bool _hasMore = true;
  bool _loadingPage = false;

  /// 最初の1ページの前か(読み込み中の表示に使う)。
  bool _firstPagePending = true;

  /// 今の絞り込みの一覧を取れなかった理由。
  String? _failure;

  /// 絞り込みを変えるたびに増やす。古い絞り込みの応答を捨てるため。
  int _generation = 0;

  /// 「すべて選択」のために残りを読んでいる間。
  bool _selectingAll = false;

  MediaAlbumsResult? _albums;

  /// **選択は path で持ち、絞り込みを変えても保つ**(REQ-022)。
  final LinkedHashSet<String> _selected = LinkedHashSet<String>();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  late final DragSelectionController<String> _dragSelection =
      DragSelectionController<String>(
        scrollController: _scrollController,
        viewportKey: _viewportKey,
        select: _selectPath,
        deselect: _deselectPath,
        isMounted: () => mounted,
        // 格子なので**表示順の範囲**で選ぶ(REQ-023)。
        displayOrder: () => [for (final item in _items) item.path],
      );

  late final MediaThumbnailCache _thumbnails = MediaThumbnailCache(
    widget.library,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _loadNextPage();
    _loadAlbums();
  }

  @override
  void dispose() {
    _dragSelection.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    MediaAlbumsResult albums;
    try {
      albums = await widget.library.albums();
    } catch (error) {
      albums = MediaAlbumsFailed('アルバムを取得できませんでした: $error');
    }
    if (mounted) setState(() => _albums = albums);
  }

  /// 次のページを読む。読めたら `true`。
  Future<bool> _loadNextPage() async {
    if (_loadingPage || !_hasMore) return false;
    final generation = _generation;
    setState(() => _loadingPage = true);
    MediaPageResult result;
    try {
      result = await widget.library.page(
        _filter,
        offset: _items.length,
        limit: widget.pageSize,
      );
    } catch (error) {
      // **port が投げても読み込み中で止まらない**(browser と同じ。約束に頼らない)。
      result = MediaPageFailed('写真・動画を取得できませんでした: $error');
    }
    if (!mounted || generation != _generation) return false;
    setState(() {
      _loadingPage = false;
      _firstPagePending = false;
      switch (result) {
        case MediaPage(:final items, :final hasMore):
          _items.addAll(items);
          _hasMore = hasMore;
          _failure = null;
        case MediaPageFailed(:final reason):
          _failure = reason;
      }
    });
    if (result is MediaPageFailed) return false;
    // 画面を埋めきらないうちは続けて読む。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    return true;
  }

  /// 末尾に近づいたら続きを読む。
  void _maybeLoadMore() {
    if (!mounted || _failure != null || _selectingAll) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 800) _loadNextPage();
  }

  /// 絞り込みを変える。**選択は保つ**(REQ-022)。
  void _changeFilter(MediaFilter filter) {
    _dragSelection.finish();
    // 前の絞り込みの item の位置の key を捨てる。残すと切り替えるたびに溜まる
    // (独立review attempt 1 の S-1)。
    _dragSelection.forgetRows();
    setState(() {
      _filter = filter;
      _generation++;
      _items.clear();
      _hasMore = true;
      _loadingPage = false;
      _firstPagePending = true;
      _failure = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadNextPage();
  }

  /// 取れなかった一覧を読み直す。
  void _retry() {
    setState(() => _failure = null);
    _loadNextPage();
  }

  void _toggle(MediaItem item) {
    setState(() {
      if (!_selected.remove(item.path)) _selected.add(item.path);
    });
  }

  void _selectPath(String path) {
    if (_selected.add(path) && mounted) setState(() {});
  }

  void _deselectPath(String path) {
    if (_selected.remove(path) && mounted) setState(() {});
  }

  /// **今の絞り込みで並ぶ item をすべて**選択に足す(REQ-023)。
  ///
  /// まだ読んでいない分があれば読み切ってから足す — 「並んでいる」は画面に
  /// 描いた分ではなく、今の絞り込みに当たる item である。読み切れなければ足さない
  /// (一部だけ選んで「すべて」と見せない)。
  Future<void> _selectAll() async {
    final generation = _generation;
    setState(() => _selectingAll = true);
    while (_hasMore && mounted && generation == _generation) {
      if (_loadingPage) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        continue;
      }
      if (!await _loadNextPage()) break;
    }
    if (!mounted) return;
    setState(() {
      _selectingAll = false;
      if (generation == _generation && !_hasMore && _failure == null) {
        _selected.addAll(_items.map((item) => item.path));
      }
    });
  }

  /// 選択をすべて解除する。**絞り込みで見えていない選択も外す**(REQ-023)。
  void _clearSelection() {
    _dragSelection.finish();
    setState(_selected.clear);
  }

  bool get _hasSelection => _selected.isNotEmpty;

  bool get _canSelectAll =>
      !_selectingAll &&
      _failure == null &&
      _items.isNotEmpty &&
      (_hasMore || !_items.every((item) => _selected.contains(item.path)));

  void _confirm() {
    Navigator.of(context).pop(_selected.toList());
  }

  Future<void> _openAlbumSheet() async {
    final colors = context.colors;
    final albums = _albums;
    final picked = await showModalBottomSheet<({int? id})>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'アルバム',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                key: mediaPickerAllAlbumsKey,
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colors.primary,
                ),
                title: Text(
                  'すべてのアルバム',
                  style: TextStyle(color: colors.textPrimary),
                ),
                selected: _filter.albumId == null,
                onTap: () => Navigator.of(sheetContext).pop((id: null)),
              ),
              switch (albums) {
                null => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // **取れなかったことを黙らせない。** アルバムが無いのか取れないのかを
                // 区別できるようにする。
                MediaAlbumsFailed(:final reason) => Padding(
                  key: const Key('media-picker-albums-failed'),
                  padding: const EdgeInsets.all(16),
                  child: Text(reason, style: TextStyle(color: colors.danger)),
                ),
                MediaAlbumsListed(albums: final list) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final album in list)
                      ListTile(
                        key: mediaPickerAlbumKey(album.id),
                        leading: SizedBox.square(
                          dimension: 40,
                          child: album.cover == null
                              ? Icon(Icons.folder, color: colors.textSecondary)
                              : _Thumbnail(
                                  item: album.cover!,
                                  loader: _thumbnails,
                                ),
                        ),
                        title: Text(
                          album.name,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                        subtitle: Text(
                          '${album.count}件',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: AppFontSize.label,
                          ),
                        ),
                        selected: _filter.albumId == album.id,
                        onTap: () =>
                            Navigator.of(sheetContext).pop((id: album.id)),
                      ),
                  ],
                ),
              },
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted || picked.id == _filter.albumId) return;
    _changeFilter(MediaFilter(kind: _filter.kind, albumId: picked.id));
  }

  /// 今のアルバムの名前。
  String get _albumLabel {
    final id = _filter.albumId;
    if (id == null) return 'すべてのアルバム';
    final albums = _albums;
    if (albums is MediaAlbumsListed) {
      for (final album in albums.albums) {
        if (album.id == id) return album.name;
      }
    }
    return 'アルバム';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        // **暗黙の戻るを出さない**(browser と同じ。閉じるのは footer だけ)。
        automaticallyImplyLeading: false,
        leading: _hasSelection
            ? IconButton(
                key: mediaPickerClearSelectionKey,
                icon: const Icon(Icons.close),
                tooltip: '選択をすべて解除',
                onPressed: _clearSelection,
              )
            : null,
        title: Text(
          key: mediaPickerTitleKey,
          _hasSelection ? '${_selected.length}件選択中' : '写真・動画',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [_menu(colors)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(colors),
          Expanded(child: _body(colors)),
          _footer(colors),
        ],
      ),
    );
  }

  Widget _menu(AppColors colors) => PopupMenuButton<VoidCallback>(
    key: mediaPickerMenuKey,
    icon: Icon(Icons.more_vert, color: colors.textSecondary),
    tooltip: 'その他の操作',
    onSelected: (action) => action(),
    itemBuilder: (context) => [
      PopupMenuItem<VoidCallback>(
        key: mediaPickerSelectAllKey,
        value: _selectAll,
        enabled: _canSelectAll,
        child: const Text('すべて選択'),
      ),
      if (_hasSelection)
        PopupMenuItem<VoidCallback>(
          key: mediaPickerMenuClearSelectionKey,
          value: _clearSelection,
          child: const Text('選択をすべて解除'),
        ),
    ],
  );

  /// アルバムと種類の切り替え(REQ-022)。
  Widget _filters(AppColors colors) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          key: mediaPickerAlbumButtonKey,
          onPressed: _openAlbumSheet,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(_albumLabel, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
        SegmentedButton<MediaKindFilter>(
          key: mediaPickerKindKey,
          showSelectedIcon: false,
          segments: [
            for (final kind in MediaKindFilter.values)
              ButtonSegment(
                value: kind,
                label: Text(
                  key: mediaPickerKindSegmentKey(kind),
                  switch (kind) {
                    MediaKindFilter.all => 'すべて',
                    MediaKindFilter.photos => '写真',
                    MediaKindFilter.videos => '動画',
                  },
                ),
              ),
          ],
          selected: {_filter.kind},
          onSelectionChanged: (selection) => _changeFilter(
            MediaFilter(kind: selection.single, albumId: _filter.albumId),
          ),
        ),
      ],
    ),
  );

  Widget _body(AppColors colors) {
    if (_firstPagePending && _failure == null) {
      return const Center(
        child: CircularProgressIndicator(key: Key('media-picker-loading')),
      );
    }
    final failure = _failure;
    if (failure != null && _items.isEmpty) {
      return Center(
        key: mediaPickerFailedKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                failure,
                style: TextStyle(color: colors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: mediaPickerRetryKey,
                onPressed: _retry,
                child: const Text('もう一度読み込む'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      final unfiltered =
          _filter.kind == MediaKindFilter.all && _filter.albumId == null;
      return Center(
        key: mediaPickerEmptyKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            unfiltered ? '写真・動画がありません' : 'この条件の写真・動画はありません',
            style: TextStyle(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final now = (widget.now ?? DateTime.now)();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _dragSelection.onPointerDown,
      onPointerMove: _dragSelection.onPointerMove,
      onPointerUp: _dragSelection.onPointerUp,
      onPointerCancel: _dragSelection.onPointerCancel,
      child: CustomScrollView(
        key: _viewportKey,
        controller: _scrollController,
        slivers: [
          for (final (day, items) in _groupByDay(_items)) ...[
            SliverToBoxAdapter(
              child: Padding(
                key: mediaPickerDayHeaderKey(day),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text(
                  mediaDayLabel(day, now: now),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _tile(colors, items[index]),
              ),
            ),
          ],
          SliverToBoxAdapter(child: _tail(colors)),
        ],
      ),
    );
  }

  /// 一覧の末尾。続きを読んでいる間・続きを取れなかったとき。
  Widget _tail(AppColors colors) {
    final failure = _failure;
    if (failure != null) {
      return Padding(
        key: mediaPickerFailedKey,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              failure,
              style: TextStyle(color: colors.danger),
              textAlign: TextAlign.center,
            ),
            TextButton(
              key: mediaPickerRetryKey,
              onPressed: _retry,
              child: const Text('もう一度読み込む'),
            ),
          ],
        ),
      );
    }
    // **読んでいる間だけ回す。** 続きがあるだけで回すと、画面外(先読みの範囲)で
    // 回り続ける。
    if (_loadingPage) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(height: _hasMore ? 64 : 16);
  }

  Widget _tile(AppColors colors, MediaItem item) {
    final selected = _selected.contains(item.path);
    final duration = item.duration;
    return GestureDetector(
      key: mediaPickerItemKey(item.path),
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(item),
      onLongPressStart: (details) => _dragSelection.start(
        item.path,
        details.globalPosition,
        baseline: Set<String>.of(_selected),
      ),
      child: Container(
        key: _dragSelection.rowGeometryKey(item.path),
        child: Semantics(
          selected: selected,
          label: item.kind == MediaKind.video ? '動画' : '写真',
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: colors.surfaceElevated,
                child: _Thumbnail(item: item, loader: _thumbnails),
              ),
              if (selected)
                ColoredBox(
                  color: colors.selectedSurface.withValues(alpha: 0.5),
                ),
              if (duration != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      child: Text(
                        key: mediaPickerDurationKey(item.path),
                        mediaDurationLabel(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSize.small,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                // 押下は item 全体で受ける(印だけ押させない)。
                child: IgnorePointer(
                  child: SelectionCheckbox(value: selected, onChanged: (_) {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// footer(browser と同じ形)。閉じる導線は「← リネーム画面へ」だけ。
  Widget _footer(AppColors colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: colors.bar,
      border: Border(top: BorderSide(color: colors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: OutlinedButton.icon(
              key: mediaPickerBackKey,
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.background,
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
              ),
              // **決定していない**(REQ-008)。未確定の選択は捨てる。
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('リネーム画面へ', overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: mediaPickerConfirmKey,
            onPressed: _hasSelection ? _confirm : null,
            child: const Text('確定'),
          ),
        ],
      ),
    ),
  );
}

/// [items](新しい順)を日ごとにまとめる。日時が無いものは「日付不明」(`null`)。
List<(DateTime?, List<MediaItem>)> _groupByDay(List<MediaItem> items) {
  final groups = <(DateTime?, List<MediaItem>)>[];
  for (final item in items) {
    final date = item.date;
    final day = date == null ? null : DateTime(date.year, date.month, date.day);
    if (groups.isNotEmpty && groups.last.$1 == day) {
      groups.last.$2.add(item);
    } else {
      groups.add((day, [item]));
    }
  }
  return groups;
}

/// サムネイルを同時に頼みすぎないよう数を絞り、作ったものを覚えておく。
///
/// 速く scroll すると数百件を一度に頼むことになる。Kotlin 側は thread pool で
/// 受けるので、ここで同時に走る数を抑える。
///
/// **覚えるのは最近使った [maxEntries] 件まで**(古いものから捨てる)。写真の多い端末で
/// 絞り込みを何度も切り替えると、上限が無ければ 256px の bytes が際限なく溜まる
/// (独立review attempt 1 の S-2)。
class MediaThumbnailCache {
  MediaThumbnailCache(this.library, {this.maxEntries = 400});

  final MediaLibraryPort library;
  final int maxEntries;
  static const _maxConcurrent = 6;
  static const _maxEdge = 256;

  /// 挿入順 = 使った順(使うたびに末尾へ移す)。
  final LinkedHashMap<int, Future<Uint8List?>> _cache = LinkedHashMap();
  final List<Completer<void>> _waiting = [];
  int _running = 0;

  /// 今覚えている件数。
  @visibleForTesting
  int get length => _cache.length;

  Future<Uint8List?> of(MediaItem item) {
    final cached = _cache.remove(item.id);
    final future = cached ?? _load(item);
    _cache[item.id] = future;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<Uint8List?> _load(MediaItem item) async {
    if (_running >= _maxConcurrent) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    try {
      return await library.thumbnail(item, maxEdge: _maxEdge);
    } catch (_) {
      return null;
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.loader});

  final MediaItem item;
  final MediaThumbnailCache loader;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<Uint8List?>(
      future: loader.of(item),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          // **作れないときも item は並べ、選べる。** 種類のアイコンを出す。
          return Center(
            child: Icon(
              item.kind == MediaKind.video
                  ? Icons.movie_outlined
                  : Icons.image_outlined,
              color: colors.textMuted,
            ),
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.broken_image_outlined, color: colors.textMuted),
        );
      },
    );
  }
}
