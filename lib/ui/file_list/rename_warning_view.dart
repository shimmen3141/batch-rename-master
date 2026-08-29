import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';

/// ルール未設定の案内帯(警告が 0 件でない状態の代わりに出る)。
const Key ruleNotConfiguredKey = Key('rule-not-configured');

/// 一覧全体の警告件数(常に見える。押すと全件の詳細が開く。005 REQ-009 (3))。
const Key warningCountKey = Key('warning-count');

/// 行の警告(005 REQ-009 (1))。押すと全件の詳細が開く。
const Key rowWarningKey = Key('row-warning');

/// ルールを直せば消える原因の説明(005 REQ-009 (2))。件数ぶん繰り返さない。
const Key ruleWarningNoticeKey = Key('rule-warning-notice');

/// 全件と説明の詳細(005 REQ-009 (3))。
const Key warningDetailDialogKey = Key('warning-detail-dialog');

/// 提示 1 件分(種別名と本文)。001 の警告と 1 対 1 とは限らない(REQ-021)。
class WarningPresentation {
  const WarningPresentation({required this.kindLabel, required this.message});

  final String kindLabel;
  final String message;
}

/// 001 が返した警告を、利用者へ見せる単位へまとめる(REQ-021)。
///
/// 同じファイルに空名警告と基準日時不明警告がともに該当する場合、001 は判定として
/// 2 件を返すが、利用者から見れば「その日時が取れないから名前が空になる」という
/// 1 つの出来事なので、結果(名前が空になる)と原因(どのトークンの基準日時か)を
/// 1 行にまとめ、基準日時不明の側は別行に出さない。
///
/// それ以外は 001 が返した順序と件数のまま並べる。まとめる対象かどうかは
/// **ファイルの同一性**で判断する。1 回の [validate] が返す警告は同じ
/// [FileEntry] インスタンスを指すため、これで同じファイルの警告だけが揃う。
List<WarningPresentation> presentWarnings(List<Warning> warnings) {
  final causesByFile = <FileEntry, List<MissingSourceDateWarning>>{};
  for (final warning in warnings) {
    if (warning is MissingSourceDateWarning) {
      (causesByFile[warning.file] ??= <MissingSourceDateWarning>[]).add(
        warning,
      );
    }
  }
  // 空名と基準日時不明の両方が該当するファイルだけをまとめる。
  final merged = <FileEntry>{
    for (final warning in warnings)
      if (warning is EmptyNameWarning && causesByFile.containsKey(warning.file))
        warning.file,
  };

  final presented = <WarningPresentation>[];
  for (final warning in warnings) {
    if (warning is MissingSourceDateWarning && merged.contains(warning.file)) {
      continue; // 空名の行へまとめ済み。
    }
    if (warning is EmptyNameWarning && merged.contains(warning.file)) {
      presented.add(
        WarningPresentation(
          kindLabel: warningKindLabel(warning),
          message: _describeEmptyNameWithCause(
            warning.file,
            causesByFile[warning.file]!,
          ),
        ),
      );
      continue;
    }
    presented.add(
      WarningPresentation(
        kindLabel: warningKindLabel(warning),
        message: describeWarning(warning),
      ),
    );
  }
  return presented;
}

/// 空名の結果と、その原因になった日時トークンを 1 行にまとめた文言(REQ-021)。
String _describeEmptyNameWithCause(
  FileEntry file,
  List<MissingSourceDateWarning> causes,
) {
  final tokens = causes
      .map(
        (cause) =>
            '${cause.tokenIndex + 1} 番目のトークン(${describeToken(cause.token)})',
      )
      .join('、');
  return '空の名前: 「${file.name}」${_locationSuffix(file)}は$tokensの'
      '基準日時が取れないため、変更後の名前が空になります';
}

/// 件数と種別内訳の見出し(例: `警告 3 件(重複 2・桁不足 1)`)。
///
/// 数えるのは 001 が返した警告そのものではなく、[presentWarnings] がまとめた
/// **提示単位**なので、見出しの件数と展開した行数が必ず一致する。
///
/// 内訳を畳んでいる間も「何がいくつ起きているか」は常に見える。
String describeWarningSummary(List<WarningPresentation> presented) {
  final counts = <String, int>{};
  for (final item in presented) {
    counts[item.kindLabel] = (counts[item.kindLabel] ?? 0) + 1;
  }
  final breakdown = counts.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join('・');
  return '警告 ${presented.length} 件($breakdown)';
}

/// ルールが空のとき、警告帯の代わりに出す案内(005 REQ-020)。
///
/// 「何が起きているか(命名ルールが未設定)」と「どうすれば進めるか(ルールを
/// 設定する)」を伝えるだけの帯で、操作そのものは下部アクションバーのルール
/// 設定ボタンが担う。警告帯とは意味が違う(不具合ではなく未着手)ので、色は
/// [AppColors.danger] ではなく通常の情報色を使う。
class RuleNotConfiguredBanner extends StatelessWidget {
  const RuleNotConfiguredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: ruleNotConfiguredKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.primary.withValues(alpha: 0.10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '命名ルールが未設定です。ルールを設定すると変更後の名前を確認できます',
              style: TextStyle(
                color: colors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 警告の種別名(見出しの内訳と各行の頭に使う)。
String warningKindLabel(Warning warning) => switch (warning) {
  DuplicateWarning() => '重複',
  DigitShortageWarning() => '桁不足',
  EmptyNameWarning() => '空の名前',
  MissingSourceDateWarning() => '基準日時なし',
};

/// 警告 1 件を、対象ファイル(と該当トークン)が識別できる文言にする(REQ-009)。
///
/// [DigitShortageWarning] だけは 001 が特定のファイルではなく**ルール内の連番
/// トークン**に対して返す警告なので、対象はトークン位置で識別する(選択中の
/// 全ファイルに一様に効く)。
String describeWarning(Warning warning) => switch (warning) {
  DuplicateWarning(:final file, :final resultName) =>
    '重複: 「${file.name}」${_locationSuffix(file)}の変更後名「$resultName」が'
        '他のファイルと重複します',
  DigitShortageWarning(
    :final tokenIndex,
    :final token,
    :final requiredDigits,
  ) =>
    '桁不足: ${tokenIndex + 1} 番目のトークン(${describeToken(token)})は'
        '選択件数に対して桁が足りません($requiredDigits 桁必要)',
  EmptyNameWarning(:final file) =>
    '空の名前: 「${file.name}」${_locationSuffix(file)}の変更後の名前が空になります',
  MissingSourceDateWarning(:final file, :final tokenIndex, :final token) =>
    '基準日時なし: 「${file.name}」${_locationSuffix(file)}は'
        '${describeDateTimeSource(token.source)}が不明なため、'
        '${tokenIndex + 1} 番目のトークン(${describeToken(token)})が空になります',
};

/// 同名・別フォルダを見分けるための場所の補足(004 が供給する行だけ)。
String _locationSuffix(FileEntry file) {
  final location = file.sourceLocation;
  return location == null ? '' : '($location)';
}

/// ルール内のトークンを、利用者がルール上で見つけられる短い名前にする。
String describeToken(Token token) => switch (token) {
  OriginalNameToken() => '元の名前',
  LiteralToken(:final value) => '固定文字「$value」',
  SequenceToken(:final digits) => '連番 $digits 桁',
  DateTimeToken(:final source, :final format) =>
    '${describeDateTimeSource(source)}「$format」',
};

/// 日時トークンの基準の呼び名。
String describeDateTimeSource(DateTimeSource source) => switch (source) {
  DateTimeSource.created => '作成日時',
  DateTimeSource.modified => '更新日時',
  DateTimeSource.current => '現在日時',
};

// ---------------------------------------------------------------------------
// 008:T16 警告の提示。**005 revision 8.0 が課すのは場所ではなく「利用者から何が
// 読めるか」である**(配置は「自由とする点」)。ここで選んだ置き場所は
// `T15` の設計指針と参考designに沿ったもので、要求ではない。
// ---------------------------------------------------------------------------

/// 行に出す警告(005 REQ-009 (1) / REQ-021)。
///
/// - **ルールが空なら空を返す**(005 REQ-020: 警告ではなく未設定を提示する)。
/// - **空名の行は空名だけ**にする。基準日時不明は結果へ畳み(REQ-021 規則1)、
///   重複は出さない(規則2)。どちらも [showWarningDetail] には残る。
/// - 同じ種別が複数あっても行では 1 つにする。行は**トークンを名指ししない**ので、
///   同じ文言を並べても情報が増えない(名指しは [ruleWarningExplanations] と詳細)。
List<Warning> rowWarningsOf(
  List<Warning> warnings, {
  required bool ruleIsEmpty,
}) {
  if (ruleIsEmpty) return const <Warning>[];
  final empty = warnings.whereType<EmptyNameWarning>().firstOrNull;
  if (empty != null) return <Warning>[empty];
  final seen = <Type>{};
  return <Warning>[
    for (final warning in warnings)
      if (seen.add(warning.runtimeType)) warning,
  ];
}

/// 行に出す短い一文(005 REQ-009 (1))。**種別が読み取れることが要求である。**
///
/// 空名は結果を 2 つ示す — **(i) 名前が空になること** と
/// **(ii) そのファイルが改名の対象にならないこと**(005 REQ-021 規則1)。
/// (ii) は (i) の言い換えではない。(i) だけでは「空の名前へ改名される」とも読める。
///
/// **トークンを名指ししない。** 名指しは [ruleWarningExplanations] と詳細が担う。
String rowWarningLabel(Warning warning) => switch (warning) {
  DuplicateWarning() => '名前が重複',
  EmptyNameWarning() => '名前が空・改名されません',
  // 基準日時が取れないのは**作成日時が不明なとき**だけである(001 INV-006:
  // 更新日時・現在日時では代替しない。それらは常に値を持つ)。
  MissingSourceDateWarning() => '作成日時が空になります',
  // 行へは来ない([warningTargetOf] が `null` を返す)。網羅のために置く。
  DigitShortageWarning() => '連番の桁が不足',
};

/// ルールを直せば消える原因の説明(005 REQ-009 (2))。
///
/// **該当ファイルの件数ぶん繰り返さない。単位は原因(トークン)ごとである。**
/// 取れない日時トークンが 2 本あれば説明は 2 つでよい。
///
/// ルールが空なら空を返す(005 REQ-020)。
List<String> ruleWarningExplanations(
  List<Warning> warnings, {
  required bool ruleIsEmpty,
}) {
  if (ruleIsEmpty) return const <String>[];
  final seenDigits = <int>{};
  final seenDate = <int>{};
  final out = <String>[];
  for (final warning in warnings) {
    switch (warning) {
      case DigitShortageWarning(
        :final tokenIndex,
        :final token,
        :final requiredDigits,
      ):
        if (!seenDigits.add(tokenIndex)) continue;
        out.add(
          '${tokenIndex + 1} 番目のトークン(${describeToken(token)})は'
          '$requiredDigits 桁必要です',
        );
      case MissingSourceDateWarning(:final tokenIndex, :final token):
        if (!seenDate.add(tokenIndex)) continue;
        out.add(
          '${tokenIndex + 1} 番目のトークン(${describeToken(token)})は'
          '${describeDateTimeSource(token.source)}が取れないため空になります',
        );
      case DuplicateWarning():
      case EmptyNameWarning():
        continue;
    }
  }
  return out;
}

/// 一覧全体の件数(005 REQ-010: 0 件なら「問題なし」。**それは警告ではない**)。
String warningCountLabel(List<Warning> warnings) {
  final count = presentWarnings(warnings).length;
  return count == 0 ? '問題なし' : '$count 件の問題';
}

/// 行の警告(005 REQ-009 (1))。**展開操作を経ずに種別が読める。**
class RowWarningView extends StatelessWidget {
  const RowWarningView({super.key, required this.warnings, this.onTap});

  /// [rowWarningsOf] を通した後の警告。空なら何も描かない。
  final List<Warning> warnings;

  /// 押したときに全件の詳細を開く(005 REQ-009 (3))。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return InkWell(
      key: rowWarningKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 3),
              child: Icon(Icons.error_outline, size: 11, color: colors.danger),
            ),
            Flexible(
              child: Text(
                warnings.map(rowWarningLabel).join('・'),
                // 種別がすべて併発しても 2 行に収まる短さにしてある。
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一覧全体の件数表示(005 REQ-009 (3) の入口の 1 つ)。
class WarningCountView extends StatelessWidget {
  const WarningCountView({super.key, required this.warnings, this.onTap});

  final List<Warning> warnings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final has = warnings.isNotEmpty;
    return InkWell(
      key: warningCountKey,
      // 0 件のときは開くものが無い。
      onTap: has ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              has ? Icons.error_outline : Icons.check_circle_outline,
              size: 13,
              color: has ? colors.danger : colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                warningCountLabel(warnings),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: has ? colors.danger : colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ルールを直せば消える原因の説明(005 REQ-009 (2))。
///
/// **ルールを変更する導線のそばへ置く**のが`T15`の設計指針だが、**場所は要求では
/// ない**(005 revision 8.0)。狭幅では下部バー、広幅では右ペインが導線なので、
/// 呼び出し側がそれぞれ描く。
class RuleWarningNotice extends StatelessWidget {
  const RuleWarningNotice({
    super.key,
    required this.warnings,
    required this.ruleIsEmpty,
  });

  final List<Warning> warnings;
  final bool ruleIsEmpty;

  @override
  Widget build(BuildContext context) {
    final explanations = ruleWarningExplanations(
      warnings,
      ruleIsEmpty: ruleIsEmpty,
    );
    if (explanations.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      key: ruleWarningNoticeKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 6),
            child: Icon(Icons.error_outline, size: 13, color: colors.danger),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final text in explanations)
                  Text(
                    text,
                    style: TextStyle(color: colors.danger, fontSize: 11.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全件と説明の詳細(005 REQ-009 (3))。
///
/// **行の警告からも一覧全体の件数表示からも同じものが開く。** 種別ごとにまとめて
/// 並べ、[presentWarnings] の提示単位をそのまま使う(実行前確認dialogと同じ単位。
/// REQ-021 のまとめを両方へ効かせる)。
Future<void> showWarningDetail(
  BuildContext context,
  List<Warning> warnings,
) async {
  if (warnings.isEmpty) return;
  final presented = presentWarnings(warnings);
  final byKind = <String, List<WarningPresentation>>{};
  for (final item in presented) {
    (byKind[item.kindLabel] ??= <WarningPresentation>[]).add(item);
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        key: warningDetailDialogKey,
        title: Text(warningCountLabel(warnings)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in byKind.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      '${entry.key} ${entry.value.length} 件',
                      style: TextStyle(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final item in entry.value) Text('• ${item.message}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('warning-detail-close'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      );
    },
  );
}
