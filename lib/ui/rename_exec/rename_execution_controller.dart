import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/rename_engine.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../../data/rename_exec/rename_executor.dart';
import '../../data/rename_exec/rename_plan.dart';
import '../file_list/file_list_controller.dart';

/// UI から既存の rename orchestration を一度だけ起動する状態境界。
class RenameExecutionController extends ChangeNotifier {
  RenameExecutionController({
    required this.files,
    required this.executor,
    this._clock = DateTime.now,
    this.undoWindow = const Duration(seconds: 5),
  });

  final FileListController files;
  final RenameExecutor executor;
  final DateTime Function() _clock;
  final Duration undoWindow;
  bool _running = false;
  bool get isRunning => _running;

  RenameOutcome? _undoableOutcome;
  DateTime? _undoDeadline;
  Timer? _undoExpiryTimer;

  bool get canUndo {
    final outcome = _undoableOutcome;
    final deadline = _undoDeadline;
    return !_running &&
        outcome != null &&
        outcome.successes.any(_changedRename) &&
        deadline != null &&
        !_clock().isAfter(deadline);
  }

  List<FileEntry> _excludedEmptyNames = const [];
  List<FileEntry> get excludedEmptyNames => _excludedEmptyNames;

  /// [force] では 001 の自動解決後に空名を除外する(REQ-022)。
  ///
  /// ルールが空のときは、どの経路から呼ばれても実行を開始しない(REQ-019)。
  /// ボタンの無効化だけに頼ると、別経路から実体を変更できてしまうため、
  /// 状態境界のここでも止める。
  Future<RenameOutcome?> execute({required bool force}) async {
    if (_running || files.isRuleEmpty) return null;
    _clearUndo();
    _running = true;
    _excludedEmptyNames = const [];
    notifyListeners();
    try {
      final entries = _entriesWithSelection();
      final now = _clock();
      final resolved = force
          ? autoResolve(files.rule, entries, now)
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
        );
        requests.add(request);
        final actual = actualByHandle[entry.source.sourceHandle];
        if (actual != null) sources[request] = actual;
      }
      _excludedEmptyNames = List.unmodifiable(excluded);
      final outcome = await executePlan(planExecution(requests), executor);
      _applyOutcome(outcome, sources);
      _offerUndo(outcome);
      return outcome;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// 直前の実行で成功したrenameを期限内に一度だけ逆順で戻す。
  Future<UndoOutcome?> undo() async {
    if (!canUndo) return null;
    final outcome = _undoableOutcome!;
    _clearUndo();
    _running = true;
    notifyListeners();
    try {
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
      ),
  ];

  static bool _hasEmptyBase(FileEntry file, String resultName) {
    final extension = file.extension;
    return extension.isEmpty ? resultName.isEmpty : resultName == '.$extension';
  }
}
