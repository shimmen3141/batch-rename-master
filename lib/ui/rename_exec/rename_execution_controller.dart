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
      for (final entry in resolved) {
        if (_hasEmptyBase(entry.source, entry.resultName)) {
          excluded.add(entry.source);
          continue;
        }
        requests.add(
          RenameRequest(
            handle: entry.source.sourceHandle ?? entry.source.name,
            originalName: entry.source.name,
            targetName: entry.resultName,
          ),
        );
      }
      _excludedEmptyNames = List.unmodifiable(excluded);
      return await executePlan(planExecution(requests), executor);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

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
