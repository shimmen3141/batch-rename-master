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
  });

  final FileListController files;
  final RenameExecutor executor;
  final DateTime Function() _clock;
  bool _running = false;
  bool get isRunning => _running;

  List<FileEntry> _excludedEmptyNames = const [];
  List<FileEntry> get excludedEmptyNames => _excludedEmptyNames;

  /// [force] では 001 の自動解決後に空名を除外する(REQ-022)。
  Future<RenameOutcome?> execute({required bool force}) async {
    if (_running) return null;
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
        if (_hasEmptyBase(entry.source, entry.resultName)) {
          excluded.add(entry.source);
          continue;
        }
        final request = RenameRequest(
          handle: entry.source.sourceHandle ?? entry.source.name,
          originalName: entry.source.name,
          targetName: entry.resultName,
        );
        requests.add(request);
        final actual = entry.source.sourceHandle == null
            ? files.items.firstWhere(
                (item) => item.name == entry.source.name,
                orElse: () => entry.source,
              )
            : actualByHandle[entry.source.sourceHandle];
        if (actual != null) sources[request] = actual;
      }
      _excludedEmptyNames = List.unmodifiable(excluded);
      final outcome = await executePlan(planExecution(requests), executor);
      _applyOutcome(outcome, sources);
      return outcome;
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
