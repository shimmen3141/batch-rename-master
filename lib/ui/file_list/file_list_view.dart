import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/rename_engine.dart';
import '../../data/file_source/file_source.dart';
import '../../data/preview/file_preview.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../file_source/list_origin.dart';
import '../file_source/same_folder_reopen.dart';
import '../file_source/source_path_text.dart';
import '../common/app_toast.dart';
import '../common/drag_selection_controller.dart';
import '../common/selection_checkbox.dart';
import '../rename_exec/rename_execution_controller.dart';
import '../rule_builder/rule_chip_strip.dart';
import '../theme/app_colors.dart';
import 'file_list_controller.dart';
import 'file_size_format.dart';
import 'row_date_format.dart';
import 'file_sort.dart';
import 'header_metrics.dart';
import 'removal_selection.dart';
import 'removal_undo.dart';
import 'rename_confirmation_view.dart';
import 'rename_warning_view.dart';
import 'row_preview_view.dart';
import 'row_view.dart';
import '../theme/app_typography.dart';

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

/// 行サブ情報のファイルの大きさ(`008:T48`)。
const Key rowSizeKey = Key('row-size');

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
    this.onReopen,
    this.listOrigin,
  });

  final FileListController controller;

  /// 一覧の読み込み元を、一覧の状態を初期値にして開き直す(004 REQ-021。`008:T56` /
  /// REQ-024。`010:T09`)。読み込み元が写真・動画の選択画面なら選択画面を、そうで
  /// なければ所属 folder を browser で開き直す(振り分けは読み込み帯が行う)。
  ///
  /// **`null` なら先頭の行を出さない。** 開き直せない platform(desktop)や、
  /// 一覧だけを描く画面では入口が無い。製品では composition root が
  /// [SameFolderReopen] を渡し、読み込み帯の結線(権限・通知)に載せる。
  final Future<void> Function()? onReopen;

  /// 一覧の読み込み元(004 REQ-024)。写真・動画の選択画面なら、先頭の行は所属
  /// folder の数に依らず「写真・動画」を示す。`null` なら読み込み元を見ない
  /// (REQ-021 の規則だけで出す)。
  final ListOriginState? listOrigin;
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
  /// モード中は帯の `ファイル選択` と下部の帯も隠れるためである(`008:T29`)。
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

  /// スクロール位置と表示領域。ドラッグ中に実際に描画された行だけを拾う。
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _listViewportKey = GlobalKey();
  final GlobalKey _renameActionBarKey = GlobalKey();
  late final DragSelectionController<String> _dragSelection =
      DragSelectionController<String>(
        scrollController: _listScrollController,
        viewportKey: _listViewportKey,
        select: (handle) => _selection.mark(handle),
        deselect: (handle) => _selection.unmark(handle),
        isMounted: () => mounted,
      );

  @override
  void dispose() {
    _dragSelection.dispose();
    _listScrollController.dispose();
    // **自分で作ったものだけ捨てる。** 渡されたものは composition root の持ち物で、
    // 読み込み帯も同じものを読んでいる。
    _own?.dispose();
    super.dispose();
  }

  void _startDragSelection(String handle, Offset position) {
    final baseline = _selection.marked;
    if (!_selection.selecting) {
      // 選択モードへ入ると下部の rename UI がモードのフッターへ入れ替わる。**高さは
      // 同じ**(`008:T42`。[_FixedFooter])なので list の viewport は変わらず、開始行は
      // 跳ばない(`008:T31`。以前はフッターが消える分を末尾余白で補っていた)。
      _selection.enter();
    }
    _dragSelection.start(handle, position, baseline: baseline);
  }

  void _exitRemovalMode() {
    _dragSelection.finish();
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
        ?widget.listOrigin,
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
        final soleFolder = soleFolderOf(rows.map((r) => r.source));
        // 読み込み元が写真・動画の選択画面なら、REQ-021 の folder の入口は出さず、
        // 選択画面を開き直す入口を出す(004 REQ-024。所属 folder が1つでも)。
        final fromMediaPicker =
            widget.listOrigin?.current == ListOrigin.mediaPicker;
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
        // 選択モードのフッター(`008:T42`)。
        _RemovalModeBar removalModeBar({required bool fill}) => _RemovalModeBar(
          fill: fill,
          // 通常のフッターに命名ルールのカードがある(狭幅)ときだけ、同じ形の
          // 説明カードを置く。無い(広幅)なら説明は1行(`008:T42`)。
          noteAsCard: widget.onEditRule != null,
          markedCount: marked.length,
          onExit: _exitRemovalMode,
          // 0 件では外せない(REQ-018)。
          onRemove: marked.isEmpty
              ? null
              : () => _removeMarked(context, marked),
        );
        return PopScope(
          // 端末の戻るは**モードをやめる**に使う(画面を閉じない)。REQ-018 の
          // 「やめる操作」はヘッダの × が満たすが、選択モードから戻るの期待は強い。
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _exitRemovalMode();
          },
          child: Container(
            color: colors.background,
            child: ToastHost(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBar(
                    controller: widget.controller,
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
                  ),
                  _MessageBanner(
                    controller: widget.controller,
                    // 一覧全体の件数(005 REQ-009 (3) の入口)。ルールが空なら出さない。
                    warnings: ruleIsEmpty ? const <Warning>[] : warnings,
                  ),
                  // **一覧の所属 folder が1つのときだけ**、一覧の先頭に folder 行を置く
                  // (004 REQ-021 の入口。`008:T26` の決定)。一覧の外に置くので、
                  // スクロールしても先頭に残る。
                  if (widget.onReopen != null &&
                      (fromMediaPicker || soleFolder != null))
                    _FolderRow(
                      label: fromMediaPicker
                          ? mediaPickerOriginLabel
                          : folderLabelOf(
                              rows.map((r) => r.source),
                              soleFolder!,
                            ),
                      icon: fromMediaPicker
                          ? Icons.photo_library_outlined
                          : Icons.folder_open_outlined,
                      // **モード中は入口を出さない**(004 REQ-021 / REQ-024 /
                      // 002 REQ-018)。行は残す — 消すと一覧が跳ねる(`008:T30` の
                      // 帯と同じ理由)。
                      onAdd: selecting ? null : widget.onReopen,
                    ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _dragSelection.onPointerDown,
                      onPointerMove: _dragSelection.onPointerMove,
                      onPointerUp: _dragSelection.onPointerUp,
                      onPointerCancel: _dragSelection.onPointerCancel,
                      child: ReorderableListView.builder(
                        key: _listViewportKey,
                        scrollController: _listScrollController,
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
                                    Curves.easeInOut.transform(
                                      animation.value,
                                    ) *
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
                            // revision 10.0(`008:T53`): **重複の相手も読める**。
                            // 相手の他の警告は足さない([rowDetailWarnings])。
                            // 行と全件は**同じ評価**([preview])から取る。
                            onShowWarningDetail: () => showWarningDetail(
                              context,
                              rowDetailWarnings(row.warnings, warnings),
                              ruleIsEmpty: ruleIsEmpty,
                              scopeFile: row.source,
                              // 同名が一覧に並ぶときだけ場所を添える。**母集合は
                              // 一覧のファイル**(警告を持つものだけだと、同名2件の
                              // 片方だけが警告されたときに見分けられない)。
                              amongFiles: rows.map((r) => r.source),
                            ),
                            selecting: selecting,
                            marked: handle != null && marked.contains(handle),
                            rowGeometryKey: handle == null
                                ? null
                                : _dragSelection.rowGeometryKey(handle),
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
                ],
              ),
              // **フッターは通知の置き場の`bottomNavigationBar`**(`008:T25`)。通知は
              // その少し上・この領域の幅の中に出る(リネームのbuttonなどに重ならない)。
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
              // **モード中は「戻る」と「N件を外す」のフッター**(`008:T42`)。
              // **通常のフッターと同じ大きさに固定する**([_FixedFooter])。
              // **通常のフッターがあるときだけ大きさを揃える**([_FixedFooter])。
              // 無い画面(ルールも実行も無い)には揃える相手が無いので、モード中だけ
              // 自然な高さのモードのフッターを出す(揃える仕組みを通すと、大きい
              // 文字で高さを大きく見積もりすぎて上の帯を押し出した)。
              footer:
                  (widget.renameExecution != null || widget.onEditRule != null)
                  ? _FixedFooter(
                      showRemovalMode: selecting,
                      normal: _RenameActionBar(
                        key: _renameActionBarKey,
                        controller: widget.controller,
                        execution: widget.renameExecution,
                        onEditRule: widget.onEditRule,
                        rows: rows,
                      ),
                      removalMode: removalModeBar(fill: true),
                    )
                  : selecting
                  ? removalModeBar(fill: false)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// 一覧の先頭の folder 行(`008:T56`。004 REQ-021 の入口の置き場所)。読み込み元が
/// 写真・動画の選択画面なら、同じ行が選択画面を開き直す入口になる(REQ-024。`010:T09`)。
const Key folderRowKey = Key('folder-row');

/// folder 行の名前。
const Key folderRowLabelKey = Key('folder-row-label');

/// folder 行の右端の `＋ 追加`。**同じ folder(読み込み元が写真・動画の選択画面なら
/// 選択画面)を一覧の状態で開き直す**(004 REQ-021 / REQ-024)。
const Key folderRowAddKey = Key('folder-row-add');

/// 一覧の先頭の folder 行(`008:T56`)。
///
/// **行全体の tap では開かない。** 開くのは右端の `＋ 追加` だけで、行の tap は
/// `008:T24`(複数 folder を束ねる表示)の折りたたみのために空けてある。
/// [onAdd] が `null`(選択モード中)なら `＋ 追加` を描かないが、**場所は残す** —
/// 行の高さを変えない。
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.label,
    required this.icon,
    required this.onAdd,
  });

  final String label;
  final IconData icon;
  final Future<void> Function()? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onAdd = this.onAdd;
    return Container(
      key: folderRowKey,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.rowDivider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            // 入りきらない分は**先頭側**を省略し、判別に効く末尾を残す(帯と同じ)。
            child: SourcePathText(
              text: label,
              textKey: folderRowLabelKey,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppFontSize.label,
              ),
            ),
          ),
          Visibility(
            visible: onAdd != null,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: TextButton(
              key: folderRowAddKey,
              onPressed: onAdd == null ? null : () => onAdd(),
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('＋ 追加'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 選択モードのフッターの「戻る」(`008:T42`)。**モードをやめる**(帯の `×` と同じ)。
const Key removalModeBackKey = Key('removal-mode-back');

/// モード中に通常のフッターを隠す(場所は取ったまま)枠(`008:T42`)。
const Key normalFooterVisibilityKey = Key('normal-footer-visibility');

/// 通常のフッターと選択モードのフッターを重ねる枠(`008:T42`)。大きさを test が測る。
const Key fixedFooterKey = Key('fixed-footer');

/// 選択モードのフッターの面(`008:T42`)。高さを test が測るための key。
const Key removalModeBarKey = Key('removal-mode-bar');

/// 選択モードのフッターの説明(`008:T42`)。**削除ではないこと**をモード中ずっと示す。
const Key removalModeNoteKey = Key('removal-mode-note');

/// 選択モードのフッターの説明の文言(2026-09-28 の開発者の決定)。
///
/// **後半(ファイルは消えない)を落とさない。** 外すのは rename の一覧からで、
/// ファイルそのものには触れない — 005 / 013 が守っている境界そのものである。
const String removalModeNoteLead = '選択したファイルをリネームリストから外します。';

/// 説明の後半。カードでは太字の2行目になる。
const String removalModeNoteMain = 'ファイルは削除されません。';

/// 説明の文字の拡大の上限(`008:T42`)。
const double removalModeNoteMaxTextScale = 1.5;

/// 説明と操作の間(`008:T42`)。通常のフッターの段の間と同じ。
const double removalModeNoteGap = 10;

/// 説明の全文(支援技術が読む)。
const String removalModeNoteText = '$removalModeNoteLead$removalModeNoteMain';

/// 権限のエラーの通知から設定画面を開く操作(`008:T25`)。
const Key permissionSettingsActionKey = Key('permission-settings-action');

/// フッター([_RenameActionBar])の面。上端の区切り線を test が見るための key。
const Key renameActionBarSurfaceKey = Key('rename-action-bar-surface');

/// 除去の選択モードのフッター(`008:T42`。002 REQ-018)。
///
/// 左に「← 戻る」(モードをやめる。帯の `×` と同じ)、右に「N件を外す」(0件では押せない)。
/// 上に**削除ではないことの説明**を常設する(以前の吹き出し(`008:T30`)の代わり)。
/// 面と区切り線は [_RenameActionBar] と同じにして、フッターの位置と見た目を揃える。
class _RemovalModeBar extends StatelessWidget {
  const _RemovalModeBar({
    required this.fill,
    required this.noteAsCard,
    required this.markedCount,
    required this.onExit,
    required this.onRemove,
  });

  /// 説明を命名ルールのカードと同じ形のカードにするか。`false`(命名ルールがフッターに
  /// 無い)なら、広幅では操作の左に2行([_RemovalNoteCompact])、通常のフッターが無い
  /// 画面では操作の上に1行([_RemovalNoteLine])。
  final bool noteAsCard;

  /// 通常のフッターと大きさを揃えているか([_FixedFooter] の中)。`true` なら説明が
  /// 余った高さを埋める。`false` なら中身の自然な高さ。
  final bool fill;

  final int markedCount;
  final VoidCallback onExit;

  /// 選ばれた行を外す。**0 件なら `null`**(REQ-018)。
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // **app内browserの footer 左下の button(`008:T39`)と同じ形。** そちらは
    // 2026-10-07 に矢印なしの「キャンセル」になった(`015:T03`)が、枠と色は同じ。
    final back = OutlinedButton.icon(
      key: removalModeBackKey,
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary),
      ),
      onPressed: onExit,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('戻る'),
    );
    // **シアンの塗り**(2026-09-28 の開発者の決定)。赤は削除を連想させる。
    final remove = FilledButton(
      key: removalModeRemoveKey,
      onPressed: onRemove,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      child: Text('$markedCount件を外す', overflow: TextOverflow.ellipsis),
    );
    final Widget content;
    if (fill && !noteAsCard) {
      // **広幅は1段**(`008:T43`。2026-09-29 の開発者の決定)。通常のフッターが
      // リネームだけなので、説明を操作の上に置く高さが無い。説明は操作の左に
      // 小さな2行で置き、入らなければ縮める。
      content = Row(
        children: [
          Expanded(
            child: _clampNoteScale(
              const Align(
                alignment: Alignment.centerLeft,
                child: _FitNote(child: _RemovalNoteCompact()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          back,
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: remove,
          ),
        ],
      );
    } else {
      // **説明が余った高さを吸収する**(2026-09-28 のエミュレータ確認「不自然な
      // 余白」)。フッターの大きさは通常のフッターと揃える([_FixedFooter])。
      // 説明のカードは命名ルールのカードと同じ形なので、ふつうはちょうど揃う。
      // 揃わない分(ルールが空のbuttonなど)はカードが伸びるか縮んで埋める。
      content = Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fill)
            Expanded(child: _clampNoteScale(const _RemovalNoteCard()))
          else
            _clampNoteScale(
              noteAsCard ? const _RemovalNoteCard() : const _RemovalNoteLine(),
            ),
          const SizedBox(height: removalModeNoteGap),
          Row(
            children: [
              back,
              const SizedBox(width: 8),
              Expanded(child: remove),
            ],
          ),
        ],
      );
    }
    return Material(
      key: removalModeBarKey,
      color: colors.bar,
      shape: Border(top: BorderSide(color: colors.border)),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.all(12), child: content),
      ),
    );
  }
}

/// **説明の文字の拡大は[removalModeNoteMaxTextScale]倍まで**(`008:T42`)。説明は補足で、
/// 最大の文字では何行にも折り返してフッターが画面の上側を押し出した。**文字は削らない**。
/// 操作(戻る・外す)の文字は抑えない。
Widget _clampNoteScale(Widget note) => Builder(
  builder: (context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: removalModeNoteMaxTextScale,
    child: note,
  ),
);

/// 説明を幅いっぱいで組み、**高さが足りなければ全体を縮めて収める**(`008:T42`)。
///
/// 選択モードのフッターは通常のフッターの大きさに固定する([_FixedFooter])ので、説明に
/// 使える高さは構成(広幅・ルールが空・文字の大きさ)で変わる。**文字を削らずに**収める。
class _FitNote extends StatelessWidget {
  const _FitNote({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(width: constraints.maxWidth, child: child),
    ),
  );
}

/// 選択モードの説明のカード(`008:T42`)。**命名ルールのカード([_RuleButton])と同じ形**
/// (余白・角丸・左の四角いアイコン・小さな見出しと太字の2行)にして、通常のフッターと
/// 部品の寸法を揃える。押せない(button ではない)ので面と枠は中立の色にする。
class _RemovalNoteCard extends StatelessWidget {
  const _RemovalNoteCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: removalModeNoteText,
      child: ExcludeSemantics(
        child: Container(
          key: removalModeNoteKey,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(ruleButtonRadius),
          ),
          child: _FitNote(
            child: Row(
              children: [
                Container(
                  width: ruleButtonIconBoxSize,
                  height: ruleButtonIconBoxSize,
                  decoration: BoxDecoration(
                    color: colors.info.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.info_outline, size: 17, color: colors.info),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        removalModeNoteLead,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        removalModeNoteMain,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 広幅の選択モードの説明(`008:T43`)。操作の左に置く小さな2行。
class _RemovalNoteCompact extends StatelessWidget {
  const _RemovalNoteCompact();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: removalModeNoteText,
      child: ExcludeSemantics(
        child: Row(
          key: removalModeNoteKey,
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    removalModeNoteLead,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: AppFontSize.caption,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    removalModeNoteMain,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppFontSize.bodySmall,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 選択モードの説明の1行(`008:T42`)。通常のフッターが無く、命名ルールも無い画面で
/// 使う(大きさを揃える相手が無いので、自然な高さで操作の上に置く)。
class _RemovalNoteLine extends StatelessWidget {
  const _RemovalNoteLine();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      key: removalModeNoteKey,
      children: [
        Icon(Icons.info_outline, size: 16, color: colors.info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            removalModeNoteText,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppFontSize.label,
            ),
          ),
        ),
      ],
    );
  }
}

/// 通常のフッターと選択モードのフッターを**同じ大きさに固定して**出し分ける(`008:T42`。
/// 2026-09-28 の開発者の決定「フッターの大きさは固定」)。
///
/// **大きさは通常のフッターが決め、モードのフッターはその枠に重ねる。** 通常のフッターは
/// 一切変わらない(当初は `IndexedStack` で「高い方に揃える」にしたが、モードのフッターの
/// 方が高くなる構成 — 広幅・ルールが空 — で**通常のフッターに空きが出た**。独立review
/// attempt 2 の P2)。モードのフッターは説明が余った高さを埋め、足りなければ説明を縮めて
/// 収める([_FitNote])。**モードの出入りでフッターの大きさが変わらない**ので、一覧の
/// 表示域も変わらず、長押しで入ったときに行が跳ばない(`008:T31`)。
class _FixedFooter extends StatelessWidget {
  const _FixedFooter({
    required this.showRemovalMode,
    required this.normal,
    required this.removalMode,
  });

  final bool showRemovalMode;
  final Widget normal;
  final Widget removalMode;

  @override
  Widget build(BuildContext context) => Stack(
    key: fixedFooterKey,
    children: [
      // **大きさは常に通常のフッターが決める。** モード中は見えなくし、押せず、
      // 支援技術からも外すが、**場所は取ったまま**にする。
      Visibility(
        key: normalFooterVisibilityKey,
        visible: !showRemovalMode,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: normal,
      ),
      // モードのフッターは、その大きさの枠いっぱいに重ねる。
      if (showRemovalMode) Positioned.fill(child: removalMode),
    ],
  );
}

/// リストの下に固定するアクションバー(参考デザインの下部バー)。
///
/// 上段にルール設定への導線、下段に実行を置く。**変更が生じるファイルが0件の
/// ときは実行を無効にする**(005 REQ-019 revision 9.0。空のルールはこの0件に含まれる)。
/// ルールが空なら、ルール設定ボタンを主役の表示へ入れ替える(REQ-020)。
class _RenameActionBar extends StatelessWidget {
  const _RenameActionBar({
    super.key,
    required this.controller,
    required this.execution,
    required this.onEditRule,
    required this.rows,
  });

  final FileListController controller;

  /// 実行境界。デモやリスト単体の描画では `null`(実行ボタンを出さない)。
  final RenameExecutionController? execution;
  final VoidCallback? onEditRule;

  /// 同じ build で作った行(実行できるかを数え直さずに決めるため。`008:T20` の F3)。
  final List<RowView> rows;

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
      showAppToast(
        ScaffoldMessenger.of(context),
        key: const Key('rename-occupied-names-unavailable'),
        tone: ToastTone.danger,
        content: Text(_unavailableMessage(prepared.reasons)),
      );
      return;
    }
    if (!context.mounted) return;
    final occupiedNames = (prepared as OccupiedNamesReady).names;

    // `prepare` が取り直した占有名を `controller` へ反映済みなので、この警告には
    // 占有名との衝突が含まれる(REQ-026 / REQ-028)。
    //
    // **行と警告を同じ評価から取る。** 警告が指す [FileEntry] は評価ごとに作られ、
    // 行の `source` とは同一でない。名前が変わらないファイルは、行が持つ警告の
    // ファイル(同じ評価のもの)で数える(review attempt 1 の T14-R1)。
    final preview = controller.preview;
    final warnings = preview.warnings;
    if (warnings.isNotEmpty) {
      // **何を聞かれていて、実行すると何が起きるか**を種類ごとに示す(`008:T14`)。
      // 同じファイルの空名と基準日時不明は、空名の側へ畳む(REQ-021 規則1)。
      final force = await showRenameConfirmation(
        context,
        warnings,
        amongFiles: preview.rows.map((r) => r.source),
        // 名前が変わらないファイルを「改名します」と書かないため(005 REQ-019 と同じ判定)。
        unchangedFiles: [
          for (final r in preview.rows)
            if (rowHasNoChange(r, ruleIsEmpty: controller.isRuleEmpty))
              ...r.warnings.map(warningFile).nonNulls,
        ],
      );
      if (!force || !context.mounted) return;
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

  /// 結果の本文。再採番が起きた項目は**件数と詳細の入口**を置く(REQ-024)。
  ///
  /// 「旧 → 新」は通知の中へ並べず、`詳細` から開くdialogで**全件**読ませる
  /// (`008:T14`。2026-10-02 の開発者の決定 A)。通知の中へ並べると件数が多いとき
  /// 縦に伸び、高さで打ち切ると scroll しないと読めなかった。
  Widget _resultContent(
    BuildContext context,
    String summary,
    List<SuccessfulRename> renumbered,
  ) {
    if (renumbered.isEmpty) return Text(summary);
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        const SizedBox(height: 4),
        InkWell(
          key: renumberedDetailLinkKey,
          onTap: () => showRenumberedDetail(context, renumbered),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.primary,
                    width: warningLinkUnderlineWidth,
                  ),
                ),
              ),
              child: Text(
                '名前を確認する',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        showAppToast(
          messenger,
          key: const Key('execute-permission-denied'),
          tone: ToastTone.danger,
          content: const Text(
            '「すべてのファイルへのアクセス」が許可されていないため、名前を変更できませんでした。'
            '端末の設定で許可してから、もう一度お試しください。',
          ),
          // **設定画面へ直接移れる**(2026-09-28 の開発者の決定)。押したときだけ開く —
          // 自動では開かない(013 REQ-003)。
          action: ToastAction(
            key: permissionSettingsActionKey,
            label: '設定',
            onPressed: () => execution.permission.openSettings(),
          ),
        );
      }
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
    showAppToast(
      ScaffoldMessenger.of(context),
      // **固定 key を付けない。** `showSnackBar` は key が null のときだけ
      // `UniqueKey` を fallback に入れ、連続する snackbar が構造的に一致した
      // ときの ink splash / highlight の持ち越しを防いでいる。結果トーストは
      // undo ボタンを含むので、固定 key を付けるとその持ち越しが起きうる。
      // 到達の観測は本文(「N 件を改名しました」)で足りる。
      //
      // **失敗を含むならエラーの見せ方にする**(`008:T25`)。成功の✓で失敗を伝えない。
      tone: failure == null ? ToastTone.success : ToastTone.danger,
      content: _resultContent(context, message.toString(), renumbered),
      // undo はこのトースト内に置く(参考デザインどおり)。下部バーへ置くと
      // 結果トーストがバーを覆い、取り消せる 5 秒の間だけ押せなくなる。
      // **undo は 5 秒で期限切れ**(REQ-007)なので、押せなくなった undo を残さない。
      // **失敗を含んでも同じ** — エラーは既定で残るが、undo を持つ間はその期限で消す。
      //
      // **名前が変わった項目があるなら閉じるまで残す**(`008:T14`。2026-10-02 の
      // 開発者の決定)。詳細を開く前に消えると、どの名前になったかを読めない。
      // そのときも undo は期限で消える(押しても何も起きない操作を残さない)。
      duration: execution.undoWindow,
      persist: renumbered.isNotEmpty
          ? true
          : execution.canUndo
          ? false
          : null,
      action: execution.canUndo
          ? ToastAction(
              key: const Key('rename-undo'),
              label: '元に戻す',
              onPressed: () => _undo(context),
              expiresAfter: execution.undoWindow,
            )
          : null,
    );
  }

  Future<void> _undo(BuildContext context) async {
    final execution = this.execution!;
    final outcome = await execution.undo();
    if (!context.mounted) return;
    // undo も書き込みなので、権限が取り消されていれば断る(013 INV-002)。
    // **黙って何も起きない**のは「壊れている」ように見えるので理由を出す。
    if (execution.permissionDenied) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        showAppToast(
          messenger,
          key: const Key('undo-permission-denied'),
          tone: ToastTone.danger,
          content: const Text(
            '「すべてのファイルへのアクセス」が許可されていないため、元に戻せませんでした。'
            '端末の設定で許可してから、もう一度お試しください。',
          ),
          action: ToastAction(
            key: permissionSettingsActionKey,
            label: '設定',
            onPressed: () => execution.permission.openSettings(),
          ),
        );
      }
      return;
    }
    if (outcome == null) return;
    final message = StringBuffer('${outcome.successes.length} 件を元に戻しました');
    final failure = outcome.failure;
    if (failure != null) {
      message.write('。失敗: ${failure.error.message ?? failure.error.kind.name}');
    }
    showAppToast(
      ScaffoldMessenger.of(context),
      tone: failure == null ? ToastTone.success : ToastTone.danger,
      content: Text(message.toString()),
      replaceCurrent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final execution = this.execution;
    final empty = controller.isRuleEmpty;
    final running = execution?.isRunning ?? false;
    // 005 REQ-019: 実行できるのは**変更が生じるファイルが1件以上ある**ときだけ。
    final changedCount = controller.changedFileCountIn(rows);
    return Material(
      key: renameActionBarSurfaceKey,
      color: colors.bar,
      // **上端に区切り線**(design 土台の `border-top: 1px solid rgba(255,255,255,.08)`)。
      // 一覧との境目が読めなかった(2026-09-28 のエミュレータ確認。`008:T25`)。
      shape: Border(top: BorderSide(color: colors.border)),
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
                  rule: controller.rule,
                  sample: controller.items.isEmpty
                      ? null
                      : controller.items.first,
                ),
                const SizedBox(height: 10),
              ],
              // 更新日時ずらしはヘッダーの歯車へ移した(`008:T43`)。
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
                    // **角丸をルール設定buttonに合わせる**(2026-09-30 の開発者の指定。`008:T47`)。
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ruleButtonRadius),
                    ),
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
    required this.rule,
    required this.sample,
  });

  final bool empty;
  final VoidCallback onPressed;

  /// 設定中のルール。チップで並べる([RuleChipStrip]。`008:T47`)。
  final RenameRule rule;

  /// チップの値を描く一覧の1件目。無ければ null。
  final FileEntry? sample;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // **未設定・設定済みで外形(面・枠・角丸)を揃える**(2026-09-30 の開発者の指定。
    // `008:T47`)。以前の未設定は塗りの `FilledButton` で、形が違った。
    //
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
          key: ruleButtonFrameKey,
          // **上下は詰め、左右は変えない**(2026-09-30 の開発者の指定。`008:T47` の
          // 実機確認)。詰めたぶんを「命名ルール」とチップの間へ回した。
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: ruleButtonVerticalPadding,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.primary.withValues(alpha: ruleButtonBorderOpacity),
            ),
            borderRadius: BorderRadius.circular(ruleButtonRadius),
          ),
          child: empty ? _emptyContent(context) : _ruleContent(colors),
        ),
      ),
    );
  }

  /// 未設定: ＋と文言だけを白で出す(✎・見出し・`編集` は出さない。2026-09-30 の
  /// 開発者の指定)。文言は「変更する名前を設定する」から変えた。
  ///
  /// **高さは設定済みよりひとまわり小さいくらい**にする(2026-10-01 の開発者の指定。
  /// 実機確認5回目)。文字の高さだけだと設定済みの半分以下で、小さく見えた。
  Widget _emptyContent(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: MediaQuery.textScalerOf(
        context,
      ).scale(ruleButtonEmptyMinContentHeight),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add, size: 18, color: Colors.white),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            '命名ルールを設定する',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppFontSize.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _ruleContent(AppColors colors) => Row(
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
                fontSize: AppFontSize.tiny,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: ruleButtonHeadingGap),
            // **設定画面と同じ2段のチップで並べる**(2026-09-30 の開発者の決定。
            // `008:T47`)。以前は `[元の名前][01…]` の字面だった。読み上げは
            // 字面の要約([describeRuleSummary])が持つ。
            Semantics(
              label: describeRuleSummary(rule),
              excludeSemantics: true,
              child: RuleChipStrip(
                key: ruleSummaryKey,
                rule: rule,
                sample: sample,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      // **飾りである。** ここだけを押しても外側の [InkWell] が受ける。
      Container(
        key: ruleEditChipKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: ruleEditChipFillOpacity),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '編集',
          style: TextStyle(
            color: colors.primary,
            fontSize: AppFontSize.small,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

/// ルール設定buttonの外形(面の上の枠)。未設定・設定済みで同じ(`008:T47`)。
const Key ruleButtonFrameKey = Key('rule-button-frame');

/// 一覧の件数と警告の入口、または**除去のための選択モード**の操作を出すヘッダ。
///
/// モード中は 002 REQ-018 の3つ(やめる / 選択件数 / 外す)へ入れ替わる。
/// **ケバブは両方のモードで同じ位置(右端)に出る**(`008:T29`)。
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.controller,
    required this.selecting,
    required this.markedCount,
    required this.onEnterRemovalMode,
    required this.onExitRemovalMode,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final FileListController controller;

  /// 除去のための選択モードか(002 REQ-018)。
  final bool selecting;

  /// いま外す候補として選ばれている件数。
  final int markedCount;

  /// モードへ入る(入口(b))。一覧が空なら `null`。
  final VoidCallback? onEnterRemovalMode;

  /// モードをやめる。**一覧は変わらない**(代表例 6i)。
  final VoidCallback onExitRemovalMode;

  /// 外せる行を全て選ぶ(ケバブ)。外せる行が無ければ `null`。
  final VoidCallback? onSelectAll;

  /// 一覧を空にする(ケバブ。004 REQ-006)。一覧が空なら `null`。
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = controller.items.length;
    return Container(
      // **右は詰める**(2026-09-30 の開発者の指定。`008:T02` の実機確認2回目)。ケバブの
      // tap target(48)は中のアイコン(20)より広いので、左と同じ padding では
      // アイコンの右に余白が目立つ。右を詰めて、アイコンの右端と左端の件数の余白を揃える。
      padding: const EdgeInsets.fromLTRB(
        headerBarHorizontalPadding,
        4,
        headerBarRightPadding,
        4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      // 左の文字の幅の上限を帯の幅から決める(下の `ConstrainedBox`)。
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
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
            // 文字側は**自分の幅を使い、上限を超えるときだけ折り返す**。切り詰めは
            // overflow を出さないまま `1000 件` を `1…` と読ませる(008:T16 の P1)。
            // **並び順に削られない** — 並び順に幅の割合を先に与えると、狭幅・文字の
            // 拡大で件数が切れた(`008:T02`、幅 320・文字 1.3・200 件)。
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * headerTextMaxWidthFraction,
              ),
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
                          fontSize: AppFontSize.bodySmall,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    // **選択の切り替えは出さない**(002 REQ-016)。
                    // **総件数は残す**(いま何件を扱っているかは実行前に知りたい)。
                    : Text(
                        key: fileCountKey,
                        '$total 件',
                        maxLines: 2,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppFontSize.bodySmall,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            // **並び順はケバブの左**(2026-09-30 の開発者の指定。`008:T02` の実機確認)。
            // 以前は並び順だけの帯が一覧の上にあった。モード中も出す(並び順の選択は
            // 提示してよい。REQ-018)。
            //
            // **残りの幅を使い、ケバブへ寄せる。** 以前は `Flexible` で包んでいて、行の幅の
            // 半分を取り置いて使わず、余りがケバブの右に空いた(2026-09-30 の実機確認
            // 2回目)。入りきらないときは切らずに折り返す。
            if (total > 0)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SortControl(controller: controller),
                ),
              ),
            // **外す操作は帯に置かない**(`008:T42`)。モード中はフッターの「N件を外す」が持つ。
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
      ),
    );
  }
}

/// 並び順を1か所で示し、そこからすべてのキーと向きを選ぶcontrol(002 REQ-020)。
///
/// 押すとキー×向きの8項目のメニューが開く(2026-09-30 の開発者の決定。`008:T02`)。
/// どの状態へも1回で行け、選べるものが全部見える。**文字を最大にしても**
/// メニューは画面の高さに収まってスクロールするので、隠れた選択肢に気づける
/// (`008:T07` の N-8a。以前の横並びの chip は画面外へはみ出していた)。
/// 選んでいる項目には選択の印(丸いチェック)を付ける(2026-09-30 の開発者の指定)。
///
/// `custom`(手で並べた状態)はメニューに出さない — 選ぶものではなく
/// 手で並べた結果を示す状態である(REQ-003)。このとき表示は「カスタム」になり、
/// どの項目にも印が付かない。
const Key sortControlKey = Key('sort-control');

/// 並び順のメニューの項目(002 REQ-020)。
Key sortOptionKeyOf(FileSortMode mode, SortDirection direction) =>
    ValueKey('sort-option:${mode.name}:${direction.name}');

/// メニューに並べる順(キーごとに昇順・降順)。
const List<FileSortMode> _sortKeys = [
  FileSortMode.name,
  FileSortMode.createdAt,
  FileSortMode.modifiedAt,
  FileSortMode.size,
];

/// キーの表示名。
String sortKeyLabel(FileSortMode mode) => switch (mode) {
  FileSortMode.name => '名前',
  FileSortMode.createdAt => '作成日時',
  FileSortMode.modifiedAt => '更新日時',
  FileSortMode.size => 'サイズ',
  FileSortMode.custom => 'カスタム',
};

/// 向きの表示名。**昇順・降順ではなく、そのキーで何が先に来るか**で示す。
String sortDirectionLabel(FileSortMode mode, SortDirection direction) {
  final ascending = direction == SortDirection.ascending;
  return switch (mode) {
    FileSortMode.name => ascending ? 'A→Z' : 'Z→A',
    FileSortMode.createdAt ||
    FileSortMode.modifiedAt => ascending ? '古い順' : '新しい順',
    FileSortMode.size => ascending ? '小さい順' : '大きい順',
    FileSortMode.custom => '',
  };
}

class _SortControl extends StatelessWidget {
  const _SortControl({required this.controller});

  final FileListController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mode = controller.sortMode;
    final direction = controller.sortDirection;
    final current = sortLabelOf(mode, direction);
    return PopupMenuButton<(FileSortMode, SortDirection)>(
      key: sortControlKey,
      tooltip: '並び順を変える',
      position: PopupMenuPosition.under,
      onSelected: (choice) =>
          controller.setSortMode(choice.$1, direction: choice.$2),
      itemBuilder: (context) => [
        for (final key in _sortKeys)
          for (final dir in SortDirection.values)
            PopupMenuItem(
              key: sortOptionKeyOf(key, dir),
              value: (key, dir),
              child: _SortOption(
                keyLabel: sortKeyLabel(key),
                directionLabel: sortDirectionLabel(key, dir),
                selected: mode == key && direction == dir,
              ),
            ),
      ],
      child: Semantics(
        label: '並び順: $current',
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final style = TextStyle(
              color: colors.textPrimary,
              fontSize: AppFontSize.bodySmall,
              fontWeight: FontWeight.w500,
            );
            // **「並び順:」は1行に入るときだけ付ける**(2026-09-30 の開発者の指定
            // 「入るなら入れなおしてください」)。帯へ移したときに外したが、ケバブの
            // 右の余白を詰めると幅 360・文字 1.0 で入った。狭幅や文字の拡大で
            // 入らないときは付けず、帯が縦に伸びすぎないようにする。
            final withPrefix = '並び順: $current';
            final fits =
                _textWidth(context, withPrefix, style) +
                    _sortControlChromeWidth <=
                constraints.maxWidth;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert, size: 16, color: colors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      fits ? withPrefix : current,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 並び順の表示の、文字以外の幅(左右の余白 4+4、⇅ 16、間 4、▾ 18)。
const double _sortControlChromeWidth = 4 + 16 + 4 + 18 + 4;

/// [text] を1行で描いたときの幅(端末の文字倍率を含む)。
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    // `Text` と同じく既定の文字の設定(書体など)へ重ねて測る。
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// 並び順の表示文言(`名前 A→Z`、手で並べた状態なら `カスタム`)。
String sortLabelOf(FileSortMode mode, SortDirection direction) =>
    mode == FileSortMode.custom
    ? sortKeyLabel(mode)
    : '${sortKeyLabel(mode)} ${sortDirectionLabel(mode, direction)}';

/// 状態に関するメッセージのバナー(`_MessageBanner`)。
const Key messageBannerKey = Key('message-banner');

/// 上の帯の下に出す、**状態に関するメッセージのバナー**(2026-09-30 の開発者の指定)。
///
/// 上の帯には件数・並び順・ケバブだけを置き、「正常にリネームできます」「N 件の問題」
/// (005 REQ-009 (3))・命名ルールが未設定(005 REQ-020)・作成日時の代替(002 REQ-011)の
/// ような**状態**はここへまとめる。行ごとに意味の色を敷いて上の帯と区別する。
/// メッセージの増減で一覧が急に動かないよう、**高さの変化をアニメーションする**。
class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.controller, required this.warnings});

  final FileListController controller;

  /// 一覧全体の警告(ルールが空なら空で渡る)。
  final List<Warning> warnings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ruleIsEmpty = controller.isRuleEmpty;
    final fallback = controller.createdAtSortWarning;
    final hasWarnings = warnings.isNotEmpty;
    // 警告0件でも、実際に変更するfileがあるときだけ準備完了を出す。変更0件では
    // 実行buttonが理由を示すので、成功を主張する件数は重ねない(008:T33)。
    //
    // **選択モード中も出す。** 隠すとモードへ入った瞬間に一覧が1行ぶん上へずれる。
    final showCount =
        !ruleIsEmpty && (hasWarnings || controller.changedFileCount > 0);
    // 押すと全件の詳細が開く(005 REQ-009 (3))。**特定のファイルに絞られない**(REQ-009 (4))。
    void openDetail() => showWarningDetail(
      context,
      controller.warnings,
      ruleIsEmpty: controller.isRuleEmpty,
      amongFiles: controller.rows.map((r) => r.source),
    );
    return AnimatedSize(
      key: messageBannerKey,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ルールが空なら警告ではなく未設定を提示する(005 REQ-020)。
          if (ruleIsEmpty) const RuleNotConfiguredBanner(),
          if (showCount)
            _MessageRow(
              key: warningCountRowKey,
              tone: hasWarnings ? colors.danger : colors.success,
              // **行のどこを押しても開く**(2026-09-30 の開発者の指定)。「詳細」の文字は
              // 押せることを示す印で、押せる範囲はそれより広い。0 件なら開くものが無い。
              onTap: hasWarnings ? openDetail : null,
              child: Align(
                alignment: Alignment.centerLeft,
                child: WarningCountView(warnings: warnings, onTap: openDetail),
              ),
            ),
          if (fallback != null)
            _MessageRow(
              key: const Key('created-at-fallback-warning'),
              tone: colors.danger,
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: bannerIconSize,
                    color: colors.danger,
                  ),
                  const SizedBox(width: bannerIconGap),
                  Expanded(
                    child: Text(
                      // **何についての状態かを先頭で示す**(2026-09-30 の開発者の指定)。
                      '並び順: 作成日時不明の ${fallback.unknownCount} 件は'
                      '更新日時で代替しています',
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: AppFontSize.label,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 件数(準備完了・N 件の問題)のバナーの行。
const Key warningCountRowKey = Key('warning-count-row');

/// バナーの1行。[tone] を薄く敷き、上の帯と区別する。[onTap] があれば行全体で押せる。
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.tone,
    required this.child,
    this.onTap,
  });

  final Color tone;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tone.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.keyLabel,
    required this.directionLabel,
    required this.selected,
  });

  final String keyLabel;
  final String directionLabel;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: keyLabel,
                  style: TextStyle(color: colors.textPrimary),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: directionLabel,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
            style: const TextStyle(fontSize: AppFontSize.bodyLarge),
          ),
        ),
        const SizedBox(width: 12),
        // **押下は項目が受ける**(印だけを押し損ねても選べる)。
        IgnorePointer(
          child: SelectionCheckbox(value: selected, onChanged: (_) {}),
        ),
      ],
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
        border: Border(bottom: BorderSide(color: colors.rowDivider)),
      ),
      child: Row(
        children: [
          // **長押しはここ(preview と名前の範囲)だけで受ける。**
          //
          // 行ごと包むと、**つまみの上の長押しも行が取る**。長押しは 500ms で
          // gesture arena を勝つので、つまみを掴んで少し止めただけで選択モードが
          // 開き、**つまみが checkbox に入れ替わって消え、掴んだままの
          // 指では並び替えを始められない**(独立reviewが実測: 450ms は並び替わり、
          // 520ms でモードが開いた)。長押ししてからドラッグするのは Android の
          // 既定の並び替え操作なので、REQ-003 / REQ-019 の導線が壊れる。
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
                      size: rowPreviewSize,
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
                        // 005 REQ-009 (1)。**現在名と同じ行の右端に置く**(`008:T50`。
                        // 2026-10-01 の開発者の決定。原文は「わざわざ1行を警告に使ううえに、
                        // 警告が見づらい」)。以前は現在名の上に専用の1行を取っていた
                        // (2026-09-02 の要望8)。**同じ行に載せられるのは、右端に書く種類を
                        // 減らしたから**である — 作成日時不明は補足情報の赤字で読めるので
                        // 書かず([rowWarningBadgeLabel])、桁不足は `T52` で起きなくなる。
                        // 現在名は残りの幅で省略し、警告は削らない。
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // **変更前は小さく薄く、変更後は大きく太く**(`008:T10`。
                            // 2026-10-01 の要望。参考designは現在名 11.5・変更後名 13 の太字)。
                            Expanded(
                              child: Text(
                                row.currentName,
                                key: rowCurrentNameKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: rowCurrentNameColorOf(colors),
                                  fontSize: rowCurrentNameFontSize,
                                ),
                              ),
                            ),
                            if (widget.warnings.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              RowWarningView(
                                warnings: widget.warnings,
                                onTap: widget.onShowWarningDetail,
                              ),
                            ],
                          ],
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
                          dateWarned: rowHasMissingCreatedAt(row),
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
          // 通常表示では**ルールに関わらずつまみを出す**(REQ-019。REQ-014 は廃止)。
          SizedBox(
            width: 32,
            child: Center(
              // **モード中はつまみを出さない**(REQ-018)。枠は同じなので、
              // 入れ替わっても行の中身は動かない。
              child: selecting
                  ? (widget.onToggleMark == null
                        // 外せない行(元場所ハンドルが無い)。**枠だけ残す。**
                        ? const SizedBox(width: 24, height: 24)
                        // **円にする**(2026-09-19 の要望2)。
                        : SelectionCheckbox(
                            key: removalMarkKeyOf(handle!),
                            value: marked,
                            onChanged: (_) => widget.onToggleMark!(),
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
    required this.dateWarned,
  });

  /// この行に「作成日時が取れない」警告がある(`008:T50`)。行の右端には書かず、
  /// **ここの `作成日時: 不明` を赤で強調して種類を読ませる**(005 REQ-009 (1))。
  final bool dateWarned;

  final FileEntry file;

  /// 現在のソート種別。**作成日時ソートのときだけ**不明を強調する(REQ-013)。
  final FileSortMode sortMode;

  /// 場所を出すか(一覧に複数の場所が混ざっているときだけ真)。
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final createdAt = file.createdAt;
    final unknown = createdAt == null;
    // 表示は常にするが、強調(警告色+アイコン)は作成日時ソートのときだけ
    // (他のソートでは日時は単なる情報で、強調は不要な警告になる。REQ-013)。
    // 並び順で作成日時を使っているとき(002 REQ-013)と、**ルールが作成日時を使って
    // 警告が出ているとき**(`008:T50`)に強調する。ルールが作成日時を使っていなければ
    // 不明でも問題は無いので、灰色のまま。
    final emphasize =
        unknown && (sortMode == FileSortMode.createdAt || dateWarned);
    final base = TextStyle(
      color: colors.textMuted,
      fontSize: AppFontSize.caption,
    );
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
                      '作成日時: ${unknown ? '不明' : formatRowDateTime(createdAt)}',
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
                '更新日時: ${formatRowDateTime(file.modifiedAt)}',
                key: rowModifiedAtKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base,
              ),
              // **大きさは日時の後ろ、ラベル無し**(`008:T48`。2026-10-01 の開発者の
              // 決定 A。参考designも `2.4 MB · 8/4 16:00` とラベルを付けない)。
              // 短いので、日時が2行に分かれる幅では更新日時の横へ収まる。
              Text(
                formatFileSize(file.size),
                key: rowSizeKey,
                maxLines: 1,
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
        style: TextStyle(
          color: colors.textDisabled,
          fontSize: AppFontSize.bodyLarge,
        ),
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
        style: TextStyle(
          color: colors.textMuted,
          fontSize: AppFontSize.bodyLarge,
        ),
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
        fontSize: AppFontSize.bodyLarge,
        fontWeight: rowNewNameFontWeight,
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

/// 行の現在名(変更前の名前)。
const Key rowCurrentNameKey = Key('row-current-name');

/// 行の preview の一辺(`008:T10`。2026-10-01 の要望)。参考designのリッチな行は
/// 52 で、以前の 40 では写真が小さかった。
const double rowPreviewSize = 52;

/// 現在名の文字の大きさ。**変更後名より小さい**(参考design: 11.5 と 13)。
const double rowCurrentNameFontSize = AppFontSize.label;

/// 現在名の色。**変更後名より薄い**(2026-10-01 の要望)。読めなくならないよう、
/// いちばん薄い `textMuted` ではなく `textSecondary` を使う。
Color rowCurrentNameColorOf(AppColors colors) => colors.textSecondary;

/// 変更後名の太さ。参考designは 700。
const FontWeight rowNewNameFontWeight = FontWeight.w700;
