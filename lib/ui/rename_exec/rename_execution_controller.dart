import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/rename_engine.dart';
import '../../data/file_source/file_source.dart';
import '../../data/permission/storage_permission.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../../data/rename_exec/rename_executor.dart';
import '../../data/rename_exec/rename_plan.dart';
import '../file_list/file_list_controller.dart';

/// 巻き戻し期限の内側か(005 contract 用語「巻き戻し期限」)。
///
/// **契約は「期限を*過ぎた*実行結果は巻き戻せない」**なので、ちょうどの瞬間は
/// まだ内側である。[RenameExecutionController.canUndo] と `undo()` の再評価が
/// **同じ述語を使う**ようにしてある — 片方だけ厳しいと、ボタンが出ているのに
/// 黙って戻らない瞬間ができる(独立review attempt 4 の F1)。
///
/// [deadline] が `null`(提示していない / 期限切れで捨てた)なら内側ではない。
bool isWithinUndoWindow({required DateTime now, DateTime? deadline}) =>
    deadline != null && !now.isAfter(deadline);

/// UI から既存の rename orchestration を一度だけ起動する状態境界。
class RenameExecutionController extends ChangeNotifier {
  RenameExecutionController({
    required this.files,
    required this.executor,
    required this.listNames,
    required this.permission,
    this._clock = DateTime.now,
    this.undoWindow = const Duration(seconds: 5),
    this.modifiedAtInterval = const Duration(seconds: 1),
  });

  final FileListController files;
  final RenameExecutor executor;

  /// 実在名の供給元(004 REQ-014 の `FileSource.listNames`)。
  ///
  /// **占有名の材料である。** これが無いと読み込んでいないファイルとの衝突を実行前に
  /// 検出できない(005 REQ-026)。**既定値を置かない** — 既定で「列挙しない」に
  /// できると、結線を忘れた経路が黙って REQ-026 を素通りする。
  final FolderNameLister listNames;

  /// 全ファイルアクセスの判定(013 REQ-004 / INV-002)。
  ///
  /// **実行の直前に毎回確認する。** 読み込み時に許可されていても、設定から
  /// 取り消されうる。Android を制限するのは composition root の仕事で、ここは
  /// platform を判定しない。
  ///
  /// **既定値を置かない。** 既定で「制限しない」にできると、結線を忘れた経路が
  /// 黙って REQ-001 / REQ-004 / INV-002 を素通りする(`listNames` と同じ理由。
  /// 独立review attempt 1 の P1-3 — 結線を外しても test が1件も落ちなかった)。
  final StoragePermissionPort permission;
  final DateTime Function() _clock;
  final Duration undoWindow;
  bool _running = false;
  bool get isRunning => _running;

  /// 直前の実行が権限不足で止まったか(013 REQ-004 / INV-002)。
  ///
  /// UI がこれを見て、実行できなかった理由を提示する。`execute` を呼ぶたびに
  /// 更新するので、**古い値を持ち回らない**。
  bool _permissionDenied = false;
  bool get permissionDenied => _permissionDenied;

  RenameOutcome? _undoableOutcome;
  DateTime? _undoDeadline;
  Timer? _undoExpiryTimer;

  bool get canUndo {
    final outcome = _undoableOutcome;
    final deadline = _undoDeadline;
    return !_running &&
        outcome != null &&
        outcome.successes.any(_changedRename) &&
        isWithinUndoWindow(now: _clock(), deadline: deadline);
  }

  List<FileEntry> _excludedEmptyNames = const [];
  List<FileEntry> get excludedEmptyNames => _excludedEmptyNames;

  Map<String?, PickError> _unavailableFolders = const {};

  /// 直前の [prepare] で実在名を取得できなかった folder → その理由(REQ-027)。
  ///
  /// 空でない間、実行は行われない。**「取得できなかった」を「衝突が無い」と
  /// 読まない。**
  Map<String?, PickError> get unavailableFolders => _unavailableFolders;

  /// 実行を要求した時点で占有名を取り直す(005 OP-005 / REQ-028)。
  ///
  /// 取得できたら [FileListController.setOccupiedNames] へも反映するので、以降の
  /// [FileListController.warnings] は**取り直した占有名**で評価される — 呼び出し側は
  /// この後に警告を読み、確認の要否を決めればよい(REQ-011 / REQ-028)。
  ///
  /// 1つでも取得できなければ [OccupiedNamesUnavailable] を返す。**呼び出し側は
  /// そのとき [execute] を呼んではならない**(REQ-027)。
  Future<OccupiedNamesResult> prepare() async {
    final result = await collectOccupiedNames(
      entries: _entriesWithSelection(),
      rule: files.rule,
      now: _clock(),
      listNames: listNames,
    );
    switch (result) {
      case OccupiedNamesReady(:final names):
        _unavailableFolders = const {};
        // 一覧の警告表示も取り直した占有名へ揃える(REQ-026)。
        files.setOccupiedNames(names.asMap);
      case OccupiedNamesUnavailable(:final reasons):
        _unavailableFolders = reasons;
    }
    notifyListeners();
    return result;
  }

  /// この端末で更新日時をずらせるか(005 REQ-015)。
  ///
  /// 手段を持つ実装だけが [ModifiedAtWriter] を実装する。UI はこれが `false` の
  /// ときに設定そのものを出さない — 「効かない設定」を見せないため。
  bool get canShiftModifiedAt => executor is ModifiedAtWriter;

  bool _shiftModifiedAt = false;

  /// 更新日時ずらしが有効か。**既定は無効**(REQ-014)。
  bool get shiftModifiedAt => _shiftModifiedAt;

  /// 更新日時ずらしの入切。ずらせない端末では有効にできない(REQ-015)。
  void setShiftModifiedAt(bool value) {
    final next = value && canShiftModifiedAt;
    if (next == _shiftModifiedAt) return;
    _shiftModifiedAt = next;
    notifyListeners();
  }

  /// ずらす間隔。既定 1 秒。
  ///
  /// filesystem の更新日時の解像度はこれより粗いことがある(FAT は 2 秒粒度)。
  /// 丸められても**順序**は保たれるので、等間隔であることは要求しない(REQ-014)。
  final Duration modifiedAtInterval;

  List<FileEntry> _modifiedAtFailures = const [];

  /// 直前の実行で、改名は成功したが更新日時を設定できなかったファイル。
  ///
  /// 改名の失敗([RenameOutcome.failure])とは別に持つ。混ぜると「改名できた
  /// のか」が読めなくなる(REQ-016)。
  List<FileEntry> get modifiedAtFailures => _modifiedAtFailures;

  /// [force] では 001 の自動解決後に空名を除外する(REQ-022)。
  ///
  /// ルールが空のときは、どの経路から呼ばれても実行を開始しない(REQ-019)。
  /// ボタンの無効化だけに頼ると、別経路から実体を変更できてしまうため、
  /// 状態境界のここでも止める。
  Future<RenameOutcome?> execute({
    required bool force,
    required OccupiedNames occupiedNames,
  }) async {
    // **早期returnでも古い値を残さない。** 残すと、次に別の理由で止まったときに
    // 前回の「権限が無い」を根拠にした説明が出る。
    _permissionDenied = false;
    if (_running || files.isRuleEmpty) return null;
    // **`_running` は最初の `await` より前に立てる。** 権限確認を先に置くと、
    // その待ちの間に2回目の実行が門を通り抜ける(REQ-012 が禁じている二重起動)。
    _running = true;
    _excludedEmptyNames = const [];
    _modifiedAtFailures = const [];
    notifyListeners();
    try {
      // **実行の直前に確認する**(013 REQ-004)。読み込み時の結果を持ち回らない。
      // 未許可なら**何も起動しない** — 013 INV-002 は「権限が無い状態で filesystem
      // へ書き込みを試みない」であり、`executor` にも `listNames` にも触れない。
      if (await permission.check() == StoragePermissionState.denied) {
        _permissionDenied = true;
        return null;
      }
      // **門を通ってから undo を捨てる。** 権限不足で断ったときに前回の undo を
      // 消すと、何もしていないのに戻せなくなる。
      _clearUndo();
      final entries = _entriesWithSelection();
      final now = _clock();
      final resolved = force
          ? autoResolve(
              files.rule,
              entries,
              now,
              occupiedNames: occupiedNames.asMap,
            )
          : generatePreview(files.rule, entries, now)
                .map(
                  (entry) => ResolvedEntry(
                    source: entry.source,
                    resultName: entry.resultName,
                  ),
                )
                .toList();
      final excluded = <FileEntry>[];
      final requests = <RenameRequest>[];
      final sources = <RenameRequest, FileEntry>{};
      final actualByHandle = <String, FileEntry>{
        for (final item in files.items)
          if (item.sourceHandle != null) item.sourceHandle!: item,
      };
      for (final entry in resolved) {
        // 起動時のUI sampleは実体handleを持たない。表示名を相対pathとして
        // production adapterへ渡すと、cwdの無関係な同名fileを変更しうる。
        if (entry.source.sourceHandle == null) continue;
        if (_hasEmptyBase(entry.source, entry.resultName)) {
          excluded.add(entry.source);
          continue;
        }
        final request = RenameRequest(
          handle: entry.source.sourceHandle!,
          originalName: entry.source.name,
          targetName: entry.resultName,
          // folder は 004 が供給した値をそのまま持つ。ハンドルから導出しない
          // (005 用語 `folder` / OQ-004)。
          folder: entry.source.sourceFolder,
        );
        requests.add(request);
        final actual = actualByHandle[entry.source.sourceHandle];
        if (actual != null) sources[request] = actual;
      }
      _excludedEmptyNames = List.unmodifiable(excluded);
      final outcome = await executePlan(
        planExecution(requests, occupiedNames: occupiedNames),
        executor,
        occupiedNames: occupiedNames,
      );
      _applyOutcome(outcome, sources);
      await _shiftModifiedAtOfSuccesses(outcome);
      _offerUndo(outcome);
      return outcome;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// 直前の実行で成功したrenameを期限内に一度だけ逆順で戻す。
  ///
  /// **undoも書き込みである。** 013 INV-002 は「権限が無い状態で filesystem へ
  /// 書き込みを試みない」であり、**戻す方向も例外にしない**。実行後に設定から
  /// 権限を取り消されても undo の提示は期限まで残る(断っても undo を消さないと
  /// 決めたため)ので、**押された時点で確かめる**(013 REQ-004)。
  Future<UndoOutcome?> undo() async {
    _permissionDenied = false;
    if (!canUndo) return null;
    final outcome = _undoableOutcome!;
    // **`_running` は最初の `await` より前に立てる**(`execute` と同じ理由)。
    _running = true;
    notifyListeners();
    try {
      if (await permission.check() == StoragePermissionState.denied) {
        _permissionDenied = true;
        // **undo は消さない。** 権限が戻れば期限内はまだ戻せる。
        return null;
      }
      // **期限を読み直す。** `check()` は channel 往復を含むので、その待ちの間に
      // 期限が切れうる(独立review attempt 3 の F3)。切れていたら戻さない。
      // **境界は[canUndo]と同じ述語で判定する。** ここだけ厳しくすると、
      // ボタンが出ているのに黙って戻らない瞬間ができる(独立review attempt 4 のF1)。
      if (!isWithinUndoWindow(now: _clock(), deadline: _undoDeadline)) {
        return null;
      }
      _clearUndo();
      final undoOutcome = await undoSuccessfulRenames(
        outcome.successes.where(_changedRename).toList(),
        executor,
      );
      _applyUndoOutcome(undoOutcome);
      return undoOutcome;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// 成功した改名に対して、**表示順**で一定間隔ずつ増える更新日時を書く(REQ-014)。
  ///
  /// 順序の基準は実行計画ではない。[planExecution] は中間状態の衝突を避けるため
  /// に並べ替え、一時名を挟むこともあるので、その順で書くと画面の並びと合わない。
  /// [_applyOutcome] 済みの `files.items` を辿ることで、利用者が見ている順序を
  /// そのまま使う。
  ///
  /// 1件失敗しても続ける(REQ-016)。失敗は [modifiedAtFailures] へ集め、改名の
  /// 失敗とは別に提示できるようにする。
  Future<void> _shiftModifiedAtOfSuccesses(RenameOutcome outcome) async {
    final executorRef = executor;
    if (!_shiftModifiedAt || executorRef is! ModifiedAtWriter) return;
    final writer = executorRef as ModifiedAtWriter;
    final renamedHandles = {
      for (final success in outcome.successes) success.handle,
    };
    if (renamedHandles.isEmpty) return;

    final base = _clock();
    final failures = <FileEntry>[];
    final replacements = <FileEntry, FileEntry>{};
    var index = 0;
    for (final item in files.items) {
      final handle = item.sourceHandle;
      if (handle == null || !renamedHandles.contains(handle)) continue;
      final value = base.add(modifiedAtInterval * index);
      index++;
      final error = await writer.setModifiedAt(handle, value);
      if (error != null) {
        failures.add(item);
        continue;
      }
      replacements[item] = _withModifiedAt(item, value);
    }
    _modifiedAtFailures = List.unmodifiable(failures);
    files.replaceItems(replacements);
  }

  /// 成功した改名と、復元できず一時名のまま残った実体だけを一覧へ反映する。
  void _applyOutcome(
    RenameOutcome outcome,
    Map<RenameRequest, FileEntry> sources,
  ) {
    final replacements = <FileEntry, FileEntry>{};
    for (final success in outcome.successes) {
      final source = sources[success.request];
      if (source == null) continue;
      replacements[source] = _renamedEntry(
        source,
        name: success.newName,
        handle: success.handle,
      );
    }
    for (final stranded in outcome.stranded) {
      final source = sources[stranded.request];
      if (source == null) continue;
      replacements[source] = _renamedEntry(
        source,
        name: stranded.currentName,
        handle: stranded.request.handle,
      );
    }
    files.replaceItems(replacements);
  }

  void _applyUndoOutcome(UndoOutcome outcome) {
    final byHandle = <String, FileEntry>{
      for (final item in files.items)
        if (item.sourceHandle != null) item.sourceHandle!: item,
    };
    final replacements = <FileEntry, FileEntry>{};
    for (final success in outcome.successes) {
      final source = byHandle[success.rename.handle];
      if (source == null) continue;
      replacements[source] = _renamedEntry(
        source,
        name: success.rename.originalName,
        handle: success.handle,
      );
    }
    files.replaceItems(replacements);
  }

  void _offerUndo(RenameOutcome outcome) {
    if (!outcome.successes.any(_changedRename)) return;
    _undoableOutcome = outcome;
    _undoDeadline = _clock().add(undoWindow);
    _undoExpiryTimer = Timer(undoWindow, () {
      _clearUndo();
      notifyListeners();
    });
  }

  void _clearUndo() {
    _undoExpiryTimer?.cancel();
    _undoExpiryTimer = null;
    _undoableOutcome = null;
    _undoDeadline = null;
  }

  @override
  void dispose() {
    _clearUndo();
    super.dispose();
  }

  static FileEntry _renamedEntry(
    FileEntry source, {
    required String name,
    required String handle,
  }) => FileEntry(
    name: name,
    createdAt: source.createdAt,
    modifiedAt: source.modifiedAt,
    size: source.size,
    selected: source.selected,
    sourceHandle: handle,
    sourceLocation: source.sourceLocation,
    sourceFolder: source.sourceFolder,
  );

  static FileEntry _withModifiedAt(FileEntry source, DateTime modifiedAt) =>
      FileEntry(
        name: source.name,
        createdAt: source.createdAt,
        modifiedAt: modifiedAt,
        size: source.size,
        selected: source.selected,
        sourceHandle: source.sourceHandle,
        sourceLocation: source.sourceLocation,
        sourceFolder: source.sourceFolder,
      );

  static bool _changedRename(SuccessfulRename rename) =>
      rename.originalName != rename.newName;

  List<FileEntry> _entriesWithSelection() => [
    for (final item in files.items)
      FileEntry(
        name: item.name,
        createdAt: item.createdAt,
        modifiedAt: item.modifiedAt,
        size: item.size,
        selected: files.selectedOf(item),
        sourceHandle: item.sourceHandle,
        sourceLocation: item.sourceLocation,
        sourceFolder: item.sourceFolder,
      ),
  ];

  static bool _hasEmptyBase(FileEntry file, String resultName) {
    final extension = file.extension;
    return extension.isEmpty ? resultName.isEmpty : resultName == '.$extension';
  }
}
