import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';

/// 警告帯そのもの(0 件のときは存在しない)。
const Key renameWarningsKey = Key('rename-warnings');

/// 件数と内訳の見出し(帯があるときは常に見える)。
const Key renameWarningSummaryKey = Key('rename-warning-summary');

/// 内訳の開閉トグル(見出し全体がタップ領域)。
const Key renameWarningToggleKey = Key('rename-warning-toggle');

/// [index] 番目(0 始まり)の警告行(展開時のみ存在する)。
Key renameWarningRowKey(int index) => Key('rename-warning-$index');

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

  /// 展開した内訳の最大高さ。これを超える件数はスクロールで送る。
  static const double detailMaxHeight = 132;

  @override
  State<RenameWarningPanel> createState() => _RenameWarningPanelState();
}

class _RenameWarningPanelState extends State<RenameWarningPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // REQ-010: 0 件のときは提示しない(空の帯も見出しも出さない)。
    if (widget.warnings.isEmpty) return const SizedBox.shrink();
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
                    describeWarningSummary(widget.warnings),
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
              constraints: const BoxConstraints(
                maxHeight: RenameWarningPanel.detailMaxHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.warnings.length; i++)
                      _WarningRow(
                        key: renameWarningRowKey(i),
                        message: describeWarning(widget.warnings[i]),
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

/// 件数と種別内訳の見出し(例: `警告 3 件(重複 2・桁不足 1)`)。
///
/// 内訳を畳んでいる間も「何がいくつ起きているか」は常に見える。
String describeWarningSummary(List<Warning> warnings) {
  final counts = <String, int>{};
  for (final warning in warnings) {
    final label = warningKindLabel(warning);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final breakdown = counts.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join('・');
  return '警告 ${warnings.length} 件($breakdown)';
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
