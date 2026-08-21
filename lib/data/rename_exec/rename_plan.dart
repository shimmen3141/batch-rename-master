import 'occupied_names.dart';

/// 1ファイルの改名を表す組(005 spec `terms`: 改名要求)。
///
/// ハンドル・実行前の名前(元の名前)・目標名からなる。目標名は 001 が確定した
/// 生成後フルネーム。
///
/// [handle] は**改名のたびに更新される**(INV-005)。改名するとハンドルが変わる
/// ため、更新しないと後続の改名も巻き戻しも古いハンドルを指して壊れる
/// (ADR-001「実機で確認した事実」2)。
class RenameRequest {
  RenameRequest({
    required this.handle,
    required this.originalName,
    required this.targetName,
    this.folder,
  });

  /// 所属folderの識別子(005 spec `terms`: folder)。
  ///
  /// **004 が供給する不透明な値**(004 REQ-013 の所属folderハンドル)をそのまま
  /// 持つ。005 は**等値だけ**で同一性を判定し、**ハンドル文字列から導出しない** —
  /// ハンドルは不透明値であり、path として解釈してよい保証が無い(OQ-004)。
  ///
  /// `null` は「不明」という単一のfolderを表す。
  ///
  /// 改名でハンドルは変わるが、**folderは変わらない**(改名は同じfolderの中で
  /// 完結する)。したがって [handle] と違い実行中に書き換えない。
  final String? folder;

  /// 実体の現在の識別子(INV-005)。
  ///
  /// 実行が改名に成功するたびに、改名後のハンドルへ書き換える。書き換えるのは
  /// 実行オーケストレーション([executePlan])だけ。
  String handle;

  /// 実行前の名前。巻き戻しの戻し先であり、実行中に変化しない(REQ-006)。
  final String originalName;

  /// 目標名。改名後の名前はこの値を正とする(REQ-018)。
  final String targetName;

  @override
  String toString() => 'RenameRequest($originalName -> $targetName @ $handle)';
}

/// [RenameStep] の種別。
enum RenameStepKind {
  /// 改名要求の目標名への改名。成功すれば実行結果の「成功した改名」になる。
  target,

  /// 循環を解くための一時名への改名。**内部ステップ**であり、成功した改名として
  /// 記録しない(005 spec `terms`: 一時名 / REQ-005)。
  temporary,

  /// 目標名が既に現在の名前と等しく、実ファイルへの操作が不要な改名。
  ///
  /// ポートを呼ばずに成功として扱う(実体は既に目標名であり INV-003 を満たす)。
  /// 呼んでしまうと「同名が既に存在する」失敗を招きうるため呼ばない。
  unchanged,
}

/// 実行計画の1ステップ(実ファイル1回ぶんの改名)。
class RenameStep {
  const RenameStep(this.request, this.newName, this.kind);

  /// このステップが動かす改名要求。
  final RenameRequest request;

  /// この時点で付ける名前(目標名、または一時名)。
  final String newName;

  /// ステップの種別。
  final RenameStepKind kind;

  @override
  String toString() => 'RenameStep(${request.originalName} -> $newName, $kind)';
}

/// 改名要求を実行順に並べた列(005 spec `terms`: 実行計画)。
class RenamePlan {
  RenamePlan(List<RenameRequest> requests, List<RenameStep> steps)
    : requests = List.unmodifiable(requests),
      steps = List.unmodifiable(steps);

  /// 入力の改名要求(すべて現れ、失われない。OP-001 の事後条件)。
  final List<RenameRequest> requests;

  /// 実行順のステップ。
  final List<RenameStep> steps;

  /// 一時名への改名を含むか(循環があった場合に真)。
  bool get usesTemporaryNames =>
      steps.any((s) => s.kind == RenameStepKind.temporary);
}

/// 改名要求の列から実行計画を立てる(OP-001 / REQ-004 / REQ-005)。
///
/// 各改名を行う**時点で**その目標名が既存のいずれの名前とも一致しない順序を返す。
/// **ここでいう既存の名前は占有名である**(REQ-004)。001 の `autoResolve` が保証
/// するのは**最終**状態の一意性だけなので、`a→b, b→c` のような入れ替えは順序で解く。
/// 順序の入れ替えだけでは解けない循環(`a→b, b→a`)がある場合に限り、一時名への
/// 改名を挿入して解く。**挿入する一時名は、そのfolderの生存名(占有名を含む)の
/// いずれとも一致しない。**
///
/// [occupiedNames] は**対象となるすべてのfolderについて全域**でなければならない
/// (OP-001 の事前条件 / OQ-003)。欠けていれば [ArgumentError] を投げる —
/// 「key が無い」を「占有名が空」として黙って通すと、実在名を取得できなかった
/// folder が「衝突が無い」と読まれる(REQ-027)。
///
/// 目標名がその folder の占有名に含まれる入力も事前条件違反である(OP-001 の
/// `errors`)。呼び出し側は REQ-026 の自動解決を経た目標名を渡さなければならない。
///
/// 実ファイルには触れず、`package:flutter` にも `dart:io` にも依存しない
/// (CON-001)。
RenamePlan planExecution(
  List<RenameRequest> requests, {
  required OccupiedNames occupiedNames,
}) {
  for (final r in requests) {
    // 事前条件は**黙って通さず投げる**。ここは実ファイルへ触る前の純粋な処理なので、
    // 投げても実体は変化しない。通してしまうと、占有名を無視した計画のまま実行へ
    // 進み、確認していない名前が実体へ書かれうる。
    final occupied = occupiedNames.of(r.folder);
    if (occupied.contains(r.targetName)) {
      throw ArgumentError.value(
        r.targetName,
        'requests',
        '目標名が占有名に含まれています。REQ-026 の自動解決を経ていない入力です'
            '(folder: ${r.folder})',
      );
    }
  }

  // 各要求が「今どの名前を持っているか」。実行の進行に合わせて更新する。
  final current = <RenameRequest, String>{
    for (final r in requests) r: r.originalName,
  };
  // 一時名が占有名・元の名前・目標名・既に発行した一時名のいずれとも衝突しない
  // ようにする。**folderごとに持つ** — 別folderの同名とは衝突しない。
  final usedNames = <(String?, String)>{
    for (final r in requests) ...[
      (r.folder, r.originalName),
      (r.folder, r.targetName),
      for (final name in occupiedNames.of(r.folder)) (r.folder, name),
    ],
  };

  final steps = <RenameStep>[];
  final pending = List<RenameRequest>.of(requests);

  // 「今この要求を目標名へ改名すると、他の要求が持っている名前とぶつかる」か。
  // **同じfolderの要求だけを見る** — 別folderの同名とは衝突しない(REQ-026)。
  bool blocked(RenameRequest r) => current.entries.any(
    (e) =>
        !identical(e.key, r) &&
        e.key.folder == r.folder &&
        e.value == r.targetName,
  );

  while (pending.isNotEmpty) {
    RenameRequest? ready;
    for (final r in pending) {
      if (!blocked(r)) {
        ready = r;
        break;
      }
    }
    if (ready != null) {
      final kind = current[ready] == ready.targetName
          ? RenameStepKind.unchanged
          : RenameStepKind.target;
      steps.add(RenameStep(ready, ready.targetName, kind));
      current[ready] = ready.targetName;
      pending.remove(ready);
      continue;
    }

    // 手詰まり = 循環。他の未実行の要求が欲しがっている名前を持つ要求を選び、
    // 一時名へ退避する。循環上の要求は必ずこれに当たるため、退避によって
    // 少なくとも1件が実行可能になる。退避後の名前(一時名)は誰の目標名でも
    // ないので、同じ要求が二度選ばれることはない。
    RenameRequest? blocker;
    for (final r in pending) {
      final wanted = pending.any(
        (o) =>
            !identical(o, r) &&
            o.folder == r.folder &&
            o.targetName == current[r],
      );
      if (wanted) {
        blocker = r;
        break;
      }
    }
    if (blocker == null) {
      // 前提(目標名の集合に重複が無い)が破れているときだけ到達する。安全な順序を
      // 作れないので残りをそのまま並べ、ポートの「同名が既に存在する」失敗で
      // 停止させる(既存を上書きしないこと=INV-002 はポートが守る)。
      for (final r in pending) {
        steps.add(RenameStep(r, r.targetName, RenameStepKind.target));
      }
      break;
    }

    final temporary = _temporaryName(
      current[blocker]!,
      usedNames,
      blocker.folder,
    );
    usedNames.add((blocker.folder, temporary));
    steps.add(RenameStep(blocker, temporary, RenameStepKind.temporary));
    current[blocker] = temporary;
  }

  return RenamePlan(requests, steps);
}

/// 循環を解くための一時名。利用者に見えうるので判別できる形にする
/// (OP-001 の `nondeterminism`: 文字列そのものは自由)。
///
/// 拡張子は保つ(`IMG_0010.jpg` → `IMG_0010.renaming-0.jpg`)。拡張子境界の
/// 判定は 001 の `FileEntry` と同じく「先頭以外の最後のドット」。
String _temporaryName(
  String currentName,
  Set<(String?, String)> usedNames,
  String? folder,
) {
  final dot = currentName.lastIndexOf('.');
  final base = dot <= 0 ? currentName : currentName.substring(0, dot);
  final extension = dot <= 0 ? '' : currentName.substring(dot);
  var n = 0;
  while (true) {
    final candidate = '$base.renaming-$n$extension';
    if (!usedNames.contains((folder, candidate))) return candidate;
    n++;
  }
}
