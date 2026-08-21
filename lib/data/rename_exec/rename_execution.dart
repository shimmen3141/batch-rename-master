import '../../core/rename_engine.dart';

import 'occupied_names.dart';
import 'rename_executor.dart';
import 'rename_plan.dart';

export 'occupied_names.dart';

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
    this.confirmedTargetName,
  });

  /// 明示された確認した目標名。`null` なら [newName] と同じとみなす。
  final String? confirmedTargetName;

  /// 利用者が確認した目標名(005 spec `terms`: 確認した目標名)。
  ///
  /// 再採番(REQ-023)が起きなかった改名では [newName] と等しい。
  String get confirmedName => confirmedTargetName ?? newName;

  /// 実行中の再採番で、確認した名前と違う名前になったか(REQ-024)。
  ///
  /// 真のとき、利用者へ**どの項目がどの名前になったか**を提示しなければならない。
  /// **黙って別の名前にしない。**
  bool get renumbered => confirmedName != newName;

  /// 対応する改名要求。
  final RenameRequest request;

  /// 改名後のハンドル。巻き戻しはこのハンドルに対して行う(REQ-006)。
  final String handle;

  /// 実行前の名前。巻き戻しの戻し先(REQ-006)。
  final String originalName;

  /// 改名後の名前。**アプリが決めた名前**であって、ポートの戻り値の名前ではない
  /// (REQ-018)。再採番が起きた場合は再採番後の名前になる(INV-003)。
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

/// 巻き戻しに成功した1件。実体は[rename]の[SuccessfulRename.originalName]へ戻り、
/// [handle]は戻した後の最新ハンドルである(REQ-006 / INV-004)。
class SuccessfulUndo {
  const SuccessfulUndo({required this.rename, required this.handle});

  final SuccessfulRename rename;
  final String handle;
}

/// 巻き戻しが停止した1件と理由(REQ-008)。
class FailedUndo {
  const FailedUndo({required this.rename, required this.error});

  final SuccessfulRename rename;
  final RenameError error;
}

/// 期限内の単一step巻き戻し結果。
class UndoOutcome {
  UndoOutcome({required List<SuccessfulUndo> successes, required this.failure})
    : successes = List.unmodifiable(successes);

  final List<SuccessfulUndo> successes;
  final FailedUndo? failure;
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
  RenameExecutor executor, {
  required OccupiedNames occupiedNames,
  RenumberCandidate renumber = defaultRenumber,
  int renumberLimit = defaultRenumberLimit,
}) async {
  // OP-002 の事前条件(OQ-003): occupiedNames は全域である。**実ファイルへ触る前に
  // 確かめる。** 生存名は再採番のときにしか組み立てないので、そこまで遅らせると
  // 「衝突が起きたときだけ落ちる」という最悪の形になる。ここで投げれば実体は
  // 変化していない。
  for (final request in plan.requests) {
    occupiedNames.of(request.folder);
  }

  final successes = <SuccessfulRename>[];
  // 今まさに一時名を持っている要求(要求 → その一時名)。
  final atTemporaryName = <RenameRequest, String>{};
  FailedRename? failure;

  // 生存名(005 spec `terms`)をfolderごとに組み立てる。組み立てるのは execute
  // である(OP-002)。実行が進むにつれて (2)(3)(5) が動くので、都度作り直す。
  final live = _LiveNames(plan: plan, occupied: occupiedNames);

  for (final step in plan.steps) {
    if (step.kind == RenameStepKind.unchanged) {
      // 実体は既に目標名。ポートを呼ばずに成功として記録する(INV-003)。
      // 生存名へは `recordSettled` しない — この分岐は
      // `originalName == targetName` のときしか生じない(`planExecution` の
      // 性質)ので、未実行として足す (2)(3) と結果名が一致するためである。
      // **その等式が崩れたらここも記録が要る。**
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

    // REQ-023: 目標名へ進める改名だけが再採番の対象である。一時名への改名は
    // 内部ステップなので、衝突しても再採番しない(利用者が確認していない名前を
    // 内部ステップで作らない)。
    final renumberable = step.kind == RenameStepKind.target;
    var attemptName = step.newName;
    var attempts = 0;
    // 実行時に衝突が観測された名前。生存名へ足して、次の候補が同じ名前へ
    // 戻らないようにする。**生存名は実行前の観測から作るので、他processが
    // 今まさに作った名前は入っていない。**
    final observedConflicts = <String>{};

    while (true) {
      final result = await executor.rename(step.request.handle, attemptName);
      if (result case Renamed(:final newHandle)) {
        // ハンドルは改名で変わりうる。以降の操作は新しい値を使う(REQ-001 / INV-005)。
        step.request.handle = newHandle;
        if (step.kind == RenameStepKind.temporary) {
          atTemporaryName[step.request] = attemptName;
        } else {
          atTemporaryName.remove(step.request);
          successes.add(
            SuccessfulRename(
              request: step.request,
              handle: newHandle,
              // 名前はポートの戻り値ではなくアプリが決めた名前を正とする(REQ-018)。
              originalName: step.request.originalName,
              newName: attemptName,
              confirmedTargetName: step.request.targetName,
            ),
          );
          live.recordSettled(step.request, attemptName);
        }
        break;
      }

      final error = (result as RenameFailed).error;
      // **自己衝突をここで判定しない。** 大文字小文字や正規化だけが違う改名で
      // 目標名が「実在する」ことになるかはfilesystem依存で、アプリ側の名前比較で
      // は代用できない(`013:T11`のreview attempt 1〜3)。**判定できるのは
      // filesystemに触るport側だけ**であり、portは自己衝突を`nameConflict`に
      // しない(REQ-025)。ここへ届く`nameConflict`は本物の衝突である。
      final retriable =
          renumberable &&
          error.kind == RenameErrorKind.nameConflict &&
          attempts < renumberLimit;
      if (!retriable) {
        failure = FailedRename(
          request: step.request,
          attemptedName: attemptName,
          temporary: step.kind == RenameStepKind.temporary,
          error: error,
        );
        break;
      }

      // 事前検出をすり抜けた衝突。生存名に対する次の候補名で試し直す(REQ-023)。
      // 候補は**確認した目標名から数え直す**。直前の試行名を base にすると
      // ` (n)` が入れ子になる。
      observedConflicts.add(attemptName);
      final next = renumber(step.request, {
        ...live.namesFor(step.request),
        ...observedConflicts,
      });
      if (next == null) {
        failure = FailedRename(
          request: step.request,
          attemptedName: attemptName,
          temporary: false,
          error: error,
        );
        break;
      }
      attemptName = next;
      attempts++;
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

/// 成功した改名だけを実行と逆順に、新しいハンドルから元名へ戻す(REQ-006)。
///
/// 1件失敗したら停止し、既に戻した分は戻ったままにする(REQ-008)。期限の判定と
/// 単一step状態はUI controllerが所有し、この純粋なorchestrationはI/O順だけを扱う。
Future<UndoOutcome> undoSuccessfulRenames(
  List<SuccessfulRename> renames,
  RenameExecutor executor,
) async {
  final undone = <SuccessfulUndo>[];
  FailedUndo? failure;
  for (final rename in renames.reversed) {
    final result = await executor.rename(rename.handle, rename.originalName);
    switch (result) {
      case Renamed(:final newHandle):
        undone.add(SuccessfulUndo(rename: rename, handle: newHandle));
      case RenameFailed(:final error):
        failure = FailedUndo(rename: rename, error: error);
    }
    if (failure != null) break;
  }
  return UndoOutcome(successes: undone, failure: failure);
}

/// 実行中の再採番で、次の候補名を求める操作(005 contract OP-002 の `renumber`)。
///
/// 第1引数は**改名要求**であり、直前に試した名前ではない。候補は毎回
/// [RenameRequest.targetName](確認した目標名)から数え直す — そうしないと
/// ` (n)` の n が進まず、`x (1) (1).jpg` のように接尾辞が入れ子になる
/// (`x (2).jpg` が正しい)。契約の `OP-002` が `renumber: (改名要求, 生存名)`
/// と書いているのはこのためである。
///
/// 第2引数はそのfolderの**生存名**(実行時に観測した衝突名を含む)。`null` を
/// 返すと、呼び出し側はその改名要求を失敗として記録する(REQ-023)。
typedef RenumberCandidate =
    String? Function(RenameRequest request, Set<String> liveNames);

/// 既定の再採番(001 の自動解決規則をそのまま使う)。
String? defaultRenumber(RenameRequest request, Set<String> liveNames) =>
    nextCandidateName(request.targetName, liveNames);

/// 再採番の試行上限(005 contract `open_questions` OQ-001)。
///
/// 1件の改名要求について、`nameConflict` を受けて名前を変えて試し直す回数の上限。
/// **8 とする。** 事前検出(REQ-026)を通ったうえで衝突するのは、他processが
/// ちょうどその名前を作った場合だけである。それが 8 回続く状況は、名前が
/// 埋まっているのではなく**別の何かが起きている**(監視appが書き戻している、
/// filesystem が誤った errno を返している等)ので、試し続けるより止めて
/// 理由を見せるほうがよい。
const int defaultRenumberLimit = 8;

/// 生存名(005 spec `terms`)をfolderごとに保持する。
///
/// 5要素の和である。(1) 占有名、(2) 未実行の改名要求の確認した目標名、
/// (3) 未実行の選択fileの現在名、(4) その計画が使う一時名、
/// (5) この実行ですでに確定した結果名。
///
/// (4) は「その時点で存在する一時名」ではなく**計画が使う一時名すべて**を入れる。
/// これから使う予定の一時名を再採番が先取りすると、後続の一時名への改名が
/// `nameConflict` になり、REQ-023 が一時名を再採番対象から外しているために
/// 停止する(005 contract `open_questions` OQ-005)。
class _LiveNames {
  _LiveNames({required this.plan, required this.occupied});

  final RenamePlan plan;
  final OccupiedNames occupied;

  /// 確定した結果名(要求 → その名前)。(5)
  final Map<RenameRequest, String> _settled = {};

  void recordSettled(RenameRequest request, String name) {
    _settled[request] = name;
  }

  /// [request] が属するfolderの生存名。
  Set<String> namesFor(RenameRequest request) {
    final folder = request.folder;
    // **key が無ければ投げる**(OQ-003)。「占有名が空」として黙って通すと、
    // 実在名を取得できなかったfolderが「衝突が無い」と読まれる(REQ-027)。
    final names = <String>{...occupied.of(folder)};
    for (final other in plan.requests) {
      if (identical(other, request)) continue;
      if (other.folder != folder) continue;
      final settled = _settled[other];
      if (settled != null) {
        names.add(settled); // (5)
      } else {
        names.add(other.targetName); // (2)
        names.add(other.originalName); // (3)
      }
    }
    for (final step in plan.steps) {
      if (step.kind != RenameStepKind.temporary) continue;
      if (step.request.folder != folder) continue;
      names.add(step.newName); // (4) 使用予定を含む
    }
    return names;
  }
}
