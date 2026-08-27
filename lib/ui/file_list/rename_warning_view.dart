import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';

/// 警告帯そのもの(0 件のときは存在しない)。
const Key renameWarningsKey = Key('rename-warnings');

/// 件数と内訳の見出し(帯があるときは常に見える)。
const Key renameWarningSummaryKey = Key('rename-warning-summary');

/// 内訳の開閉トグル(見出し全体がタップ領域)。
const Key renameWarningToggleKey = Key('rename-warning-toggle');

/// 展開した内訳のスクロール領域(展開時のみ存在する)。高さの上限がここに効く。
const Key renameWarningDetailKey = Key('rename-warning-detail');

/// [index] 番目(0 始まり)の警告行(展開時のみ存在する)。
Key renameWarningRowKey(int index) => Key('rename-warning-$index');

/// ルール未設定の案内帯(警告帯の代わりに出る)。
const Key ruleNotConfiguredKey = Key('rule-not-configured');

/// 001 の検証([validate])が返した警告をプレビュー上に提示する帯(005 REQ-009)。
///
/// **判定は 001 が持ち、005 は表示だけを担う**(契約 `terms` の「警告」)。
/// 4 種([DuplicateWarning] / [DigitShortageWarning] / [EmptyNameWarning] /
/// [MissingSourceDateWarning])すべてを、どのファイルが対象か識別できる文言で
/// 1 件 1 行に並べる。基準日時不明ではルール内のどのトークンが空になるかも示す。
///
/// [warnings] が空なら**何も表示しない**(005 REQ-010)。
///
/// 帯は「件数と種別内訳の見出し」+「1 件 1 行の内訳」からなり、内訳は見出しの
/// タップで開閉する(既定は閉じ)。ファイル一覧の縦を警告で潰さないための構成で、
/// 提示方法は仕様が実装に委ねている範囲(spec.md「自由とする点」)。開いた内訳は
/// 帯の中でスクロールするので、件数が多くても全件たどれる。
///
/// 見た目は 004 T6 の作成日時フォールバック警告帯に揃え、色は [AppColors] の
/// セマンティック色([AppColors.danger])から取る(生の色値を書かない)。
class RenameWarningPanel extends StatefulWidget {
  const RenameWarningPanel({super.key, required this.warnings});

  /// 001 の [validate] が返した警告(表示順はそのまま保つ)。
  final List<Warning> warnings;

  /// 展開した内訳の最大高さの**上限**。実際は画面の高さに応じて決まる
  /// ([detailMaxHeightFor])。
  static const double detailMaxHeight = 132;

  /// 画面の高さから内訳の最大高さを決める(008:T07)。
  ///
  /// **固定 132px をやめた。** 狭幅では1件の文言が4行へ折り返すため、132px には
  /// 2件しか入らない。folder を跨ぐ重複は通常経路で出る(008 の (i))ので、
  /// 件数が多いのは例外ではない。
  ///
  /// **画面を警告で埋めない**という元の意図は保つ。上限は画面の高さの
  /// [_detailHeightRatio] までで、そこから先はこれまでどおりスクロールで送る。
  static double detailMaxHeightFor(double screenHeight) {
    final proportional = screenHeight * _detailHeightRatio;
    return proportional < detailMaxHeight ? detailMaxHeight : proportional;
  }

  /// 内訳へ渡してよい画面の割合。残りは一覧のために空けておく。
  static const double _detailHeightRatio = 0.32;

  @override
  State<RenameWarningPanel> createState() => _RenameWarningPanelState();
}

class _RenameWarningPanelState extends State<RenameWarningPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // REQ-021: 同一ファイルの空名 + 基準日時不明は 1 行にまとめてから数える。
    final presented = presentWarnings(widget.warnings);
    // REQ-010: 0 件のときは提示しない(空の帯も見出しも出さない)。
    if (presented.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      key: renameWarningsKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.danger.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: renameWarningToggleKey,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                // 004 T6 の作成日時フォールバック帯(warning_amber)とは別の印を
                // 使い、どちらの警告かをアイコンでも区別できるようにする。
                Icon(Icons.error_outline, size: 14, color: colors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key: renameWarningSummaryKey,
                    describeWarningSummary(presented),
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: colors.danger,
                ),
              ],
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              key: renameWarningDetailKey,
              constraints: BoxConstraints(
                maxHeight: RenameWarningPanel.detailMaxHeightFor(
                  MediaQuery.sizeOf(context).height,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < presented.length; i++)
                      _WarningRow(
                        key: renameWarningRowKey(i),
                        message: presented[i].message,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 警告 1 件の行(印 + 説明文)。
class _WarningRow extends StatelessWidget {
  const _WarningRow({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, size: 13, color: colors.danger),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.danger, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

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
