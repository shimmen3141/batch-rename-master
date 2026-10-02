import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../common/design_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// ルール未設定の案内帯(警告が 0 件でない状態の代わりに出る)。
const Key ruleNotConfiguredKey = Key('rule-not-configured');

/// 一覧全体の警告件数(常に見える。押すと全件の詳細が開く。005 REQ-009 (3))。
const Key warningCountKey = Key('warning-count');

/// 行の警告(005 REQ-009 (1))。押すと**その行の**詳細が開く(REQ-009 (4))。
const Key rowWarningKey = Key('row-warning');

/// 行の警告の文言(右端に書く種類。`008:T50`)。
const Key rowWarningBadgeTextKey = Key('row-warning-badge-text');

/// 設定中のルールの1行要約(参考designのルール設定button 2行目)。
const Key ruleSummaryKey = Key('rule-summary');

/// ルール設定button内の `編集` の飾り。**押下対象ではない**(押せるのは button
/// 全体だけ。2026-09-02 の要望9)。
const Key ruleEditChipKey = Key('rule-edit-chip');

/// 実行buttonのlabel(005 REQ-019 / REQ-020。2026-09-02 の要望14)。
const Key executeLabelKey = Key('rename-action-label');

/// ルール設定buttonの角の丸み・塗り・枠・アイコンの箱(参考design)。
///
/// **固定しているのは「button 全体が一つの押下対象であること」と「枠と塗りが
/// 在ること」である**(widget test が正本)。値そのものは自由で、余白・字体・色の
/// 詰めは `008:T10` が持つ。
const double ruleButtonRadius = 14;
const double ruleButtonFillOpacity = 0.10;
const double ruleButtonBorderOpacity = 0.42;
const double ruleButtonIconBoxSize = 32;
const double ruleEditChipFillOpacity = 0.16;

/// ルール設定buttonの上下の内側の余白と、「命名ルール」とチップの間(`008:T47`)。
/// 2026-09-30 の開発者の指定で、上下を 11 → 8 → 6 に詰め、間を 4 → 7 → 9 に広げた
/// (実機確認1回目・2回目)。
const double ruleButtonVerticalPadding = 6;
const double ruleButtonHeadingGap = 9;

/// 未設定のルール設定buttonの中身の最小の高さ(文字の拡大に合わせて伸ばす。`008:T47`)。
/// 2026-10-01 の開発者の指定(実機確認5回目)で、設定済みよりひとまわり小さいくらいまで
/// 縦に大きくした。文字 1.0 で button は 34 → 64(設定済みは 78)。
const double ruleButtonEmptyMinContentHeight = 50;

/// 詳細dialog内の節の並び(原因ごとに1節。005 REQ-009 (2) / (3))。
///
/// `008:T19` で「原因の説明」節と「全件」節に分けていた形から組み直した
/// (2026-09-02 の要望3・4: 同じ原因が2つの節へ重複して出ていた)。
const Key warningDetailSectionsKey = Key('warning-detail-sections');

/// 節1つ(見出し・説明・対象の列挙)。
Key warningDetailSectionKey(int index) => Key('warning-detail-section-$index');

/// 節の説明(**節ごとに1つだけ**。005 REQ-009 (2))。
Key warningDetailExplanationKey(int index) =>
    Key('warning-detail-explanation-$index');

/// 節の対象の列挙(005 REQ-009 (3) / (4))。
Key warningDetailTargetsKey(int index) => Key('warning-detail-targets-$index');

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
List<WarningPresentation> presentWarnings(
  List<Warning> warnings, {
  Iterable<FileEntry> amongFiles = const <FileEntry>[],
}) {
  // 場所の括弧は同名が並ぶときだけ添える([fileLabel] / [ambiguousFileNames])。
  final ambiguous = _ambiguousAmong(warnings, amongFiles);
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
            ambiguous: ambiguous,
          ),
        ),
      );
      continue;
    }
    presented.add(
      WarningPresentation(
        kindLabel: warningKindLabel(warning),
        message: describeWarning(warning, ambiguous: ambiguous),
      ),
    );
  }
  return presented;
}

/// 空名の結果と、その原因になった日時トークンを 1 行にまとめた文言(REQ-021)。
String _describeEmptyNameWithCause(
  FileEntry file,
  List<MissingSourceDateWarning> causes, {
  Set<String> ambiguous = const <String>{},
}) {
  final tokens = causes
      .map(
        (cause) =>
            '${cause.tokenIndex + 1} 番目のトークン(${describeToken(cause.token)})',
      )
      .join('、');
  final label = fileLabel(file, withLocation: ambiguous.contains(file.name));
  return '名前が空: $labelは$tokensの基準日時が取れないため、'
      '変更後の名前が空になります';
}

/// ルールが空のとき、警告の代わりに出す案内(005 REQ-020)。
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
      // 一覧の上のメッセージのバナーの1行として出る(`008:T02`)。行の余白を揃える。
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                fontSize: AppFontSize.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 警告の種別名。**行・詳細modal・実行前確認dialogで同じ語彙を使う**
/// (`008:T19` が文言の正本。2026-09-02 の要望5)。
///
/// 改修前は詳細側だけ `基準日時なし` / `桁不足` で、行は `作成日時不明` /
/// `連番の桁不足` だった。**利用者から見て同じものが2つの語彙で呼ばれていた。**
String warningKindLabel(Warning warning) => switch (warning) {
  DuplicateWarning() => duplicateKindLabel,
  DigitShortageWarning() => digitShortageKindLabel,
  EmptyNameWarning() => '名前が空',
  // **どの基準が取れないかを明示する**(要望5)。基準から導くので、作成日時
  // トークンで「更新日時不明」と出ることはない。
  MissingSourceDateWarning(:final token) => missingSourceDateKindLabel(
    token.source,
  ),
};

/// 名前が重複する種別の呼び名(行・詳細・確認dialog共通)。
///
/// **短くした**(`008:T50`。以前は `名前の重複`)。行の右端は現在名と同じ行に載るので、
/// 語を短くするほど現在名が残る。同じ語彙を使う決まり(`008:T19`)に従い、詳細と
/// 確認dialogも同じ語にそろえた。
const String duplicateKindLabel = '重複';

/// 連番の桁が足りない種別の呼び名(行・詳細・確認dialog共通)。`008:T50` で
/// `連番の桁不足` から短くした(理由は [duplicateKindLabel])。
const String digitShortageKindLabel = '桁不足';

/// 日時トークンの基準が取れない種別の呼び名(基準ごとに変わる)。
String missingSourceDateKindLabel(DateTimeSource source) =>
    '${describeDateTimeSource(source)}不明';

/// 警告 1 件を、対象ファイル(と該当トークン)が識別できる文言にする(REQ-009)。
///
/// [DigitShortageWarning] だけは 001 が特定のファイルではなく**ルール内の連番
/// トークン**に対して返す警告なので、対象はトークン位置で識別する(選択中の
/// 全ファイルに一様に効く)。
String describeWarning(
  Warning warning, {
  Set<String> ambiguous = const <String>{},
}) {
  String label(FileEntry file) =>
      fileLabel(file, withLocation: ambiguous.contains(file.name));
  return switch (warning) {
    DuplicateWarning(:final file, :final resultName) =>
      '${warningKindLabel(warning)}: ${label(file)}の変更後名「$resultName」が'
          '他のファイルと重複します',
    DigitShortageWarning(
      :final tokenIndex,
      :final token,
      :final requiredDigits,
    ) =>
      '${warningKindLabel(warning)}: ${tokenIndex + 1} 番目のトークン'
          '(${describeToken(token)})は選択件数に対して桁が足りません'
          '($requiredDigits 桁必要)',
    EmptyNameWarning(:final file) =>
      '${warningKindLabel(warning)}: ${label(file)}の変更後の名前が空になります',
    MissingSourceDateWarning(:final file, :final tokenIndex, :final token) =>
      '${warningKindLabel(warning)}: ${label(file)}は'
          '${tokenIndex + 1} 番目のトークン(${describeToken(token)})が'
          '空になります',
  };
}

/// 対象ファイルを識別する字面(005 REQ-009)。
///
/// **場所の括弧は既定で出さない**(2026-09-02 の要望4。原文は「モーダル内で
/// ファイルの場所を括弧内に示す必要はない」)。**ただし同じ表示名が2件以上
/// 並ぶときだけ添える** — REQ-009 は「どのファイルが対象かを識別できる形」を
/// 課しており、同名が並ぶと名前だけでは識別できない(004 は複数folderの混在を
/// 通常経路で起こす)。
String fileLabel(FileEntry file, {required bool withLocation}) {
  final location = file.sourceLocation;
  if (!withLocation || location == null) return '「${file.name}」';
  return '「${file.name}」($location)';
}

/// [files] のうち、**同じ表示名のファイルが2件以上ある名前**(場所を添えないと
/// 識別できない)。
///
/// **数えるのは相異なるファイルである。** 警告のリストをそのまま渡すと、同じ
/// ファイルがその警告の件数ぶん現れるので、**1ファイルに警告が2件あるだけで
/// 「同名が並ぶ」と誤判定する**(独立review attempt 1 の P1-1)。ここで identity で
/// 畳んでから名前を数える。
///
/// **母集合は利用者が見分ける必要のあるファイル集合**(一覧に並んでいるもの)を
/// 渡すこと。警告を持つファイルだけを渡すと、**同名2件のうち片方だけが警告された
/// とき**に場所が付かず、どちらか分からなくなる(同 P1-2)。
Set<String> ambiguousFileNames(Iterable<FileEntry> files) {
  final distinct = Set<FileEntry>.identity()..addAll(files);
  final seen = <String>{};
  final duplicated = <String>{};
  for (final file in distinct) {
    if (!seen.add(file.name)) duplicated.add(file.name);
  }
  return duplicated;
}

/// 場所を添える必要がある名前([amongFiles] が空なら警告を持つファイルだけで数える)。
///
/// 呼び出し側が一覧のファイルを渡せる場合は必ず渡す。渡さない経路は、同名2件の
/// うち片方だけが警告されたときに場所を添えられない(独立review attempt 1 の P1-2)。
Set<String> _ambiguousAmong(
  List<Warning> warnings,
  Iterable<FileEntry> amongFiles,
) => ambiguousFileNames(
  amongFiles.isEmpty ? warnings.map(warningFile).nonNulls : amongFiles,
);

/// 警告が対象とするファイル([DigitShortageWarning] は 001 のうえでは持たない)。
FileEntry? warningFile(Warning warning) => switch (warning) {
  DuplicateWarning(:final file) => file,
  EmptyNameWarning(:final file) => file,
  MissingSourceDateWarning(:final file) => file,
  DigitShortageWarning() => null,
};

/// ルール内のトークンを、利用者がルール上で見つけられる短い名前にする。
String describeToken(Token token) => switch (token) {
  OriginalNameToken() => '元の名前',
  LiteralToken(:final value) => '固定文字「$value」',
  SequenceToken(:final digits, :final zeroPad) =>
    zeroPad ? '連番 $digits 桁' : '連番 ゼロ埋めなし',
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

/// 行の警告の押した跡の角の丸みと、文字の濃さ。
///
/// 値そのものは自由で、**固定しているのは「文字が変更後名より薄い」ことと、
/// 押せることを太字・下線で示すこと**である(widget test が正本)。`008:T50` で
/// 枠と塗りの箱をやめた(以前は塗り 0.12・枠 0.45)。
const double rowWarningRadius = 6;
const double rowWarningLabelOpacity = 0.78;

/// 行の警告の文字とアイコンの大きさ。
const double rowWarningFontSize = AppFontSize.small;

/// アイコンを baseline からさらに下げる量([rowWarningFontSize] に対する割合)。
///
/// **Material icons と CJK の字面(ink)の中心の差**である。icons は baseline の上
/// 1em を占めるので ink の中心が **baseline − 0.5em**、CJK は上 0.88em 〜 下 0.12em で
/// **baseline − 0.38em**。差は **0.12em** で、揃えないとアイコンが上へ浮いて見える
/// (2026-09-04 のmanual確認)。
///
/// **押さえているのは既定の文字倍率だけである。** 比例先の [rowWarningFontSize] は
/// コンパイル時定数で、利用者の文字倍率(`textScaler`)に追随しない。[Icon] も
/// `applyTextScaling` が既定 false で拡大しないのに対し、[Text] の `fontSize` は
/// 倍率で拡大するので、**倍率を上げるほど字面の中心の差が開く**(実測 gap =
/// 1.18 / 2.37 / 4.30 / 6.91px @ 倍率 1.0 / 1.3 / 2.0 / 3.0)。
/// **受容した残余riskであり、引き受け先は `008:T10`**(余白・字体・階層)。
const double rowWarningIconInkNudge = 0.12;

/// 行に出す警告(005 REQ-009 (1) / REQ-021)。
///
/// - **ルールが空なら空を返す**(005 REQ-020: 警告ではなく未設定を提示する)。
/// - **空名の行は空名だけ**にする。基準日時不明は結果へ畳み(REQ-021 規則1)、
///   重複は出さない(規則2)。どちらも [showWarningDetail] には残る。
/// - 同じ種別が複数あっても行では 1 つにする。行は**トークンを名指ししない**ので、
///   同じ文言を並べても情報が増えない(名指しは詳細modalの節が担う)。
List<Warning> rowWarningsOf(
  List<Warning> warnings, {
  required bool ruleIsEmpty,
}) {
  if (ruleIsEmpty) return const <Warning>[];
  final empty = warnings.whereType<EmptyNameWarning>().firstOrNull;
  // 空名の行は結果だけにする(REQ-021 規則1。REQ-009 (1) も「規則が畳んだ種別を
  // ここで別立てにしない」と書いている)。**桁不足と空名は同時に起きない** —
  // 空名は全トークンが空文字を出すときだけで、連番は常に1文字以上を出す。
  if (empty != null) return <Warning>[empty];
  final seen = <Type>{};
  return <Warning>[
    for (final warning in warnings)
      if (seen.add(warning.runtimeType)) warning,
  ];
}

/// 行の右端に書く種類(`008:T50`。2026-10-01 の開発者の決定)。
///
/// **その行のほかの場所から読めない種類だけを書く。**
///
/// - 作成日時不明は書かない — 補足情報の `作成日時: 不明` を赤で強調して読ませる
///   (005 REQ-009 (1) の「種別が一覧の状態で分かる」はそこで満たす)。
/// - 名前が空は書く — 結果(この名前にならず、改名されない)は補足情報からは
///   読めない。変更後名の `（変更なし）` と合わせて、005 代表例20 の (i)(ii) を読ませる。
/// - **書く種類が無いとき(作成日時不明だけの行)は `詳細` と書く。** 押す場所を
///   どの行でも同じ位置に保ち、その行の詳細を開く入口を消さないためである。
String rowWarningBadgeLabel(List<Warning> warnings) {
  final kinds = [
    for (final w in warnings)
      if (w is! MissingSourceDateWarning) rowWarningLabel(w),
  ];
  return kinds.isEmpty ? rowWarningDetailLabel : kinds.join('・');
}

/// 右端に書く種類が無い行の文言(`008:T50`)。
const String rowWarningDetailLabel = '詳細';

/// 行の右端に書く種類の呼び名。作成日時不明は [rowWarningBadgeLabel] が外す。
String rowWarningLabel(Warning warning) => switch (warning) {
  DuplicateWarning() => duplicateKindLabel,
  EmptyNameWarning() => '名前が空',
  MissingSourceDateWarning(:final token) => missingSourceDateKindLabel(
    token.source,
  ),
  // 002 REQ-015 の導出で**行へ来る**(008:T17 の改訂)。`T52` の自動の引き上げの
  // 後はほぼ起きないが、判定は安全網として残る。
  DigitShortageWarning() => digitShortageKindLabel,
};

/// 設定中のルールの1行要約(参考designのルール設定button 2行目)。
///
/// **トークンを並べた形にする**(2026-09-02 の要望9。原文は「参考designだと
/// `[元の名前][01][YYYYMMDD]`のようなトークン的な表示だが、現状は『連番1桁+作成日時』
/// のような説明的な表示になってしまっている」)。**説明は [describeToken] が持ち、
/// ここは使わない。**
///
/// ルールが空なら空文字を返す(空のときは button の中身が入れ替わるので使われない)。
///
/// `008:T47` から button はチップ(`RuleChipStrip`)で並べ、この字面は**読み上げ**に使う。
String describeRuleSummary(RenameRule rule) =>
    rule.tokens.map(describeTokenChip).join();

/// ルール要約に並べる、トークン1つぶんの字面(参考designの `summary()`)。
///
/// 固定文字だけは**角括弧を付けない** — 実際に出力される文字がそのまま並ぶ形が
/// designの意図である(`[元の名前]-01` のように読める)。空の固定文字は、付けても
/// 何も出ないことが読めるように `""` と書く。
String describeTokenChip(Token token) => switch (token) {
  OriginalNameToken() => '[元の名前]',
  LiteralToken(:final value) => value.isEmpty ? '""' : value,
  SequenceToken(:final start, :final digits, :final zeroPad) =>
    '[${zeroPad ? start.toString().padLeft(digits, '0') : '$start'}…]',
  // **基準を落とさない。** designの日時トークンは1種類だが、003 は作成/更新/現在の
  // 3つを持つ。書式だけにすると `[YYYYMMDD]` がどの基準か読めなくなる。
  DateTimeToken(:final source, :final format) =>
    '[${describeDateTimeSource(source)} $format]',
};

/// 実行buttonのlabel(2026-09-02 の要望14)。
///
/// **参考designは3状態だが、ここは4状態である。** designは
/// `!sel.length ? '対象を選択してください' : changeCount ? changeCount + ' 件をリネーム'
/// : 'ルールを設定してください'` で、**「ルールが空」と「ルールはあるが変更が生じる
/// ファイルが0件」を同じ文言へ畳んでいる。**
///
/// **それは 005 と両立しない。** 例22a は「ルールが `[元の名前]` 1つだけ」のとき
/// 「**命名ルールが未設定である旨は出さない — ルールは設定されている**」と定め、
/// REQ-020 の案内はルールが空のときだけである。designの文言をそのまま使うと、
/// ルールを設定している利用者へ「ルールを設定してください」と出すことになる。
/// そこで**0件の理由で文言を分けた** — REQ-019 が定める分岐
/// (「(a) ルールが空であるかどうかの1つだけ」)に一致する。
///
/// [changedCount] は 005 用語「変更が生じるファイル」の件数である。
/// **ルールの形では数えない**(例22b)。
String executeLabel({
  required int selectedCount,
  required int changedCount,
  required bool ruleIsEmpty,
}) {
  if (selectedCount == 0) return '対象を選択してください';
  if (changedCount > 0) return '$changedCount 件をリネーム';
  if (ruleIsEmpty) return 'ルールを設定してください';
  return '変更されるファイルがありません';
}

/// 一覧全体の件数。0 件なら、実行できる状態だけ準備完了を示す(008:T33)。
String warningCountLabel(List<Warning> warnings) {
  final count = presentWarnings(warnings).length;
  return count == 0 ? '正常にリネームできます' : '$count 件の問題';
}

/// 行の警告(005 REQ-009 (1))。**展開操作を経ずに種別が読める。**
class RowWarningView extends StatelessWidget {
  const RowWarningView({super.key, required this.warnings, this.onTap});

  /// [rowWarningsOf] を通した後の警告。空なら何も描かない。
  final List<Warning> warnings;

  /// 押したときに**その行の**詳細を開く(005 REQ-009 (4))。全件はヘッダの件数から。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    // **押せると分かる形にする**(2026-09-03 のmanual確認。原文は「ぱっと見だと
    // 押せることが分からず、ただの警告文に見える。角を丸めた赤の四角で囲み、
    // 中をさらに薄い赤で塗りつぶしてボタンぽっくしても良いかも」)。
    //
    // **色は変更後名より薄くする**(同「変更後名の表示の赤と同じ濃さなので、目が
    // 散る。少しだけ薄くしても良いかも」)。行の主役は変更後名で、警告はその
    // 補足である。**種別が読めることは変わらない** — 薄くするのは濃さだけで、
    // 背景との対比は保つ。
    final label = colors.danger.withValues(alpha: rowWarningLabelOpacity);
    // **アイコンも文字の倍率に合わせて拡大する**(`008:T10`)。[Text] の `fontSize` は
    // 利用者の文字倍率で拡大するが、[Icon] は既定で拡大しない。揃えないと、倍率を
    // 上げるほどアイコンが小さく、字面の中心も上へずれていった(`008:T18` から
    // 引き受けた残余risk。実測 gap = 1.18 / 2.37 / 4.30 / 6.91px @ 1.0 / 1.3 / 2.0 / 3.0)。
    final iconSize = MediaQuery.textScalerOf(context).scale(rowWarningFontSize);
    // **枠と塗りの箱をやめ、太字・下線の文字にした**(`008:T50`。2026-10-01 の開発者の
    // 決定)。以前は現在名の上の専用の行に、角を丸めた赤の箱で置いていた(2026-09-03 の
    // 要望「押せることが分からない」)。**押せることは下線で示す。** 右端は現在名と
    // 同じ行に載るので、箱の枠と内側の余白のぶん現在名が早く切れるのを避けた。
    return InkWell(
      key: rowWarningKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(rowWarningRadius),
      child: Padding(
        // **tap範囲を文字より広く取る。** 11px の文字だけを当たり判定にすると指で外す
        // (`008:T18` / `T19`。当たり判定と中身の差は上下 8 / 左右 12)。
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          // **アイコンを文字の baseline へ揃え、字面の差を [rowWarningIconInkNudge] で
          // 補正する**(2026-09-03・09-04 の manual 確認、`008:T10`)。
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 3),
              // `CrossAxisAlignment.baseline` は子の baseline を固定するので、padding では
              // 下がらない。paint 側でずらす。
              child: Transform.translate(
                offset: Offset(0, iconSize * rowWarningIconInkNudge),
                child: Icon(Icons.error_outline, size: iconSize, color: label),
              ),
            ),
            // **1行で、削らない。** 書く種類は短く(最長でも `重複・桁不足`)、残りの幅は
            // 現在名が省略して譲る。
            //
            // **下線は文字の装飾ではなく、文字の枠の下に引いた線**にする(2026-10-01 の
            // 実機確認1回目。原文は「各行の警告の下線が見えづらいです。ヘッダー付近の
            // 警告文の『詳細』の下線の引き方を参考にしてください」)。文字の装飾の下線は
            // 字形に接して細い。件数表示の「詳細」([warningDetailLinkKey])と同じ引き方・
            // 同じ太さ([warningLinkUnderlineWidth])にそろえる。
            Container(
              key: rowWarningUnderlineKey,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: label,
                    width: warningLinkUnderlineWidth,
                  ),
                ),
              ),
              child: Text(
                rowWarningBadgeLabel(warnings),
                key: rowWarningBadgeTextKey,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: label,
                  fontSize: rowWarningFontSize,
                  fontWeight: FontWeight.w700,
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
      // **横の余白を足さない**。同じバナーの作成日時の代替の行と、印の位置・印と文の
      // 間を揃える(2026-09-30 の開発者の指定。[bannerIconSize] / [bannerIconGap])。
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // **警告マークに揃える**(2026-09-30 の開発者の指定)。同じバナーの
              // 作成日時の代替と同じ形にする。
              has ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: bannerIconSize,
              color: has ? colors.danger : colors.success,
            ),
            const SizedBox(width: bannerIconGap),
            // **「詳細」は入らなければ次の行へ回す**(`Wrap`)。同じ行へ詰めると、
            // 狭幅・文字の拡大で件数の文言が切れた(幅 320・文字 2.0・1000 件。
            // 008:T16 の N-9 — 件数が読めなくなる)。
            Flexible(
              child: Wrap(
                spacing: 14,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    // **何についての状態かを先頭で示す**(2026-09-30 の開発者の指定)。
                    // バナーには並び順の状態(「並び順: …」)も並ぶ。詳細を開いたときの
                    // 見出しは件数だけのまま([warningCountLabel])。
                    has
                        ? 'リネーム: ${warningCountLabel(warnings)}'
                        : warningCountLabel(warnings),
                    // **切らずに次の行へ落とす**(008:T16 の (i) と同じ理由)。
                    // 切り詰めは overflow を出さないまま `⚠ 1000 件の問題` を
                    // `⚠ 1…` と読ませる。
                    maxLines: 2,
                    style: TextStyle(
                      color: has ? colors.danger : colors.success,
                      fontSize: AppFontSize.bodySmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // **押せることを示す**(2026-09-30 の開発者の指定)。太字・下線の「詳細」。
                  // 押せるのはこの文字だけではない — バナーの行のどこを押しても開く。
                  //
                  // **下線は文字の装飾ではなく、文字の下に引いた線**(同日の指定「太く
                  // しつつ少しだけ下にずらす」)。文字の装飾の下線は文字に接して細く、
                  // 見えづらかった。
                  if (has)
                    Container(
                      key: warningDetailLinkKey,
                      // 文字の枠の下端に接して引く。2 離したら「離れすぎ」だった
                      // (2026-09-30 の開発者の指定。文字の枠が字形より下まであるので、
                      // 接していても字形からは少し離れて見える)。
                      padding: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colors.danger,
                            width: warningLinkUnderlineWidth,
                          ),
                        ),
                      ),
                      child: Text(
                        '詳細',
                        style: TextStyle(
                          color: colors.danger,
                          fontSize: AppFontSize.bodySmall,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 件数表示の「詳細」(押せることを示す文字と、その下の線)。
const Key warningDetailLinkKey = Key('warning-detail-link');

/// 押せることを示す下線の太さ。件数表示の「詳細」と行の警告で共有する
/// (2026-09-30 の開発者の指定「太くしつつ少しだけ下にずらす」、`008:T50` で行へも)。
const double warningLinkUnderlineWidth = 1.5;

/// 行の警告の文字の下の線(`008:T50`)。
const Key rowWarningUnderlineKey = Key('row-warning-underline');

/// 状態のメッセージのバナーの印の大きさ。行ごとに揃える(`008:T02`)。
const double bannerIconSize = 14;

/// 状態のメッセージのバナーの、印と文の間。行ごとに揃える(`008:T02`)。
const double bannerIconGap = 8;

/// 詳細modalの重複の組1つ(**同じ folder で同じ変更後名になるファイル**。`008:T53`)。
class WarningDetailGroup {
  const WarningDetailGroup({required this.resultName, required this.members});

  /// 組の見出し(変更後名。同じ名前の組が別の folder にもあれば場所を添える)。
  final String resultName;

  /// その名前になる、読み込んだファイル([fileLabel])。
  ///
  /// **1件だけなら、相手は読み込んでいないファイル**(フォルダにもともとある同名の
  /// ファイル、または選んでいない行)である — 001 は相手が読み込んだファイルなら
  /// その相手にも重複を返す。
  final List<String> members;

  /// 相手が読み込んだファイルの中に無い(フォルダにある既存のファイルとぶつかる)か。
  bool get collidesWithExisting => members.length == 1;
}

/// 詳細modalの節1つ(005 REQ-009 (2) / (3))。
///
/// **説明は節に1つだけ**で、対象の件数に比例しない。単位は原因(トークン)ごと
/// なので、取れない日時トークンが2本あれば節が2つになる。
class WarningDetailSection {
  const WarningDetailSection({
    required this.title,
    required this.explanation,
    required this.targets,
    this.groups = const <WarningDetailGroup>[],
  });

  /// 種別名と件数の見出し。
  final String title;

  /// ファイルによって変わらない説明(**節に1つ**)。
  final String explanation;

  /// 対象の識別([fileLabel])。重複の節では [groups] の全員を並べた順。
  final List<String> targets;

  /// 重複の節だけ: 変更後名ごとの組(`008:T53`)。他の節は空。
  final List<WarningDetailGroup> groups;
}

/// 重複の組を分ける鍵。001 が重複を数えるのと同じ — **folder と変更後名**。
(String?, String) _duplicateKey(DuplicateWarning warning) =>
    (warning.file.sourceFolder, warning.resultName);

/// 行から開く詳細へ渡す警告(005 REQ-009 (4)、revision 10.0。`008:T53`)。
///
/// その行の警告([rowWarnings])に、**その行の重複の相手**の重複の警告を足す。
/// 相手は [allWarnings] のうち、同じ folder・同じ変更後名の重複である。
/// **相手の他の警告(日時不明など)は足さない** — 相手は、そのファイルの重複という
/// 1つの出来事の一部として読ませる。
///
/// [rowWarnings] と [allWarnings] は**同じ評価**から取ること(`controller.preview`)。
/// その行の重複を identity で見分けて二重に足さない。
List<Warning> rowDetailWarnings(
  List<Warning> rowWarnings,
  List<Warning> allWarnings,
) {
  final keys = {
    for (final w in rowWarnings.whereType<DuplicateWarning>()) _duplicateKey(w),
  };
  if (keys.isEmpty) return rowWarnings;
  final own = Set<Warning>.identity()..addAll(rowWarnings);
  return <Warning>[
    ...rowWarnings,
    for (final w in allWarnings.whereType<DuplicateWarning>())
      if (!own.contains(w) && keys.contains(_duplicateKey(w))) w,
  ];
}

/// [warnings] を原因ごとの節へ組む(`008:T19`。2026-09-02 の要望3・4)。
///
/// **呼び出し側がスコープを決めて渡す** — 行から開くならその行の警告と重複の相手
/// ([rowDetailWarnings])、ヘッダの件数から開くなら全件(005 REQ-009 (4))。
///
/// **重複は変更後名ごとの組に分ける**(`008:T53`。2026-10-02 の開発者の要望
/// 「重複するファイルを一つの枠に列挙する」)。1つの節に全件を並べると、どれと
/// どれが同じ名前になるのかを名前を見比べて探すことになる。
///
/// **REQ-021 のまとめは行だけに効かせる。** 空名と基準日時不明が同時に該当する
/// ファイルは、行では結果へ畳む(規則1)が、ここでは両方の節に並ぶ —
/// REQ-009 (3)/(4) が「(1) では読めない情報(トークンの名指し)へ到達できること」を
/// 課しているので、原因の節を落とすと名指しへ到達できない。**説明は原因ごとに
/// 1つ**なので (2) に反しない。
///
/// ルールが空なら空を返す(005 REQ-020: 警告ではなく未設定を提示する)。
List<WarningDetailSection> warningDetailSections(
  List<Warning> warnings, {
  required bool ruleIsEmpty,
  Iterable<FileEntry> amongFiles = const <FileEntry>[],
}) {
  if (ruleIsEmpty) return const <WarningDetailSection>[];
  final ambiguous = _ambiguousAmong(warnings, amongFiles);
  String label(FileEntry file) =>
      fileLabel(file, withLocation: ambiguous.contains(file.name));

  // 原因ごとにまとめる。**001 が返した順序のまま**節を並べる(安定した順序)。
  final order = <String>[];
  final kinds = <String, String>{};
  final explanations = <String, String>{};
  final targets = <String, List<String>>{};

  void put(String key, String kind, String explanation, String? target) {
    if (!kinds.containsKey(key)) {
      order.add(key);
      kinds[key] = kind;
      explanations[key] = explanation;
      targets[key] = <String>[];
    }
    if (target != null) targets[key]!.add(target);
  }

  // 重複の組(現れた順)。組の中も現れた順。
  final groups = <(String?, String), List<FileEntry>>{};

  for (final warning in warnings) {
    switch (warning) {
      case DigitShortageWarning(
        :final tokenIndex,
        :final token,
        :final requiredDigits,
      ):
        put(
          'digit-$tokenIndex',
          warningKindLabel(warning),
          '${tokenIndex + 1} 番目のトークン(${describeToken(token)})は'
              '$requiredDigits 桁必要です',
          null,
        );
      case MissingSourceDateWarning(
        :final tokenIndex,
        :final token,
        :final file,
      ):
        put(
          'date-$tokenIndex',
          warningKindLabel(warning),
          '${tokenIndex + 1} 番目のトークン(${describeToken(token)})は'
              '${describeDateTimeSource(token.source)}が取れないため、'
              'その部分が空になります',
          label(file),
        );
      case DuplicateWarning(:final file):
        put(
          'duplicate',
          warningKindLabel(warning),
          '変更後の名前が同じになるファイルを、名前ごとにまとめています',
          null,
        );
        final members = groups[_duplicateKey(warning)] ??= <FileEntry>[];
        if (!members.any((m) => identical(m, file))) members.add(file);
      case EmptyNameWarning(:final file):
        put(
          'empty',
          warningKindLabel(warning),
          '変更後の名前が空になるため、これらのファイルは改名されません',
          label(file),
        );
    }
  }

  // 同じ変更後名の組が別の folder にもあれば、見出しに場所を添える。
  final sharedNames = <String>{};
  final seenNames = <String>{};
  for (final (_, name) in groups.keys) {
    if (!seenNames.add(name)) sharedNames.add(name);
  }
  final duplicateGroups = <WarningDetailGroup>[
    for (final MapEntry(key: (_, name), value: members) in groups.entries)
      WarningDetailGroup(
        resultName: switch (members.first.sourceLocation) {
          final location? when sharedNames.contains(name) =>
            '「$name」($location)',
          _ => '「$name」',
        },
        members: [for (final m in members) label(m)],
      ),
  ];
  if (duplicateGroups.isNotEmpty) {
    targets['duplicate'] = [for (final g in duplicateGroups) ...g.members];
  }

  return <WarningDetailSection>[
    for (final key in order)
      WarningDetailSection(
        title: targets[key]!.isEmpty
            ? kinds[key]!
            : '${kinds[key]!} ${targets[key]!.length} 件',
        explanation: explanations[key]!,
        targets: targets[key]!,
        groups: key == 'duplicate'
            ? duplicateGroups
            : const <WarningDetailGroup>[],
      ),
  ];
}

/// 重複の組1つの枠(`008:T53`)。
Key warningDetailGroupKey(int section, int group) =>
    Key('warning-detail-group-$section-$group');

/// 詳細dialogの「閉じる」。
const Key warningDetailCloseKey = Key('warning-detail-close');

/// 相手が読み込んだファイルの中に無いときの書き方(`008:T53`)。
///
/// 001 の警告は相手が占有名かどうかを持たないので、「読み込んだ相手が無い」ことから
/// こう書く(005 revision 10.0 で提示の自由とした)。選んでいない行の現在名と
/// ぶつかる場合も、フォルダにある既存のファイルであることは変わらない。
///
/// 文言と赤は 2026-10-02 の実機確認での開発者の指定。
const String existingFileLabel = '(フォルダにある既存のファイルと重複)';

/// 重複の組の、変更後名の行(組の最後の行)。
const Key warningDetailGroupResultKey = Key('warning-detail-group-result');

/// 重複の組の「(フォルダにある既存のファイルと重複)」の行(変更後名の次の行)。
const Key warningDetailGroupExistingKey = Key('warning-detail-group-existing');

/// 警告の詳細(005 REQ-009 (3) / (4))。
///
/// **スコープは呼び出し側が決める。** [warnings] にその行の警告(と重複の相手。
/// [rowDetailWarnings])を渡せばその行の詳細、全件を渡せば全件の詳細になる。
/// [scopeFile] は見出しに使うだけで絞り込みはしない(絞り込みの正本は渡された
/// [warnings] である)。
///
/// 見た目は実行前の確認(`008:T14`)と同じ枠([DesignDialog] / [IssueCard])。
Future<void> showWarningDetail(
  BuildContext context,
  List<Warning> warnings, {
  required bool ruleIsEmpty,
  FileEntry? scopeFile,
  Iterable<FileEntry> amongFiles = const <FileEntry>[],
}) async {
  final sections = warningDetailSections(
    warnings,
    ruleIsEmpty: ruleIsEmpty,
    amongFiles: amongFiles,
  );
  if (sections.isEmpty) return;
  await showDialog<void>(
    context: context,
    barrierColor: designDialogBarrierColor,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      final targetStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: AppFontSize.small,
        height: 1.5,
      );
      return DesignDialog(
        key: warningDetailDialogKey,
        title: scopeFile == null
            ? warningCountLabel(warnings)
            : '${fileLabel(scopeFile, withLocation: false)}の問題',
        body: [
          Column(
            key: warningDetailSectionsKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, section) in sections.indexed)
                IssueCard(
                  key: warningDetailSectionKey(index),
                  title: section.title,
                  // **説明は節に1つだけ**(005 REQ-009 (2))。
                  description: section.explanation,
                  descriptionKey: warningDetailExplanationKey(index),
                  child: section.targets.isEmpty
                      ? null
                      : Column(
                          key: warningDetailTargetsKey(index),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (section.groups.isEmpty)
                              for (final target in section.targets)
                                Text(target, style: targetStyle),
                            for (final (g, group) in section.groups.indexed)
                              _DuplicateGroupBox(
                                key: warningDetailGroupKey(index, g),
                                group: group,
                                targetStyle: targetStyle,
                              ),
                          ],
                        ),
                ),
            ],
          ),
        ],
        actions: [
          Expanded(
            child: DialogButton(
              key: warningDetailCloseKey,
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

/// 重複の組1つ: 変更後名の見出しと、その名前になるファイル(`008:T53`)。
class _DuplicateGroupBox extends StatelessWidget {
  const _DuplicateGroupBox({
    super.key,
    required this.group,
    required this.targetStyle,
  });

  final WarningDetailGroup group;
  final TextStyle targetStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final danger = TextStyle(
      color: colors.danger,
      fontSize: AppFontSize.small,
      fontWeight: FontWeight.w700,
      height: 1.5,
    );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.danger.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // **ファイルは「、」で区切って横へ並べ、入りきらなければ名前の切れ目で次の行へ
          // 送る**(2026-10-02 の実機確認。原文は「入りきらない場合はファイル名の途中では
          // 改行せず、次の行から始めるイメージ」)。区切りは名前の後ろに付け、行頭に
          // 「、」が来ないようにする。
          Wrap(
            children: [
              for (final (i, member) in group.members.indexed)
                Text(
                  i < group.members.length - 1 ? '$member、' : member,
                  style: targetStyle,
                ),
            ],
          ),
          // **変更後名は最後の行**(同じ確認。原文は「1行目に矢印があるのは不自然」)。
          // ファイル → 名前の順に読める。
          Text(
            '→ ${group.resultName}',
            key: warningDetailGroupResultKey,
            style: danger,
          ),
          // 相手が読み込んだファイルの中に無い組は、変更後名の次の行で示す(同じ確認)。
          if (group.collidesWithExisting)
            Text(
              existingFileLabel,
              key: warningDetailGroupExistingKey,
              style: danger,
            ),
        ],
      ),
    );
  }
}
