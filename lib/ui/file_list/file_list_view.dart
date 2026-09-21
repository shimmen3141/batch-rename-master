import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/rename_engine.dart';
import '../../data/file_source/file_source.dart';
import '../../data/preview/file_preview.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../file_source/source_path_text.dart';
import '../rename_exec/rename_execution_controller.dart';
import '../theme/app_colors.dart';
import 'file_list_controller.dart';
import 'file_sort.dart';
import 'header_metrics.dart';
import 'removal_hint.dart';
import 'removal_selection.dart';
import 'removal_undo.dart';
import 'rename_warning_view.dart';
import 'row_preview_view.dart';
import 'row_view.dart';

/// 更新日時ずらしの設定(005 REQ-014。書ける端末でだけ出る)。
const Key shiftModifiedAtKey = Key('shift-modified-at');

/// 一覧の総件数(002 REQ-016)。**選択された件数ではない** — 一覧にある
/// ファイルはすべて rename 対象である。
const Key fileCountKey = Key('file-count');

/// 一覧のケバブメニュー(`008:T29`)。**通常表示でもモード中でも同じ位置に出る。**
const Key listMenuKey = Key('list-menu');

/// ケバブの「外すファイルを選ぶ」(002 REQ-018 の入口(b))。
///
/// **長押しに依存しない入口が要る。** 長押しは Flutter ではマウスでも発火するが、
/// **押せることが画面から読めない**(支援技術からも辿りにくい)。一覧が空でない間は
/// 常にここから入れる(代表例 6j)。**メニューの項目でもこの要求は満たす** —
/// (b) が課しているのは「マウスと支援技術から操作できる」ことである。
const Key removalModeEnterKey = Key('menu-enter-removal');

/// ケバブの「すべて選択」。全件を外す候補にしてモードへ入る。
const Key menuSelectAllKey = Key('menu-select-all');

/// ケバブの「すべてをリネーム対象から外す」(004 REQ-006 の `clearFiles`)。
///
/// **`008:T29` で読み込み帯の `一覧を空にする` から移した。**
const Key menuClearAllKey = Key('menu-clear-all');

/// 選択モードをやめる(002 REQ-018)。一覧は変わらない(代表例 6i)。
const Key removalModeExitKey = Key('removal-mode-exit');

/// 選択モードで選ばれている件数(002 REQ-018)。
const Key removalModeCountKey = Key('removal-mode-count');

/// 選ばれた行を一覧から外す(002 REQ-018)。0 件では押せない。
const Key removalModeRemoveKey = Key('removal-mode-remove');

/// 並び替えで**掴まれている行**(`008:T32`)。掴んでいる間だけ在る。
const Key draggingRowKey = Key('dragging-row');

/// 選択モードで [handle] の行に出る選択の切り替え(002 REQ-018)。
Key removalMarkKeyOf(String handle) => ValueKey('removal-mark:$handle');

/// 行サブ情報の場所(002 REQ-010)。行ごとに1つで、場所を持たない行には無い。
///
/// **一覧に複数の場所が混ざっているときだけ出る**(002 の決定。2026-09-18 に開発者が
/// 再承認。代表例 7b・7c / `008:T22`)。1つだけなら読み込み帯が一覧全体として示す。
const Key rowLocationKey = Key('row-location');

/// 行サブ情報の作成日時(002 REQ-013)。**並び順chipや代替警告と同じ語を含む**ため、
/// testが行の中の日時だけを指せるようにkeyを持たせる。
const Key rowCreatedAtKey = Key('row-created-at');

/// 行サブ情報の更新日時。狭幅では作成日時より先に削られる側である(008:T07)。
const Key rowModifiedAtKey = Key('row-modified-at');

/// メイン画面のファイルリスト(002 spec の描画層)。
///
/// [FileListController] を購読して描画するだけの薄いウィジェット。ロジックは
/// 持たず、操作は controller のメソッドへ委譲する。各行はチェックボックスの右へ
/// 現在名・変更後名・サブ情報を**縦に積み**(参考designのリッチな行。008:T07 で
/// 横2カラムから移した)、上部にソート切替チップを置く。
/// 視覚は参考デザインに準拠し、色は [AppColors] のセマンティック名で参照する。
class FileListView extends StatefulWidget {
  const FileListView({
    super.key,
    required this.controller,
    this.renameExecution,
    this.onEditRule,
    this.filePreview,
    this.removalSelection,
  });

  final FileListController controller;
  final RenameExecutionController? renameExecution;

  /// 行の preview の供給元(008:T07)。`null` なら種別アイコンだけを出す。
  ///
  /// **`null` が既定である。** demo データや preview を持たない画面で、実 file を
  /// 触ろうとしないようにするためである。
  final FilePreviewPort? filePreview;

  /// ルール編集を開く導線(REQ-020 の「ルールを設定すれば進める」)。
  ///
  /// ルールビルダーが常時見えているレイアウト(デスクトップの 2 ペイン)では
  /// `null` を渡し、下部バーには実行だけを置く。
  final VoidCallback? onEditRule;

  /// 除去のための選択モードの状態(002 REQ-018)。
  ///
  /// **`null` なら自分で1つ持つ。** 一覧だけを描く画面(testや部分的な組み立て)では
  /// それで足りる。**製品では composition root が1つ作って読み込み帯とも共有する** —
  /// モード中は帯の `別フォルダへ` と下部の帯も隠れるためである(`008:T29`)。
  final RemovalSelection? removalSelection;

  @override
  State<FileListView> createState() => _FileListViewState();
}

/// 除去のための選択モードの状態(002 REQ-018)。
///
/// **[FileListController] へ置かない。** controller の選択(`toggleSelection` /
/// `selectedCount`)は **rename 対象の選択**で、製品 UI では常に全件である
/// (REQ-004 / REQ-016)。ここで選ぶのは**これから外す候補**で、モードを抜ければ
/// 消える別物なので、同じ状態へ混ぜると「外す候補にしただけで rename から外れる」
/// 振る舞いになりうる(代表例 6f・6i)。
///
/// **ハンドルで覚える。** 項目は改名や読み込み直しで別の値へ入れ替わるが
/// (005 REQ-018 / 004 REQ-004)、ハンドルは同じファイルを指す識別子である。
/// 覚えたハンドルが一覧から消えていれば、そのときの表示では数に入れない。
class _FileListViewState extends State<FileListView> {
  /// 外から渡されなかったときに自分で持つ状態(`008:T29`)。
  RemovalSelection? _own;

  RemovalSelection get _selection =>
      widget.removalSelection ?? (_own ??= RemovalSelection());

  /// 外すアイコンと補足の吹き出しを結ぶ(`008:T30`)。**吹き出しは `Overlay` にある**ので、
  /// 座標を計算せずこの link が位置を決める。
  final LayerLink _hintLink = LayerLink();

  /// スクロール位置と表示領域。ドラッグ中に実際に描画された行だけを拾う。
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _listViewportKey = GlobalKey();
  final GlobalKey _renameActionBarKey = GlobalKey();
  final Map<String, GlobalKey> _rowGeometryKeys = <String, GlobalKey>{};

  _DragSelectionSession? _dragSelection;
  final Map<int, Offset> _pointerPositions = <int, Offset>{};
  int? _dragPointer;
  Timer? _autoScrollTimer;
  double _autoScrollPixelsPerTick = 0;
  double _selectionViewportBottomPadding = 0;
  bool _traceAfterScrollPending = false;

  static const double _autoScrollEdgeExtent = 48;
  static const double _autoScrollStep = 4;
  static const double _maxAutoScrollMultiplier = 4;

  @override
  void dispose() {
    _finishDragSelection();
    _listScrollController.dispose();
    // **自分で作ったものだけ捨てる。** 渡されたものは composition root の持ち物で、
    // 読み込み帯も同じものを読んでいる。
    _own?.dispose();
    super.dispose();
  }

  GlobalKey _rowGeometryKey(String handle) =>
      _rowGeometryKeys.putIfAbsent(handle, GlobalKey.new);

  void _startDragSelection(String handle, Offset position) {
    // Pointer の move/up/cancel は行の GestureDetector ではなく list 親の
    // Listener が受け続ける。長距離 scroll で開始行が dispose されても、
    // session と timer に古い座標が残らない。
    final pointer = _nearestPointerTo(position);
    _finishDragSelection();
    _dragPointer = pointer;
    final baseline = _selection.marked;
    if (_selection.selecting) {
      _selection.mark(handle);
    } else {
      // 選択モードへ入ると下部の rename UI が隠れ、list の viewport が広がる。
      // 最下部を見ていると scroll extent が縮んで開始行が下へ跳ぶため、消える
      // UI と同じ高さを list の末尾余白として先に確保する。
      _selectionViewportBottomPadding = _renameActionBarHeight;
      _selection.enter(handle: handle);
    }
    final session = _DragSelectionSession(baseline, position);
    _dragSelection = session;
    session.visit(handle, _selection);
    _updateAutoScroll(position);
  }

  int? _nearestPointerTo(Offset position) {
    int? result;
    var distance = double.infinity;
    for (final entry in _pointerPositions.entries) {
      final candidate = (entry.value - position).distanceSquared;
      if (candidate < distance) {
        result = entry.key;
        distance = candidate;
      }
    }
    return result;
  }

  void _onListPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
  }

  void _onListPointerMove(PointerMoveEvent event) {
    _pointerPositions[event.pointer] = event.position;
    if (event.pointer == _dragPointer) _moveDragSelection(event.position);
  }

  void _onListPointerUp(PointerUpEvent event) {
    _pointerPositions.remove(event.pointer);
    if (event.pointer == _dragPointer) _finishDragSelection();
  }

  void _onListPointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (event.pointer == _dragPointer) _finishDragSelection();
  }

  void _moveDragSelection(Offset position) {
    final session = _dragSelection;
    if (session == null) return;
    _traceSelection(session, position);
    _updateAutoScroll(position);
  }

  void _traceSelection(_DragSelectionSession session, Offset position) {
    for (final crossing in _rowsCrossed(session.pointer, position)) {
      session.visit(crossing.handle, _selection);
    }
    session.pointer = position;
  }

  List<_RowCrossing> _rowsCrossed(Offset from, Offset to) {
    final crossings = <_RowCrossing>[];
    for (final entry in _rowGeometryKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final origin = renderObject.localToGlobal(Offset.zero);
      final t = _segmentEntry(
        Rect.fromLTWH(
          origin.dx,
          origin.dy,
          renderObject.size.width,
          renderObject.size.height,
        ),
        from,
        to,
      );
      if (t != null) crossings.add(_RowCrossing(entry.key, t));
    }
    crossings.sort((a, b) => a.t.compareTo(b.t));
    return crossings;
  }

  void _updateAutoScroll(Offset position) {
    final viewport = _viewportRect;
    if (viewport == null ||
        position.dx < viewport.left ||
        position.dx > viewport.right) {
      _stopAutoScroll();
      return;
    }

    // 指が header へ入っても上方向の選択 drag は続く。viewport の内側だけに
    // 限ると、実機では最上行を越えた瞬間に scroll が止まる。端からの深さで
    // step を増やすので、header へ近づき越えるほど速くなる。
    final aboveTopEdge = viewport.top + _autoScrollEdgeExtent - position.dy;
    final belowBottomEdge =
        position.dy - (viewport.bottom - _autoScrollEdgeExtent);
    _autoScrollPixelsPerTick = aboveTopEdge > 0
        ? -_scrollStepForDepth(aboveTopEdge)
        : (belowBottomEdge > 0 ? _scrollStepForDepth(belowBottomEdge) : 0);
    if (_autoScrollPixelsPerTick == 0 ||
        !_canAutoScroll(_autoScrollPixelsPerTick)) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  double get _renameActionBarHeight {
    final renderObject = _renameActionBarKey.currentContext?.findRenderObject();
    return renderObject is RenderBox && renderObject.attached
        ? renderObject.size.height
        : 0;
  }

  double _scrollStepForDepth(double depth) =>
      _autoScrollStep *
      (depth / _autoScrollEdgeExtent).clamp(1, _maxAutoScrollMultiplier);

  Rect? get _viewportRect {
    final renderObject = _listViewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      origin.dx,
      origin.dy,
      renderObject.size.width,
      renderObject.size.height,
    );
  }

  bool _canAutoScroll(double direction) {
    if (!_listScrollController.hasClients) return false;
    final position = _listScrollController.position;
    return direction < 0
        ? position.pixels > position.minScrollExtent
        : position.pixels < position.maxScrollExtent;
  }

  void _autoScrollTick() {
    final session = _dragSelection;
    if (session == null || !_canAutoScroll(_autoScrollPixelsPerTick)) {
      _stopAutoScroll();
      return;
    }
    final position = _listScrollController.position;
    final next = (position.pixels + _autoScrollPixelsPerTick).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) {
      _stopAutoScroll();
      return;
    }
    _listScrollController.jumpTo(next);
    if (_traceAfterScrollPending) return;
    _traceAfterScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _traceAfterScrollPending = false;
      if (mounted && identical(session, _dragSelection)) {
        _traceSelection(session, session.pointer);
      }
    });
  }

  void _finishDragSelection() {
    _dragSelection = null;
    _dragPointer = null;
    _stopAutoScroll();
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollPixelsPerTick = 0;
  }

  void _exitRemovalMode() {
    _finishDragSelection();
    _selectionViewportBottomPadding = 0;
    _selection.exit();
  }

  /// 選ばれた行をまとめて外す(REQ-018)。
  ///
  /// **1回の取り消しで全件が元の位置へ戻る**(代表例 6h)。[removeUndoably] は
  /// 除去の**前後**を1組の控えとして見るので、除去をこの closure の中で
  /// まとめて済ませれば、通知も取り消しも1回で足りる。
  ///
  /// **`setFiles` で残りへ置き換えない。** `setFiles` は占有名を捨てるので
  /// (005 REQ-026)、外しただけで一覧の重複警告が弱くなり、控えの照合も
  /// 毎回「古い」と判定される。`removeFile` の反復は占有名に触れない。
  void _removeMarked(BuildContext context, Set<String> handles) {
    removeUndoably(context, widget.controller, () {
      for (final handle in handles) {
        widget.controller.removeFile(handle);
      }
    });
    _exitRemovalMode();
  }

  /// 一覧を空にする(004 REQ-006)。**取り消せる形で行う**(002 REQ-017)。
  ///
  /// `008:T29` で読み込み帯の `一覧を空にする` からケバブへ移した。
  void _clearAll(BuildContext context) {
    removeUndoably(context, widget.controller, widget.controller.clearFiles);
    _exitRemovalMode();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        _selection,
        ?widget.renameExecution,
      ]),
      builder: (context, _) {
        // 行データと警告は同じ検証から作れる。ビルド1回につき一度だけ評価する
        // (`rows` と `warnings` を別々に呼ぶと 001 の検証が2回走る)。
        final preview = widget.controller.preview;
        final rows = preview.rows;
        final warnings = preview.warnings;
        // 005 REQ-020: ルールが空なら警告を提示しない。**行にも出さない。**
        final ruleIsEmpty = widget.controller.isRuleEmpty;
        // 002 の決定(2026-09-18 再承認・`008:T22`): 行が場所を表示するのは
        // **一覧に複数の場所が混ざっているときだけ**である。1つだけなら読み込み帯が
        // 一覧全体として示すので、全行へ同じ名前が並ぶのは冗長になる(代表例 7b・7c)。
        //
        // **ここで1回だけ数える。** 行ごとに数えると一覧の長さの2乗で効く。
        final showRowLocation =
            rows
                .map((r) => r.source.sourceLocation)
                .whereType<String>()
                .toSet()
                .length >
            1;
        // **いま外せる行のハンドル**。控えたハンドルがもう一覧に無いことがある
        // (取り消しの通知を出したまま読み込み直した場合など)。
        final removable = <String>{
          for (final row in rows) ?row.source.sourceHandle,
        };
        final marked = _selection.markedAmong(removable);
        // **一覧が空ならモードは成り立たない**(選ぶものが無く、REQ-018 の入口も
        // 「一覧が空でない間」である)。描画を畳むだけでなく、**状態も片付ける**。
        //
        // 畳んだ画面にはヘッダの × が無いので、**利用者には片付ける手段が無い**。
        // 状態を残すと「一覧を空にする → 元に戻す」で**誰も押していないのに
        // モードが戻り、前の外す候補が選択済みで復活する**(独立reviewが製品構成で
        // 実測した)。`build` の中では `setState` を呼べないので frame の後に回す。
        final selecting = _selection.selecting && rows.isNotEmpty;
        if (_selection.selecting && rows.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selection.selecting) _selection.exit();
          });
        }
        // **見えている0件と内部の0件を揃える**(`008:T29`)。改名の取り消しや
        // 読み込み直しで候補が一覧から消えると、画面は「0件選択中」なのに
        // 内部には残っていて「0件で抜ける」が効かない(独立review attempt 1 の P3)。
        else if (_selection.selecting &&
            marked.length != _selection.marked.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _selection.retain(removable);
          });
        }
        return PopScope(
          // 端末の戻るは**モードをやめる**に使う(画面を閉じない)。REQ-018 の
          // 「やめる操作」はヘッダの × が満たすが、選択モードから戻るの期待は強い。
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _exitRemovalMode();
          },
          child: Container(
            color: colors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBar(
                  controller: widget.controller,
                  // 一覧全体の件数(005 REQ-009 (3) の入口)。**常時 1 行に収まり、
                  // 一覧を覆わない** — 集約帯を廃止した狙いがこれである。
                  warnings: ruleIsEmpty ? const <Warning>[] : warnings,
                  selecting: selecting,
                  markedCount: marked.length,
                  // **一覧が空でない間は常に入れる**(入口(b)。代表例 6j)。
                  // 外せる行の有無で出し入れしない — ヘッダの構成が一覧の中身で
                  // 変わるし、REQ-018 が課しているのは「一覧が空でない間」である。
                  // ハンドルを持つ行が無ければ、入っても 0 件で外せないだけになる。
                  onEnterRemovalMode: rows.isEmpty
                      ? null
                      : () => _selection.enter(),
                  onSelectAll: removable.isEmpty
                      ? null
                      : () => _selection.selectAll(removable),
                  onClearAll: rows.isEmpty ? null : () => _clearAll(context),
                  onExitRemovalMode: _exitRemovalMode,
                  // 0 件では外せない(REQ-018)。
                  onRemoveMarked: marked.isEmpty
                      ? null
                      : () => _removeMarked(context, marked),
                  hintLink: _hintLink,
                ),
                // 外すアイコンへ重ねる補足(`008:T30`)。**自分では何も描かず**、
                // `Overlay` へ出して帯をまたぐ。モードをやめた瞬間に消える。
                RemovalHintAnchor(link: _hintLink, visible: selecting),
                _SortBar(controller: widget.controller, selecting: selecting),
                _CreatedAtFallbackBanner(
                  warning: widget.controller.createdAtSortWarning,
                ),
                // ルールが空なら警告ではなく未設定を提示する(005 REQ-020)。
                // トークンが加われば自動でこの分岐が戻り、通常の警告提示になる。
                if (ruleIsEmpty) const RuleNotConfiguredBanner(),
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onListPointerDown,
                    onPointerMove: _onListPointerMove,
                    onPointerUp: _onListPointerUp,
                    onPointerCancel: _onListPointerCancel,
                    child: ReorderableListView.builder(
                      key: _listViewportKey,
                      scrollController: _listScrollController,
                      // 選択開始で下部 action bar を隠しても、開始行の画面座標を
                      // 保つため、消えた高さを list の末尾余白として残す。
                      padding: EdgeInsets.only(
                        bottom: selecting ? _selectionViewportBottomPadding : 0,
                      ),
                      // ドラッグは行末尾のハンドルからのみ開始する(行の長押しや
                      // 行タップと衝突させない)。**既定の長押しドラッグを切って
                      // あることが、選択モードの長押しの前提でもある。**
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      // onReorderItem は newIndex を削除後の挿入先へ調整済みで渡す。
                      onReorderItem: widget.controller.reorder,
                      // **掴めた行を面の色で示す**(2026-09-19 の要望。`008:T32`)。
                      // いま掴めたのかどうかが分からないまま動かすことになっていた。
                      //
                      // **選択モードの選択行(`selectedSurface`)とは別の色にする** —
                      // 別々の状態が同じ見た目になると、`008:T29` で分けた区別が戻る。
                      // モード中はつまみを出さない(REQ-018)ので同時には起きないが、
                      // 色が同じなら「掴んでいる」と「選んでいる」が読み分けられない。
                      //
                      // **影は既定と同じように上げる。** 面の色を足すだけにして、
                      // 浮き上がりという手掛かりを減らさない。
                      proxyDecorator: (child, index, animation) =>
                          AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) => Material(
                              key: draggingRowKey,
                              color: colors.surface,
                              shadowColor: colors.background,
                              elevation:
                                  Curves.easeInOut.transform(animation.value) *
                                  6,
                              child: child,
                            ),
                            child: child,
                          ),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final handle = row.source.sourceHandle;
                        return _FileRow(
                          // ReorderableListView は各子に安定 Key を要求する。
                          // FileEntry は同一性で扱う値なので ValueKey で追従する。
                          key: ValueKey(row.source),
                          index: index,
                          row: row,
                          // 並び順が出力に効くのは連番があるときだけ(REQ-014)。
                          // **モード中に出さない判定は行側が持つ** — 枠を
                          // checkbox と取り合うので、同じ場所で決めないと
                          // 「どちらも出ない」「両方出る」が作れてしまう。
                          showDragHandle: widget.controller.manualOrderMatters,
                          sortMode: widget.controller.sortMode,
                          showLocation: showRowLocation,
                          filePreview: widget.filePreview,
                          // 005 REQ-009 (1): 種別が**展開操作を経ずに**読める。
                          warnings: rowWarningsOf(
                            row.warnings,
                            ruleIsEmpty: ruleIsEmpty,
                          ),
                          ruleIsEmpty: ruleIsEmpty,
                          // 005 REQ-009 (4): **行から開くのはその行の警告だけ。**
                          // 全件は件数表示から開く(2026-09-02 の要望2)。
                          onShowWarningDetail: () => showWarningDetail(
                            context,
                            row.warnings,
                            ruleIsEmpty: ruleIsEmpty,
                            scopeFile: row.source,
                            // 同名が一覧に並ぶときだけ場所を添える。**母集合は
                            // 一覧のファイル**(警告を持つものだけだと、同名2件の
                            // 片方だけが警告されたときに見分けられない)。
                            amongFiles: widget.controller.rows.map(
                              (r) => r.source,
                            ),
                          ),
                          selecting: selecting,
                          marked: handle != null && marked.contains(handle),
                          rowGeometryKey: handle == null
                              ? null
                              : _rowGeometryKey(handle),
                          // **元場所ハンドルを持つ行だけ外せる**(004 REQ-006 は
                          // ハンドルで対象を指す)。持たない行は選べない —
                          // 選べるのに外れない件数を出すほうが悪い。
                          onToggleMark: handle == null
                              ? null
                              : () => _selection.toggle(handle),
                          onLongPressStart: handle == null
                              ? null
                              : (position) =>
                                    _startDragSelection(handle, position),
                        );
                      },
                    ),
                  ),
                ),
                // 参考デザインどおり、ルール設定と実行はリストより下の固定バーへ
                // まとめる(T09 で T04 の上部配置から移設)。
                //
                // 005 REQ-009 (2) の原因の提示は、**バーの手前へ積まない。**
                // 独立した子として積むと、原因の数 × 文字倍率で伸びて一覧と
                // 下部バーを押し出した(独立review attempt 3 のP1-1)。参考designの
                // ルール設定buttonが持つ「命名ルール」見出しの右へ、**種別だけ**を
                // 載せる。**広幅では下部バーに導線が無い**ため、
                // `RuleBuilderWorkspace` が右ペイン側へ同じものを描く。
                // **モード中は下部の帯を隠す**(2026-09-19 の要望7)。モードは外す
                // 作業に専念させる。005 は提示の場所・文言・UI部品を自由とする点に
                // 残しており、REQ-019 が課すのは「実行が始まらない・実ファイルを
                // 1件も変えない」という振る舞いである。
                if (!selecting &&
                    (widget.renameExecution != null ||
                        widget.onEditRule != null))
                  _RenameActionBar(
                    key: _renameActionBarKey,
                    controller: widget.controller,
                    execution: widget.renameExecution,
                    onEditRule: widget.onEditRule,
                    warnings: ruleIsEmpty ? const <Warning>[] : warnings,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 1回の長押しドラッグの経路と、開始時から保護する候補を持つ。
class _DragSelectionSession {
  _DragSelectionSession(Set<String> baseline, this.pointer)
    : _baseline = Set<String>.of(baseline);

  final Set<String> _baseline;
  final List<String> _path = <String>[];
  Offset pointer;

  /// 到達済み行へ戻った場合は、その後にこのドラッグが足した行だけを外す。
  void visit(String handle, RemovalSelection selection) {
    final previous = _path.lastIndexOf(handle);
    if (previous >= 0) {
      final leaving = _path.sublist(previous + 1);
      _path.removeRange(previous + 1, _path.length);
      for (final left in leaving) {
        if (!_baseline.contains(left)) selection.unmark(left);
      }
      return;
    }
    _path.add(handle);
    selection.mark(handle);
  }
}

class _RowCrossing {
  const _RowCrossing(this.handle, this.t);

  final String handle;
  final double t;
}

/// 線分が [rect] に初めて入る比率を返す。行高を仮定せず、画面へ実描画された
/// 矩形だけで判定する。入らなければ `null`。
double? _segmentEntry(Rect rect, Offset from, Offset to) {
  var first = 0.0;
  var last = 1.0;
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;

  bool clip(double p, double q) {
    if (p == 0) return q >= 0;
    final ratio = q / p;
    if (p < 0) {
      if (ratio > last) return false;
      if (ratio > first) first = ratio;
    } else {
      if (ratio < first) return false;
      if (ratio < last) last = ratio;
    }
    return true;
  }

  if (!clip(-dx, from.dx - rect.left) ||
      !clip(dx, rect.right - from.dx) ||
      !clip(-dy, from.dy - rect.top) ||
      !clip(dy, rect.bottom - from.dy)) {
    return null;
  }
  return first;
}

/// リストの下に固定するアクションバー(参考デザインの下部バー)。
///
/// 上段にルール設定への導線、下段に実行を置く。ルールが空のときは実行を無効に
/// したうえで、ルール設定ボタンを主役の表示へ入れ替える(005 REQ-019 / REQ-020)。
class _RenameActionBar extends StatelessWidget {
  const _RenameActionBar({
    super.key,
    required this.controller,
    required this.execution,
    required this.onEditRule,
    required this.warnings,
  });

  final FileListController controller;

  /// 実行境界。デモやリスト単体の描画では `null`(実行ボタンを出さない)。
  final RenameExecutionController? execution;
  final VoidCallback? onEditRule;

  /// ルール設定buttonへ載せる警告(005 REQ-009 (2))。ルールが空なら空で渡る。
  final List<Warning> warnings;

  Future<void> _request(BuildContext context) async {
    final execution = this.execution;
    // REQ-019: **変更が生じるファイルが0件なら実行を要求しても開始しない**
    // (controller 側でも止める)。空ルールはこの0件に含まれるが、それだけではない。
    if (execution == null ||
        execution.isRunning ||
        !controller.hasChangedFiles) {
      return;
    }
    // REQ-028: 占有名を**実行を要求したこの時点で取り直す**。読み込み時の観測で
    // 判定すると、そのあと他processが作ったfileとの衝突が事前検出をすり抜ける。
    final prepared = await execution.prepare();
    if (prepared is OccupiedNamesUnavailable) {
      // REQ-027: 実在名を取得できなかったfolderがある。**実行を行わず理由を出す。**
      // 「取得できなかった」を「衝突が無い」と読まない。
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('rename-occupied-names-unavailable'),
          content: Text(_unavailableMessage(prepared.reasons)),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final occupiedNames = (prepared as OccupiedNamesReady).names;

    // 確認ダイアログも帯と同じ提示単位を使う(REQ-021 のまとめを両方へ効かせる)。
    // `prepare` が取り直した占有名を `controller` へ反映済みなので、この警告には
    // 占有名との衝突が含まれる(REQ-026 / REQ-028)。
    final warnings = presentWarnings(
      controller.warnings,
      amongFiles: controller.rows.map((r) => r.source),
    );
    if (warnings.isNotEmpty) {
      final force = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('rename-confirmation-dialog'),
          title: const Text('警告を確認してください'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final warning in warnings) Text('• ${warning.message}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('rename-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('rename-force'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('強制実行'),
            ),
          ],
        ),
      );
      if (force != true || !context.mounted) return;
      await _run(context, force: true, occupiedNames: occupiedNames);
      return;
    }
    await _run(context, force: false, occupiedNames: occupiedNames);
  }

  /// 実在名を取得できなかった folder の提示文(REQ-027)。
  ///
  /// **どのfolderがなぜ駄目かを出す。** 件数だけでは利用者が直しようがない。
  static String _unavailableMessage(Map<String?, PickError> reasons) {
    final lines = [
      for (final entry in reasons.entries)
        '${entry.key ?? '(場所不明)'}: ${entry.value.message ?? entry.value.kind.name}',
    ];
    return 'フォルダ内のファイル名を確認できないため実行しませんでした。'
        '${lines.join(' / ')}';
  }

  /// 結果の本文。再採番が起きた項目は**全件**を並べる(REQ-024)。
  ///
  /// 件数だけでは「どれが変わったか」が分からず、先頭数件で打ち切ると
  /// **残りは黙って別の名前になる**。多いときは高さを制限してスクロールさせ、
  /// 落とさない。
  Widget _resultContent(String summary, List<SuccessfulRename> renumbered) {
    if (renumbered.isEmpty) return Text(summary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 96),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in renumbered)
                  Text('${s.confirmedName} → ${s.newName}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context, {
    required bool force,
    required OccupiedNames occupiedNames,
  }) async {
    final execution = this.execution!;
    final outcome = await execution.execute(
      force: force,
      occupiedNames: occupiedNames,
    );
    if (!context.mounted) return;
    // 権限が取り消されていた場合(013 REQ-004)。**黙って何も起きない**のは
    // 「壊れている」ように見えるので、理由を出す。実体には触れていない(INV-002)。
    if (execution.permissionDenied) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const Key('execute-permission-denied'),
          content: const Text(
            '「すべてのファイルへのアクセス」が許可されていないため、名前を変更できませんでした。'
            '端末の設定で許可してから、もう一度お試しください。',
          ),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    if (outcome == null) return;
    final message = StringBuffer('${outcome.successes.length} 件を改名しました');
    final excluded = execution.excludedEmptyNames.length;
    if (excluded > 0) message.write('。名前が空になるため $excluded 件を除外しました');
    // REQ-024: 実行中に再採番が起きた項目は、確認した名前と結果名が違う。
    // **黙って別の名前にしない** — 何件がどの名前になったかを示す。件数だけだと
    // 「どれが変わったか」が分からないので、少数なら名前を並べる。
    final renumbered = [
      for (final success in outcome.successes)
        if (success.renumbered) success,
    ];
    if (renumbered.isNotEmpty) {
      message.write('。実行中に名前が使われていたため ${renumbered.length} 件の名前が変わりました');
    }
    final failure = outcome.failure;
    if (failure != null) {
      message.write('。失敗: ${failure.error.message ?? failure.error.kind.name}');
    }
    // 更新日時の設定失敗は改名の失敗と分けて書く。混ぜると「改名できたのか」が
    // 読めなくなる(REQ-016)。
    final shiftFailures = execution.modifiedAtFailures.length;
    if (shiftFailures > 0) {
      message.write('。改名は成功しましたが、$shiftFailures 件の更新日時は変更できませんでした');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // **固定 key を付けない。** `showSnackBar` は key が null のときだけ
        // `UniqueKey` を fallback に入れ、連続する snackbar が構造的に一致した
        // ときの ink splash / highlight の持ち越しを防いでいる。結果トーストは
        // undo ボタンを含むので、固定 key を付けるとその持ち越しが起きうる。
        // 到達の観測は本文(「N 件を改名しました」)で足りる。
        content: _resultContent(message.toString(), renumbered),
        // undo はこのトースト内に置く(参考デザインどおり)。下部バーへ置くと
        // 結果トーストがバーを覆い、取り消せる 5 秒の間だけ押せなくなる。
        duration: execution.undoWindow,
        // action があると既定で消えなくなる(persist)。undo は 5 秒で期限切れ
        // (REQ-007)なので、押せなくなった undo を残さないよう明示的に消す。
        persist: false,
        action: execution.canUndo
            ? SnackBarAction(
                key: const Key('rename-undo'),
                label: '元に戻す',
                onPressed: () => _undo(context),
              )
            : null,
      ),
    );
  }

  Future<void> _undo(BuildContext context) async {
    final execution = this.execution!;
    final outcome = await execution.undo();
    if (!context.mounted) return;
    // undo も書き込みなので、権限が取り消されていれば断る(013 INV-002)。
    // **黙って何も起きない**のは「壊れている」ように見えるので理由を出す。
    if (execution.permissionDenied) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const Key('undo-permission-denied'),
          content: const Text(
            '「すべてのファイルへのアクセス」が許可されていないため、元に戻せませんでした。'
            '端末の設定で許可してから、もう一度お試しください。',
          ),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    if (outcome == null) return;
    final message = StringBuffer('${outcome.successes.length} 件を元に戻しました');
    final failure = outcome.failure;
    if (failure != null) {
      message.write('。失敗: ${failure.error.message ?? failure.error.kind.name}');
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final execution = this.execution;
    final empty = controller.isRuleEmpty;
    final running = execution?.isRunning ?? false;
    // 005 REQ-019: 実行できるのは**変更が生じるファイルが1件以上ある**ときだけ。
    final changedCount = controller.changedFileCount;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onEditRule != null) ...[
                _RuleButton(
                  empty: empty,
                  onPressed: onEditRule!,
                  summary: describeRuleSummary(controller.rule),
                ),
                const SizedBox(height: 10),
              ],
              // 更新日時ずらし。設定できない端末では出さない(REQ-015)。
              if (execution != null && execution.canShiftModifiedAt) ...[
                _ShiftModifiedAtToggle(execution: execution),
                const SizedBox(height: 6),
              ],
              if (execution != null)
                FilledButton.icon(
                  key: const Key('rename-action'),
                  // REQ-019: 変更が生じるファイルが0件の間は押せない。
                  onPressed: running || changedCount == 0
                      ? null
                      : () => _request(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  icon: running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.drive_file_rename_outline),
                  label: Text(
                    running
                        ? '処理中…'
                        : executeLabel(
                            selectedCount: controller.selectedCount,
                            changedCount: changedCount,
                            ruleIsEmpty: empty,
                          ),
                    key: executeLabelKey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 更新日時ずらしの入切(005 REQ-014)。
///
/// 設定できる端末でだけ [_RenameActionBar] が描画する(REQ-015)。既定は OFF で、
/// 入れると改名成功後に一覧の並び順で更新日時をずらす。
class _ShiftModifiedAtToggle extends StatelessWidget {
  const _ShiftModifiedAtToggle({required this.execution});

  final RenameExecutionController execution;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      key: shiftModifiedAtKey,
      onTap: () => execution.setShiftModifiedAt(!execution.shiftModifiedAt),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: execution.shiftModifiedAt,
                onChanged: (value) =>
                    execution.setShiftModifiedAt(value ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '更新日時を一覧の並び順にずらす',
                style: TextStyle(color: colors.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ルール編集への導線(参考designの2行button)。
///
/// design は `[✎] 命名ルール / <設定中のルール>` の2行に `編集` を添えた形で、
/// **「命名ルール」見出しの右に空きがある**。005 REQ-009 (2) の原因の提示を
/// そこへ置く(008:T15 が土台として申し送り、開発者が2026-08-31に選択)。
///
/// **載せるのは種別だけである。**説明そのものを載せると原因の数と文字倍率で
/// buttonが伸び、下部バーごと一覧を押し出す(独立review attempt 3 のP1-1)。
/// 種別は最大2つなので占有が定数に収まる。説明は詳細dialogが持つ。
///
/// ルールが空のときは design の2行ではなく**主役のbutton**へ入れ替える
/// (005 REQ-019 / REQ-020)。この状態では警告も出さない。
class _RuleButton extends StatelessWidget {
  const _RuleButton({
    required this.empty,
    required this.onPressed,
    required this.summary,
  });

  final bool empty;
  final VoidCallback onPressed;

  /// 設定中のルールの1行要約(design の2行目)。トークンを並べた形
  /// ([describeRuleSummary])。
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (empty) {
      return FilledButton.icon(
        key: const Key('configure-rule'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('変更する名前を設定する'),
      );
    }
    // **button 全体が一つの押下対象である**(2026-09-02 の要望9。原文は
    // 「参考designだと全体がボタンと認識しやすいが、現状だと右の編集ボタンを
    // 押す必要があると錯覚する」)。`編集` は**押下対象ではなく飾り**で、
    // 押せる場所は外側の [InkWell] 一つだけである。参考designも
    // `<button>` の中に `編集` の `<span>` を置いている。
    return Material(
      color: colors.primary.withValues(alpha: ruleButtonFillOpacity),
      borderRadius: BorderRadius.circular(ruleButtonRadius),
      child: InkWell(
        key: const Key('configure-rule'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ruleButtonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.primary.withValues(alpha: ruleButtonBorderOpacity),
            ),
            borderRadius: BorderRadius.circular(ruleButtonRadius),
          ),
          child: Row(
            children: [
              // 参考designの塗りつぶした四角の中の `✎`。
              Container(
                width: ruleButtonIconBoxSize,
                height: ruleButtonIconBoxSize,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.edit, size: 17, color: colors.onPrimary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '命名ルール',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      key: ruleSummaryKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // **飾りである。** ここだけを押しても外側の [InkWell] が受ける。
              Container(
                key: ruleEditChipKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: ruleEditChipFillOpacity,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '編集',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一覧の件数と警告の入口、または**除去のための選択モード**の操作を出すヘッダ。
///
/// モード中は 002 REQ-018 の3つ(やめる / 選択件数 / 外す)へ入れ替わる。
/// **ケバブは両方のモードで同じ位置(右端)に出る**(`008:T29`)。
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.controller,
    required this.warnings,
    required this.selecting,
    required this.markedCount,
    required this.onEnterRemovalMode,
    required this.onExitRemovalMode,
    required this.onRemoveMarked,
    required this.onSelectAll,
    required this.onClearAll,
    required this.hintLink,
  });

  final FileListController controller;

  /// 一覧全体の警告(005 REQ-009 (3) の入口。ルールが空なら空で渡る)。
  final List<Warning> warnings;

  /// 除去のための選択モードか(002 REQ-018)。
  final bool selecting;

  /// いま外す候補として選ばれている件数。
  final int markedCount;

  /// モードへ入る(入口(b))。一覧が空なら `null`。
  final VoidCallback? onEnterRemovalMode;

  /// モードをやめる。**一覧は変わらない**(代表例 6i)。
  final VoidCallback onExitRemovalMode;

  /// 選ばれた行を外す。**0 件なら `null`**(REQ-018)。
  final VoidCallback? onRemoveMarked;

  /// 外せる行を全て選ぶ(ケバブ)。外せる行が無ければ `null`。
  final VoidCallback? onSelectAll;

  /// 一覧を空にする(ケバブ。004 REQ-006)。一覧が空なら `null`。
  final VoidCallback? onClearAll;

  /// 外すアイコンと補足の吹き出しを結ぶ(`008:T30`)。**吹き出しは `Overlay` にある**ので、
  /// 位置は座標を計算するのではなくこの link がアイコンから直に決める。
  final LayerLink hintLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = controller.items.length;
    return Container(
      // 左右の padding は**吹き出しのツノの位置にも効く**ので共有する(`008:T30`)。
      padding: const EdgeInsets.symmetric(
        horizontal: headerBarHorizontalPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (selecting)
            IconButton(
              key: removalModeExitKey,
              onPressed: onExitRemovalMode,
              icon: const Icon(Icons.close, size: 18),
              color: colors.textSecondary,
              tooltip: '選ぶのをやめる',
              visualDensity: VisualDensity.compact,
              // **tap target を数で固定する**(`008:T30`)。帯の吹き出しは
              // この幅からツノの位置を出すので、実際の描画幅が数と一致している
              // 必要がある(widget test が実測で確かめる)。
              constraints: const BoxConstraints.tightFor(
                width: headerIconExtent,
                height: headerIconExtent,
              ),
              padding: EdgeInsets.zero,
            ),
          // **文字は左、操作は右**(2026-09-19 の要望4)。
          //
          // 文字側だけ `Expanded` にして折り返させる。`Row` にそのまま並べると
          // 幅が足りないとき「はみ出す」か「切り詰める」しかなく、切り詰めは
          // overflow を出さないまま `1000 件` を `1…` と読ませる(008:T16 の P1)。
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: selecting
                  // **「2件選択中」と簡潔に出す**(2026-09-19 の決定)。`T27` の
                  // 決定節は「外すことを名指しする見出し」を勧めていたが、
                  // 開発者がこちらを選んだ。誤読を防ぐ役割は、外すアイコンの
                  // tooltip とケバブの文言が引き受ける。REQ-018 は文言を縛らない。
                  ? Text(
                      key: removalModeCountKey,
                      '$markedCount件選択中',
                      maxLines: 2,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // **選択の切り替えは出さない**(002 REQ-016)。
                        // **総件数は残す**(いま何件を扱っているかは実行前に知りたい)。
                        Text(
                          key: fileCountKey,
                          '$total 件',
                          maxLines: 2,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // 一覧全体の件数。押すと全件の詳細が開く(005 REQ-009 (3))。
                        // **ルールが空のときは出さない** — 001 は空名と重複を
                        // 返しているので「問題なし」は誤りになる。
                        //
                        // 警告0件でも、実際に変更するfileがあるときだけ準備完了を
                        // 出す。変更0件では実行buttonが理由を示すので、成功を主張する
                        // 件数見出しは重ねない(008:T33)。
                        if (!controller.isRuleEmpty &&
                            (warnings.isNotEmpty ||
                                controller.changedFileCount > 0))
                          WarningCountView(
                            warnings: warnings,
                            // 全件の入口。**特定のファイルに絞られない**(REQ-009 (4))。
                            onTap: () => showWarningDetail(
                              context,
                              controller.warnings,
                              ruleIsEmpty: controller.isRuleEmpty,
                              amongFiles: controller.rows.map((r) => r.source),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          // **外す操作はアイコン1つ**(2026-09-19 の要望4)。`一覧を空にする` が
          // 使っていたものと同じ icon にして、右寄せで置く。
          if (selecting)
            CompositedTransformTarget(
              link: hintLink,
              child: IconButton(
                key: removalModeRemoveKey,
                onPressed: onRemoveMarked,
                icon: const Icon(Icons.playlist_remove, size: 20),
                color: colors.danger,
                disabledColor: colors.textDisabled,
                tooltip: '選んだファイルをリネーム候補から外す',
                visualDensity: VisualDensity.compact,
                // **tap target を数で固定する**(`008:T30`)。吹き出しはこの幅から
                // ツノの位置を出すので、実際の描画幅が数と一致している必要がある
                // (widget test が実測で確かめる)。
                constraints: const BoxConstraints.tightFor(
                  width: headerIconExtent,
                  height: headerIconExtent,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          // **ケバブは両方のモードで同じ位置に出る**(2026-09-19 の補足)。
          // 一覧が空のときだけ出さない(どの項目も対象が無い)。
          if (total > 0)
            PopupMenuButton<VoidCallback?>(
              key: listMenuKey,
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: colors.textSecondary,
              ),
              tooltip: 'その他の操作',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 180),
              onSelected: (action) => action?.call(),
              itemBuilder: (context) => [
                // **通常表示のときだけ出す。** モード中は既に入っている。
                if (!selecting)
                  PopupMenuItem<VoidCallback?>(
                    key: removalModeEnterKey,
                    value: onEnterRemovalMode,
                    enabled: onEnterRemovalMode != null,
                    child: const Text('外すファイルを選ぶ'),
                  ),
                PopupMenuItem<VoidCallback?>(
                  key: menuSelectAllKey,
                  value: onSelectAll,
                  enabled: onSelectAll != null,
                  child: const Text('すべて選択'),
                ),
                PopupMenuItem<VoidCallback?>(
                  key: menuClearAllKey,
                  value: onClearAll,
                  enabled: onClearAll != null,
                  // **`一覧を空にする` の言い換えである**(`008:T29` で読み込み帯から
                  // 移した)。結果を名指しするので、選択モードの「選ぶ」と混ざらない。
                  child: const Text('すべてをリネーム対象から外す'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.controller, required this.selecting});

  final FileListController controller;

  /// 除去のための選択モードか(002 REQ-018)。モード中は `カスタム順` を出さない。
  final bool selecting;

  /// 常に提示するソート(閲覧・確認の用途があるため。REQ-014)。
  static const List<(FileSortMode, String)> _alwaysModes = [
    (FileSortMode.name, '元の名前順'),
    (FileSortMode.createdAt, '作成日時順'),
    (FileSortMode.modifiedAt, '更新日時順'),
    (FileSortMode.size, 'サイズ順'),
  ];

  /// 連番トークンがあるときだけ提示する(並び順が出力に効くのはそのときだけ)。
  static const (FileSortMode, String) _customMode = (
    FileSortMode.custom,
    'カスタム順',
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (final (mode, label) in [
              ..._alwaysModes,
              // **モード中は出さない。** `カスタム順` は REQ-014 が言う
              // 「手動並び替えの提示」そのもので、REQ-018 はモード中それを
              // 提示しないと定めている。ソート自体(名前順など)は常に出す。
              if (controller.manualOrderMatters && !selecting) _customMode,
            ]) ...[
              _SortChip(
                label: label,
                active: controller.sortMode == mode,
                onTap: () => controller.setSortMode(mode),
              ),
              const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

/// 作成日時ソート時に「不明な件数を更新日時で代替した」ことを知らせる帯(REQ-011)。
///
/// [warning] が `null`(不明 0 件、または作成日時以外のソート)なら何も表示しない。
class _CreatedAtFallbackBanner extends StatelessWidget {
  const _CreatedAtFallbackBanner({required this.warning});

  final CreatedAtFallbackWarning? warning;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    if (warning == null) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      key: const Key('created-at-fallback-warning'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.danger.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '作成日時を取得できないファイルが ${warning.unknownCount} 件あります。'
              'それらは更新日時で代替して並べています。',
              style: TextStyle(color: colors.danger, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colors.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? colors.primary.withValues(alpha: 0.45)
                : colors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? colors.primary : colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 1行: preview + 現在名・変更後名・サブ情報 + ドラッグハンドル。
///
/// **通常表示には除去の操作を置かない**(002 REQ-016)。以前は右端に × があったが、
/// 並び替えのつまみと隣り合って押し間違えうるので、除去は**選択モード**へ移した
/// (REQ-018 / `008:T27`)。モード中はこの行の左へ選択の切り替えが出る。
class _FileRow extends StatefulWidget {
  const _FileRow({
    super.key,
    required this.index,
    required this.row,
    required this.showDragHandle,
    required this.sortMode,
    required this.showLocation,
    required this.filePreview,
    required this.warnings,
    required this.onShowWarningDetail,
    required this.ruleIsEmpty,
    required this.selecting,
    required this.marked,
    required this.rowGeometryKey,
    required this.onToggleMark,
    required this.onLongPressStart,
  });

  /// ReorderableListView 内での行位置(ドラッグハンドルが使用)。
  final int index;
  final RowView row;

  /// 手動並び替えを提示するか(連番トークンがあるときだけ。REQ-014)。
  final bool showDragHandle;

  /// 現在のソート種別(作成日時が不明な行の強調条件に使う。REQ-013)。
  final FileSortMode sortMode;

  /// この行に場所(元フォルダ)を出すか。
  ///
  /// **一覧に複数の場所が混ざっているときだけ真**である(002 の決定・`008:T22`)。
  /// 判定は一覧の側が持つ — 行は自分だけを見ても「混ざっているか」を知れない。
  final bool showLocation;

  /// 行の preview の供給元(008:T07)。`null` なら種別アイコンだけを出す。
  final FilePreviewPort? filePreview;

  /// この行に出す警告([rowWarningsOf] を通した後)。空なら何も出ない。
  final List<Warning> warnings;

  /// ルールにトークンが1つも無いか(005 REQ-020 / REQ-029)。空なら変更後名の
  /// 代わりに「変更なし」を出す。
  final bool ruleIsEmpty;

  /// 行の警告を押したときに**その行の**詳細を開く(005 REQ-009 (4))。
  final VoidCallback onShowWarningDetail;

  /// 除去のための選択モードか(002 REQ-018)。モード中は選択の切り替えを出し、
  /// 並び替えのつまみを出さない。
  final bool selecting;

  /// この行が外す候補として選ばれているか(モード中だけ意味を持つ)。
  final bool marked;

  /// 外す候補にする/やめる。**元場所ハンドルを持たない行では `null`**
  /// (ハンドルが無いと除去の対象を指せない。004 REQ-006)。
  final VoidCallback? onToggleMark;

  /// 表示済みの行矩形を、ドラッグの経路判定に使う。
  final GlobalKey? rowGeometryKey;

  /// 長押しドラッグの開始。move/up/cancel は list 親の Listener が追跡するので、
  /// この行が offscreen で dispose されても active pointer は失われない。
  final ValueChanged<Offset>? onLongPressStart;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  /// つまみに指が触れているか(`008:T32`)。
  ///
  /// **Flutter の並び替えは「触れてから約18px 動いた時点」でドラッグ開始と判定する**ので、
  /// `proxyDecorator` だけだと**触れてすぐには色が変わらない**(2026-09-19 の2回目の
  /// 実機確認)。つまみは触れた瞬間からもう動かせるので、**触れた瞬間**を見て同じ色にする。
  bool _grabbed = false;

  void _setGrabbed(bool value) {
    if (_grabbed == value) return;
    setState(() => _grabbed = value);
    // **掴めたことを一拍の振動でも伝える**(2026-09-19 の要望)。
    // `HapticFeedback` は view の触覚フィードバックを使うので、`VIBRATE` 権限は要らない。
    if (value) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final row = widget.row;
    final selecting = widget.selecting;
    final marked = widget.marked;
    final handle = row.source.sourceHandle;
    return Container(
      key: widget.rowGeometryKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // **選ばれた行は面を染める**(2026-09-19 の要望2)。行の高さも位置も
        // 変えずに、選んだものが一覧の中で読める。
        //
        // **掴んでいる間はドラッグ中と同じ色**(`008:T32`)。`proxyDecorator` が
        // 引き継ぐので、実際に動き始めても見た目は変わらない。
        color: _grabbed
            ? colors.surface
            : (selecting && marked ? colors.selectedSurface : null),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // **長押しはここ(preview と名前の範囲)だけで受ける。**
          //
          // 行ごと包むと、**つまみの上の長押しも行が取る**。長押しは 500ms で
          // gesture arena を勝つので、つまみを掴んで少し止めただけで選択モードが
          // 開き、`showDragHandle` が false になって**つまみが消え、掴んだままの
          // 指では並び替えを始められない**(独立reviewが実測: 450ms は並び替わり、
          // 520ms でモードが開いた)。長押ししてからドラッグするのは Android の
          // 既定の並び替え操作なので、REQ-003 / REQ-014 の導線が壊れる。
          Expanded(
            child: GestureDetector(
              // 名前の文字の上だけ、にしない(この範囲の余白でも反応する)。
              behavior: HitTestBehavior.opaque,
              // 初回とモード中で同じ長押しドラッグを受ける。通常の短いドラッグは
              // callback を持たず、選択へ影響しない。
              onLongPressStart: widget.onLongPressStart == null
                  ? null
                  : (details) =>
                        widget.onLongPressStart!(details.globalPosition),
              // **モード中の tap は選択の切り替え**。通常表示では行 tap に意味を
              // 持たせない(誤って外す操作へ繋げない)。
              onTap: selecting ? widget.onToggleMark : null,
              child: Row(
                children: [
                  // 中身が見える行にする(参考designのリッチな行)。preview を出せない
                  // file は種別アイコンになるが、**枠は必ず在る**ので行の高さも名前の
                  // 開始位置も揃う。
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: RowPreviewView(
                      file: row.source,
                      preview: widget.filePreview,
                    ),
                  ),
                  // 現在名・変更後名・サブ情報を**縦に積む**(参考designのリッチな行)。
                  //
                  // 横2カラムだと各セルが行幅の半分しか使えず、狭幅ではサブ情報が
                  // 収まらない((h)の見切れの根本)。縦に積むと3つとも行幅を丸ごと
                  // 使える。002 specはレイアウトを非規範としている(「対象外」節)。
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 005 REQ-009 (1)。**現在名の上に1行設けて右寄せで置く**
                        // (2026-09-02 の要望8。原文は「リネーム前の名前と同じ行の右の
                        // スペースか、**さらにその上に1行設けてそこに右寄せで表示する**」で、
                        // 参考designも両方の変種を持つ — リッチ案は現在名と同じ行、
                        // コンパクト案は上の行に `text-align:right` で置いている)。
                        //
                        // **同じ行ではなく上の行を選んだ。** 008:T17 の改訂で桁不足が
                        // 行へ来るようになり、種別は最大3つ併発する(重複・作成日時不明・
                        // 連番の桁不足)。同じ行へ載せると、狭幅では現在名か種別の
                        // どちらかが必ず切り詰められる。上の行なら行幅を丸ごと使える。
                        // **行数は増えない** — 警告は元から変更後名の下で1行を占めていた。
                        RowWarningView(
                          warnings: widget.warnings,
                          onTap: widget.onShowWarningDetail,
                        ),
                        Text(
                          row.currentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        // 「現在名 → 変更後名」という読み方は矢印で残す。
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: colors.textMuted,
                              ),
                            ),
                            Expanded(
                              child: _NewName(
                                row: row,
                                ruleIsEmpty: widget.ruleIsEmpty,
                                hasWarning: widget.warnings.isNotEmpty,
                              ),
                            ),
                          ],
                        ),
                        _DateSubInfo(
                          file: row.source,
                          sortMode: widget.sortMode,
                          showLocation: widget.showLocation,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // **checkbox とつまみは同じ枠に入れる**(2026-09-19 の要望1)。
          //
          // 左へ出すと、モードへ入った瞬間に preview と名前が横へずれて
          // **かくつく**(実機で観測)。右端なら行の読み始めが動かない。
          // 幅を固定しておくと、つまみ ↔ checkbox の入れ替わりでも中身が動かない。
          // **モード中はつまみを出さない**(REQ-018)ので、位置は取り合わない。
          if (selecting || widget.showDragHandle)
            SizedBox(
              width: 32,
              child: Center(
                // **モード中はつまみを出さない**(REQ-018)。枠は同じなので、
                // 入れ替わっても行の中身は動かない。
                child: selecting
                    ? (widget.onToggleMark == null
                          // 外せない行(元場所ハンドルが無い)。**枠だけ残す。**
                          ? const SizedBox(width: 24, height: 24)
                          : Checkbox(
                              key: removalMarkKeyOf(handle!),
                              value: marked,
                              onChanged: (_) => widget.onToggleMark!(),
                              // **円にする**(2026-09-19 の要望2)。
                              shape: const CircleBorder(),
                              side: BorderSide(
                                color: colors.textMuted,
                                width: 1.5,
                              ),
                              activeColor: colors.selectionMark,
                              checkColor: colors.onPrimary,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                    // **触れた瞬間を見る**(`008:T32`)。`ReorderableDragStartListener`
                    // だけだと、Flutter が約18px の移動でドラッグ開始と判定するまで
                    // 色が変わらない(2026-09-19 の2回目の実機確認)。つまみは
                    // 触れた瞬間からもう動かせるので、そこで色と振動を出す。
                    : Listener(
                        onPointerDown: (_) => _setGrabbed(true),
                        onPointerUp: (_) => _setGrabbed(false),
                        onPointerCancel: (_) => _setGrabbed(false),
                        child: ReorderableDragStartListener(
                          index: widget.index,
                          child: Icon(
                            Icons.drag_handle,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 行のサブ情報: 場所(元フォルダ)と、作成日時・更新日時の双方(REQ-010 / REQ-013)。
///
/// 場所を出すのは**一覧に複数の場所が混ざっているときだけ**である(002 の決定。
/// 2026-09-18 に開発者が再承認。代表例 7b・7c)。混ざっていれば別フォルダの同名
/// ファイルを見分ける手がかりになり、1つだけなら読み込み帯が一覧全体として示す。
/// 作成日時が不明な行は「作成日時: 不明」を危険色+警告アイコンで
/// 示し、更新日時で代替されたことを行レベルで見分けられるようにする。見た目は
/// 非規範だが、色は [AppColors] のセマンティック名から取る(生の色値を書かない)。
class _DateSubInfo extends StatelessWidget {
  const _DateSubInfo({
    required this.file,
    required this.sortMode,
    required this.showLocation,
  });

  final FileEntry file;

  /// 現在のソート種別。**作成日時ソートのときだけ**不明を強調する(REQ-013)。
  final FileSortMode sortMode;

  /// 場所を出すか(一覧に複数の場所が混ざっているときだけ真)。
  final bool showLocation;

  static String _format(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}/${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final createdAt = file.createdAt;
    final unknown = createdAt == null;
    // 表示は常にするが、強調(警告色+アイコン)は作成日時ソートのときだけ
    // (他のソートでは日時は単なる情報で、強調は不要な警告になる。REQ-013)。
    final emphasize = unknown && sortMode == FileSortMode.createdAt;
    final base = TextStyle(color: colors.textMuted, fontSize: 10.5);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 場所(元フォルダ)。004 が供給し、かつ**一覧に複数の場所が混ざっている**
          // 行だけ表示する(REQ-010 と 002 の決定。`008:T22`)。
          //
          // **日時と同じ行に置かない。** 同居させると狭幅で場所が幅を使い切り、
          // 後ろにある `作成日時: 不明` から省略される(008:T07 の (h))。
          //
          // **省略は先頭側から行う**(`…/DCIM/t07-fixtures`)。帯と同じ文字列なので、
          // 同じ見せ方にする(`008:T23`)。
          if (showLocation && file.sourceLocation != null)
            SourcePathText(
              text: file.sourceLocation!,
              textKey: rowLocationKey,
              style: base,
            ),
          // **2つの日時は `Wrap` に置く。** 横に並びきらなければ更新日時が
          // 次の行へ落ち、作成日時は丸ごと残る。
          //
          // `Row` で作成日時を「縮まない側」に置くと、幅が足りなくなった瞬間に
          // 省略ではなく **overflow** になる(独立review attempt 1 の P1-1)。
          // 更新日時を削るだけでは足りず、作成日時自身にも下限が要る。
          // ここでも「優先順位ではなく行数で解く」を一段深く適用している。
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (emphasize) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 11,
                      color: colors.danger,
                    ),
                    const SizedBox(width: 3),
                  ],
                  // 最後の砦として省略も持たせる。**1行に単独で置いても入らない**
                  // ほど狭いとき(極端な font scale など)に、はみ出させない。
                  Flexible(
                    child: Text(
                      '作成日時: ${unknown ? '不明' : _format(createdAt)}',
                      key: rowCreatedAtKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: emphasize ? colors.danger : colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              // 入りきらなければ**次の行へ落ちる**。作成日時を削らない。
              Text(
                '更新日時: ${_format(file.modifiedAt)}',
                key: rowModifiedAtKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 変更後名セル。未選択は対象外表示、変更なしはその旨、それ以外はアクセント色。
class _NewName extends StatelessWidget {
  const _NewName({
    required this.row,
    required this.ruleIsEmpty,
    required this.hasWarning,
  });

  final RowView row;

  /// ルールにトークンが1つも無いか(005 REQ-029)。
  final bool ruleIsEmpty;

  /// この行に警告が出ているか。**変更後名の色をこれで決める**(参考designの
  /// `newColor: bad ? 赤 : 緑`)。
  final bool hasWarning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final newName = row.newName;
    // 未選択行はプレビュー対象外(002 REQ-007)。「変更なし」とは別物なので
    // 区別する — 選べば変わりうる。
    if (newName == null) {
      return Text(
        '—',
        style: TextStyle(color: colors.textDisabled, fontSize: 13),
      );
    }
    // 005 REQ-029: **変更が生じない行は、生成後名の代わりに「変わらない」ことが
    // 読める。** 空のルールの生成後名(`.jpg` のような拡張子だけの名前)を変更後名
    // として出さない — REQ-019 によりその名前が実体に付くことはない。
    if (rowHasNoChange(row, ruleIsEmpty: ruleIsEmpty)) {
      return Text(
        unchangedLabel,
        key: rowUnchangedKey,
        overflow: TextOverflow.ellipsis,
        // **強調しない**(参考designも `（変更なし）` を弱い色で置いている)。
        style: TextStyle(color: colors.textMuted, fontSize: 13),
      );
    }
    return Text(
      newName,
      key: rowNewNameKey,
      overflow: TextOverflow.ellipsis,
      // 参考design: `newColor: bad ? '#f87171' : '#4ade80'`。
      // 正常なら success、警告対象なら danger(2026-09-02 の要望7)。
      style: TextStyle(
        color: hasWarning ? colors.danger : colors.success,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// 変更後名の代わりに出す文言(005 REQ-029)。
const String unchangedLabel = '（変更なし）';

/// 「変更なし」を出している変更後名。
const Key rowUnchangedKey = Key('row-unchanged');

/// 実際の変更後名を出している変更後名。
const Key rowNewNameKey = Key('row-new-name');
