import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../../data/rename_exec/rename_execution.dart';
import '../common/design_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'rename_warning_view.dart';

// ---------------------------------------------------------------------------
// 008:T14 実行前確認dialogと、再採番の結果の詳細。
//
// **判定は動かさない。** 何を警告するか(001 / 005 REQ-009)、確認を挟むか
// (005 REQ-011)、強制実行で何が起きるか(001 の自動解決 / 005 REQ-022)は正本の
// まま。ここは「何を聞かれていて、選ぶと何が起きるか」の書き方と見せ方だけを持つ
// (005 spec「自由とする点」)。見た目の土台は `docs/design/Bulk Renamer.html` の
// 「実行前の確認」。
// ---------------------------------------------------------------------------

/// 実行前確認dialog(005 REQ-011)。
const Key renameConfirmationDialogKey = Key('rename-confirmation-dialog');

/// 確認dialogの「キャンセル」(実ファイルを1件も変えない)。
const Key renameCancelKey = Key('rename-cancel');

/// 確認dialogの実行button(001 の自動解決が返した名前で実行する)。
const Key renameForceKey = Key('rename-force');

/// 確認dialogの種類ごとの枠。
Key confirmationIssueKey(int index) => Key('confirmation-issue-$index');

/// 強制実行buttonの文字色(design 土台の `dlgConfirmFg`)。赤い面の上で読める濃い赤。
const Color confirmDangerForeground = Color(0xFF2B0707);

/// 確認dialogの種類1つ分(見出し・実行すると何が起きるか・対象)。
class ConfirmationIssue {
  const ConfirmationIssue({
    required this.title,
    required this.consequence,
    required this.targets,
    this.resolves = false,
  });

  /// 種別名と件数(行・詳細と同じ語彙。`008:T19` が文言の正本)。
  final String title;

  /// **このまま実行するとどう処理されるか**(001 の自動解決 / 005 REQ-022)。
  final String consequence;

  /// 対象ファイルの字面([fileLabel])。対象をファイルで持たない種別は空。
  final List<String> targets;

  /// 自動解決で名前を変える種別か(重複・桁不足)。実行buttonの文言を決める。
  final bool resolves;
}

/// [warnings] を**種別ごとに1つ**へまとめ、強制実行したときの処理を添える。
///
/// 1ファイル1行で並べると、30件の重複で同じ文が30行続き、何を選ばされているのかが
/// 読めなくなる(`013:T07` の U5)。種別の順序は 001 が返した順。
///
/// - 名前が空になるファイルは**改名されない**(005 REQ-022)ので、同じファイルの
///   基準日時不明は「空にして改名します」の側へ数えない(REQ-021 規則1 と同じ畳み方)。
/// - **日時不明でも名前が変わらないファイルがある**(`[元の名前][作成日時]` で作成日時が
///   取れないと、生成後名が現在名と同じになる)。[unchangedFiles] に入るファイルは
///   「改名しません」の枠へ分ける — 改名されないファイルを「改名します」と書かない
///   (独立review attempt 1 の T14-R1)。[unchangedFiles] は呼び出し側が
///   `rowHasNoChange`(005 REQ-019 の判定)で作って渡す。
/// - 桁不足はトークンに対する警告で、対象ファイルを持たない。複数あれば最も大きい
///   必要桁数を書く。**`008:T21` / `T52` 以後、UIからは届かない**(桁数を下限より
///   小さくできない)が、001 の判定は安全網として残るので、届いたときも書けるようにする。
List<ConfirmationIssue> confirmationIssues(
  List<Warning> warnings, {
  Iterable<FileEntry> amongFiles = const <FileEntry>[],
  Iterable<FileEntry> unchangedFiles = const <FileEntry>[],
}) {
  final unchanged = Set<FileEntry>.identity()..addAll(unchangedFiles);
  final ambiguous = ambiguousFileNames(
    amongFiles.isEmpty ? warnings.map(warningFile).nonNulls : amongFiles,
  );
  String label(FileEntry file) =>
      fileLabel(file, withLocation: ambiguous.contains(file.name));

  final excluded = Set<FileEntry>.identity()
    ..addAll(warnings.whereType<EmptyNameWarning>().map((w) => w.file));

  final order = <String>[];
  final kinds = <String, String>{};
  final files = <String, Set<FileEntry>>{};
  var requiredDigits = 0;

  void put(String key, String kind, FileEntry? file) {
    if (!kinds.containsKey(key)) {
      order.add(key);
      kinds[key] = kind;
      files[key] = Set<FileEntry>.identity();
    }
    if (file != null) files[key]!.add(file);
  }

  for (final warning in warnings) {
    switch (warning) {
      case DuplicateWarning(:final file):
        put('duplicate', warningKindLabel(warning), file);
      case DigitShortageWarning(requiredDigits: final digits):
        if (digits > requiredDigits) requiredDigits = digits;
        put('digit', warningKindLabel(warning), null);
      case EmptyNameWarning(:final file):
        put('empty', warningKindLabel(warning), file);
      case MissingSourceDateWarning(:final file, :final token):
        if (excluded.contains(file)) continue;
        put(
          unchanged.contains(file)
              ? 'date-same-${token.source.name}'
              : 'date-${token.source.name}',
          warningKindLabel(warning),
          file,
        );
    }
  }

  return <ConfirmationIssue>[
    for (final key in order)
      if (key == 'duplicate')
        ConfirmationIssue(
          title: '${kinds[key]} ${files[key]!.length} 件',
          consequence: '重ならないように、名前の末尾へ (1) (2) … を付けて改名します',
          targets: [for (final f in files[key]!) label(f)],
          resolves: true,
        )
      else if (key == 'digit')
        ConfirmationIssue(
          title: kinds[key]!,
          consequence: '連番を $requiredDigits 桁に広げて改名します',
          targets: const <String>[],
          resolves: true,
        )
      else if (key == 'empty')
        ConfirmationIssue(
          title: '${kinds[key]} ${files[key]!.length} 件',
          consequence: '変更後の名前が空になるため、これらのファイルは改名しません',
          targets: [for (final f in files[key]!) label(f)],
        )
      else if (key.startsWith('date-same-'))
        ConfirmationIssue(
          title: '${kinds[key]} ${files[key]!.length} 件',
          consequence: '日時が取れず名前が変わらないため、これらのファイルは改名しません',
          targets: [for (final f in files[key]!) label(f)],
        )
      else
        ConfirmationIssue(
          title: '${kinds[key]} ${files[key]!.length} 件',
          consequence: 'その日時の部分を空にして改名します',
          targets: [for (final f in files[key]!) label(f)],
        ),
  ];
}

/// 確認dialogの説明文(何を聞かれているか)。
String confirmationDescription(List<Warning> warnings) {
  final files = Set<FileEntry>.identity()
    ..addAll(warnings.map(warningFile).nonNulls);
  final head = files.isEmpty ? '問題があります。' : '${files.length} 件のファイルに問題があります。';
  return '$headこのまま実行すると、次のように処理します。';
}

/// 実行buttonの文言。**名前を変えて解決する種別があるときだけ「自動解決」と書く** —
/// 名前が空・日時不明だけなら何も解決しないので、そう書くと偽りになる。
String confirmationActionLabel(List<ConfirmationIssue> issues) =>
    issues.any((i) => i.resolves) ? '自動解決して実行' : 'このまま実行';

/// 実行前確認dialogを開き、実行を選んだら `true` を返す(005 REQ-011)。
///
/// キャンセル・戻る操作・外側のタップでは `false`。
Future<bool> showRenameConfirmation(
  BuildContext context,
  List<Warning> warnings, {
  Iterable<FileEntry> amongFiles = const <FileEntry>[],
  Iterable<FileEntry> unchangedFiles = const <FileEntry>[],
}) async {
  final issues = confirmationIssues(
    warnings,
    amongFiles: amongFiles,
    unchangedFiles: unchangedFiles,
  );
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: designDialogBarrierColor,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return DesignDialog(
        key: renameConfirmationDialogKey,
        title: '実行前の確認',
        description: confirmationDescription(warnings),
        body: [
          for (final (index, issue) in issues.indexed)
            _IssueCard(key: confirmationIssueKey(index), issue: issue),
        ],
        actions: [
          Expanded(
            flex: 10,
            child: DialogButton(
              key: renameCancelKey,
              label: 'キャンセル',
              background: colors.surfaceElevated,
              foreground: colors.textPrimary,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 13,
            child: DialogButton(
              key: renameForceKey,
              label: confirmationActionLabel(issues),
              // **警告を押し切る操作だと見分けられる色にする**(design 土台)。
              background: colors.danger,
              foreground: confirmDangerForeground,
              bold: true,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// 再採番の結果の詳細dialog(005 REQ-024)。
const Key renumberedDetailDialogKey = Key('renumbered-detail-dialog');

/// 結果の通知の、再採番の詳細を開く入口。
const Key renumberedDetailLinkKey = Key('renumbered-detail-link');

/// 再採番の結果の詳細の「閉じる」。
const Key renumberedDetailCloseKey = Key('renumbered-detail-close');

/// 再採番の結果の詳細の1件(確認した名前 → 結果の名前)。
Key renumberedDetailRowKey(int index) => Key('renumbered-detail-row-$index');

/// 再採番が起きた改名を**全件**並べる(005 REQ-024)。
///
/// 結果の通知の中へ並べていたときは、件数が多いと通知が縦に伸びた(高さ 96px で
/// 打ち切ってscroll)。通知には件数と入口だけを置き、名前はここで読む
/// (2026-10-02 の開発者の決定 A)。**打ち切らない** — 先頭数件で止めると、
/// 残りは黙って別の名前になる。
Future<void> showRenumberedDetail(
  BuildContext context,
  List<SuccessfulRename> renumbered,
) {
  return showDialog<void>(
    context: context,
    barrierColor: designDialogBarrierColor,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return DesignDialog(
        key: renumberedDetailDialogKey,
        title: '名前が変わったファイル',
        description:
            '実行中に同じ名前のファイルが作られたため、確認した名前とは別の名前で'
            '改名しました(${renumbered.length} 件)。',
        body: [
          for (final (index, s) in renumbered.indexed)
            Padding(
              key: renumberedDetailRowKey(index),
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: s.confirmedName,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    TextSpan(
                      text: ' → ',
                      style: TextStyle(color: colors.textMuted),
                    ),
                    TextSpan(
                      text: s.newName,
                      style: TextStyle(
                        color: colors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: AppFontSize.body),
              ),
            ),
        ],
        actions: [
          Expanded(
            child: DialogButton(
              key: renumberedDetailCloseKey,
              label: '閉じる',
              background: colors.surfaceElevated,
              foreground: colors.textPrimary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ),
        ],
      );
    },
  );
}

/// 種類1つ分の枠([IssueCard])。対象は件数ぶん行を増やさず、1つの段落へ並べる。
class _IssueCard extends StatelessWidget {
  const _IssueCard({super.key, required this.issue});

  final ConfirmationIssue issue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IssueCard(
      title: issue.title,
      description: issue.consequence,
      // **対象は件数ぶん行を増やさず、1つの段落へ並べる。** 30件でも
      // 種類の枠が縦に伸びすぎず、どのファイルかは読める。
      child: issue.targets.isEmpty
          ? null
          : Text(
              issue.targets.join('、'),
              style: TextStyle(
                color: colors.textMuted,
                fontSize: AppFontSize.small,
                height: 1.5,
              ),
            ),
    );
  }
}
