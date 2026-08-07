import 'rename_executor.dart';
import 'rename_plan.dart';

/// 目標名に到達した改名(005 spec `terms`: 実行結果 の「成功した改名」)。
///
/// 記録の対象は改名要求であって内部ステップではないため、一時名への改名・
/// 一時名からの改名はここに現れない(REQ-005)。
class SuccessfulRename {
  const SuccessfulRename({
    required this.request,
    required this.handle,
    required this.originalName,
    required this.newName,
  });

  /// 対応する改名要求。
  final RenameRequest request;

  /// 改名後のハンドル。巻き戻しはこのハンドルに対して行う(REQ-006)。
  final String handle;

  /// 実行前の名前。巻き戻しの戻し先(REQ-006)。
  final String originalName;

  /// 改名後の名前。**要求した目標名**であって、ポートの戻り値の名前ではない
  /// (REQ-018)。
  final String newName;
}

/// 失敗した改名とその理由(REQ-002)。
class FailedRename {
  const FailedRename({
    required this.request,
    required this.attemptedName,
    required this.temporary,
    required this.error,
  });

  /// 失敗した改名要求。
  final RenameRequest request;

  /// 失敗した時点で付けようとしていた名前(一時名のこともある)。
  final String attemptedName;

  /// 一時名への改名(内部ステップ)で失敗したか。
  final bool temporary;

  /// 失敗の理由。
  final RenameError error;
}

/// 停止によって一時名を持ったまま残ったファイル(REQ-005)。
///
/// 元の名前へ戻すことを試み、**戻せなかった**ものだけがここに現れる。
class StrandedFile {
  const StrandedFile({
    required this.request,
    required this.currentName,
    required this.error,
  });

  /// 一時名のまま残った改名要求。
  final RenameRequest request;

  /// そのファイルの現在の名前(一時名)。
  final String currentName;

  /// 元の名前へ戻せなかった理由。
  final RenameError error;
}

/// 実行がどこまで進んだかの記録(005 spec `terms`: 実行結果)。
///
/// 「成功した改名」「失敗した改名」「未実行のまま残った改名」の3者を型で
/// 区別する(REQ-003)。
class RenameOutcome {
  RenameOutcome({
    required List<SuccessfulRename> successes,
    required this.failure,
    required List<RenameRequest> notExecuted,
    required List<StrandedFile> stranded,
  }) : successes = List.unmodifiable(successes),
       notExecuted = List.unmodifiable(notExecuted),
       stranded = List.unmodifiable(stranded);

  /// 目標名に到達した改名(実行順)。停止しても元に戻さない(REQ-002)。
  final List<SuccessfulRename> successes;

  /// 失敗した改名とその理由。失敗が無ければ `null`。
  final FailedRename? failure;

  /// 未実行のまま残った改名(入力順)。
  final List<RenameRequest> notExecuted;

  /// 一時名のまま残り、元の名前へも戻せなかったファイル(REQ-005)。
  final List<StrandedFile> stranded;

  /// 失敗により途中で停止したか(REQ-002)。
  bool get stopped => failure != null;
}

/// 実行計画に従って1件ずつ改名する(OP-002)。
///
/// - 計画の順に1件ずつ行い、成功のたびに改名要求のハンドルを更新する
///   (REQ-001 / INV-005)。
/// - 1件でも失敗したらその時点で停止し、**成功済みの改名は元に戻さない**
///   (REQ-002)。
/// - 停止で一時名を持つファイルが残る場合は元の名前へ戻すことを試み、
///   戻せなければ現在の名前を実行結果に含める(REQ-005)。
///
/// 実ファイルへの作用は [executor] だけが持つ。この関数は `package:flutter`
/// にも `dart:io` にも依存しない(CON-001)。
Future<RenameOutcome> executePlan(
  RenamePlan plan,
  RenameExecutor executor,
) async {
  final successes = <SuccessfulRename>[];
  // 今まさに一時名を持っている要求(要求 → その一時名)。
  final atTemporaryName = <RenameRequest, String>{};
  FailedRename? failure;

  for (final step in plan.steps) {
    if (step.kind == RenameStepKind.unchanged) {
      // 実体は既に目標名。ポートを呼ばずに成功として記録する(INV-003)。
      successes.add(
        SuccessfulRename(
          request: step.request,
          handle: step.request.handle,
          originalName: step.request.originalName,
          newName: step.request.targetName,
        ),
      );
      continue;
    }

    final result = await executor.rename(step.request.handle, step.newName);
    switch (result) {
      case Renamed(:final newHandle):
        // ハンドルは改名で変わりうる。以降の操作は新しい値を使う(REQ-001 / INV-005)。
        step.request.handle = newHandle;
        if (step.kind == RenameStepKind.temporary) {
          atTemporaryName[step.request] = step.newName;
        } else {
          atTemporaryName.remove(step.request);
          successes.add(
            SuccessfulRename(
              request: step.request,
              handle: newHandle,
              // 名前はポートの戻り値ではなく要求した目標名を正とする(REQ-018)。
              originalName: step.request.originalName,
              newName: step.request.targetName,
            ),
          );
        }
      case RenameFailed(:final error):
        failure = FailedRename(
          request: step.request,
          attemptedName: step.newName,
          temporary: step.kind == RenameStepKind.temporary,
          error: error,
        );
    }
    if (failure != null) break;
  }

  final stranded = <StrandedFile>[];
  if (failure != null) {
    // REQ-005: 停止で一時名が残ったら元の名前へ戻すことを試みる。一時名は成功した
    // 改名として記録していないので、この戻しは INV-003 を破らない。
    for (final entry in atTemporaryName.entries) {
      final request = entry.key;
      final result = await executor.rename(
        request.handle,
        request.originalName,
      );
      switch (result) {
        case Renamed(:final newHandle):
          request.handle = newHandle;
        case RenameFailed(:final error):
          stranded.add(
            StrandedFile(
              request: request,
              currentName: entry.value,
              error: error,
            ),
          );
      }
    }
  }

  final succeeded = successes.map((s) => s.request).toSet();
  final notExecuted = [
    for (final request in plan.requests)
      if (!succeeded.contains(request) && !identical(request, failure?.request))
        request,
  ];

  return RenameOutcome(
    successes: successes,
    failure: failure,
    notExecuted: notExecuted,
    stranded: stranded,
  );
}
