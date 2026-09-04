import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';

/// ルール未設定の案内帯(警告が 0 件でない状態の代わりに出る)。
const Key ruleNotConfiguredKey = Key('rule-not-configured');

/// 一覧全体の警告件数(常に見える。押すと全件の詳細が開く。005 REQ-009 (3))。
const Key warningCountKey = Key('warning-count');

/// 行の警告(005 REQ-009 (1))。押すと全件の詳細が開く。
const Key rowWarningKey = Key('row-warning');

/// ルールを直せば消える原因の提示(005 REQ-009 (2))。件数ぶん繰り返さない。
///
/// **狭幅では下部バーのルール設定button内、広幅では右ペイン上部**にある。
/// どちらの layout にも在ることが要求である(片方だけだと行き場を失う)。
const Key ruleWarningNoticeKey = Key('rule-warning-notice');

/// 設定中のルールの1行要約(参考designのルール設定button 2行目)。
const Key ruleSummaryKey = Key('rule-summary');

/// 詳細dialog内の「原因ごとの説明」節(005 REQ-009 (2) の説明の置き場所)。
const Key warningDetailCausesKey = Key('warning-detail-causes');

/// 詳細dialog内の「ファイルごとの全件」節(005 REQ-009 (3))。
const Key warningDetailFilesKey = Key('warning-detail-files');

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
  DigitShortageWarning() => digitShortageKindLabel,
  EmptyNameWarning() => '空の名前',
  MissingSourceDateWarning() => missingSourceDateKindLabel,
};

/// ルールを直せば消える種別。**この2つがルール由来の警告のすべてである** —
/// 重複と空の名前はファイル単位なので行が持つ。[ruleWarningKinds] と共有する。
const String digitShortageKindLabel = '桁不足';
const String missingSourceDateKindLabel = '基準日時なし';

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

/// 行の警告の角の丸み・塗り・枠・文字の濃さ。
///
/// **押せると分かる形にするため**の値である(2026-09-03 のmanual確認)。
/// 値そのものは自由で、**固定しているのは「文字が変更後名より薄い」ことと
/// 「枠と塗りが在る」ことである**(widget test が正本)。
const double rowWarningRadius = 6;
const double rowWarningFillOpacity = 0.12;
const double rowWarningBorderOpacity = 0.45;
const double rowWarningLabelOpacity = 0.78;

/// 行の警告の文字とアイコンの大きさ。
const double rowWarningFontSize = 11;

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
///   同じ文言を並べても情報が増えない(名指しは [ruleWarningExplanations] と詳細)。
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
  // **どの基準が取れないかを明示する**(2026-09-02 の要望5。原文は「『基準日時
  // なし』…『作成日時不明』『更新日時不明』とちゃんと明示してほしい」)。
  // 実際に取れないのは作成日時だけだが(001 INV-006: 更新日時・現在日時は常に
  // 値を持つ)、**基準から導いて誤った名前を出さないようにする。**
  MissingSourceDateWarning(:final token) =>
    '${describeDateTimeSource(token.source)}不明',
  // 002 REQ-015 の導出で**行へ来る**(008:T17 の改訂)。指定桁数を超えて描かれる
  // 行だけが該当する。文言は開発者の指定(2026-09-02 の要望5)。
  DigitShortageWarning() => '連番の桁不足',
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

/// ルールを直せば消える警告の**種別**(005 REQ-009 (2) の常設側)。
///
/// **説明そのものではなく種別を返す。** 説明は原因(トークン)ごとに1つなので
/// **トークンの数だけ増える**が、種別は2つしかない。常設する提示をこちらにすると、
/// 原因が何本あっても文字倍率がいくつでも**占有が変わらない**。
///
/// **これは集約帯を廃止したときに失った保証の作り直しである。** 帯は
/// `detailMaxHeightFor`(画面高の32%上限 + scroll)で有界だったが、置換先に置いた
/// 説明の並びには上限が無く、原因3つ・文字倍率2.0で一覧が0pxになった
/// (独立review attempt 3 のP1-1)。**器へ上限を付けるのではなく、常設する中身を
/// 定数個にして解く。**説明そのものは詳細dialogが持つ([showWarningDetail])。
///
/// ルールが空なら空を返す(005 REQ-020)。
List<String> ruleWarningKinds(
  List<Warning> warnings, {
  required bool ruleIsEmpty,
}) {
  if (ruleIsEmpty) return const <String>[];
  var digits = false;
  var date = false;
  for (final warning in warnings) {
    if (warning is DigitShortageWarning) digits = true;
    if (warning is MissingSourceDateWarning) date = true;
  }
  // 001 が返した順ではなく**固定した順**で並べる(件数で並びが揺れない)。
  return <String>[
    if (digits) digitShortageKindLabel,
    if (date) missingSourceDateKindLabel,
  ];
}

/// 設定中のルールの1行要約(参考designのルール設定button 2行目)。
///
/// **最小形にとどめる** — [describeToken] を並べるだけである。文言の作り込みは
/// `008:T14`、余白・字体は `008:T10` が持つ。ルールが空なら空文字を返す。
String describeRuleSummary(RenameRule rule) =>
    rule.tokens.map(describeToken).join(' + ');

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
    // **押せると分かる形にする**(2026-09-03 のmanual確認。原文は「ぱっと見だと
    // 押せることが分からず、ただの警告文に見える。角を丸めた赤の四角で囲み、
    // 中をさらに薄い赤で塗りつぶしてボタンぽっくしても良いかも」)。
    //
    // **色は変更後名より薄くする**(同「変更後名の表示の赤と同じ濃さなので、目が
    // 散る。少しだけ薄くしても良いかも」)。行の主役は変更後名で、警告はその
    // 補足である。**種別が読めることは変わらない** — 薄くするのは濃さだけで、
    // 背景との対比は保つ。
    final label = colors.danger.withValues(alpha: rowWarningLabelOpacity);
    // **箱そのものを右へ寄せる**(参考designのコンパクト案。2026-09-02 の要望8)。
    // 箱は中身の幅しか取らないので、`Row` の `mainAxisAlignment` では寄らない。
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        key: rowWarningKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(rowWarningRadius),
        child: Container(
          // **tap範囲を文字より広く取る。** 11px の文字だけを当たり判定にすると
          // 指で外す。**この値は実機で確かめていない** — `e5aceed` の形(当たり判定が
          // 行幅いっぱい)で確認したのは 2026-09-03 で、その後この箱の形へ作り替えた。
          // **当たり判定は行幅からバッジの幅へ縮んでいる。** 手順3′で確かめ直す。
          // 縮む方向を縛る assertion は無い(`task.md` の残余risk 穴C)。
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: colors.danger.withValues(alpha: rowWarningFillOpacity),
            border: Border.all(
              color: colors.danger.withValues(alpha: rowWarningBorderOpacity),
            ),
            borderRadius: BorderRadius.circular(rowWarningRadius),
          ),
          child: Row(
            // **アイコンを文字のbaselineへ揃える**(2026-09-03 のmanual確認。原文は
            // 「！マークが警告文に対して少し上にずれている。修正したい」)。
            // `CrossAxisAlignment.start` は箱の上端を揃えるので、字面の中心が
            // 下にある文字に対してアイコンが上へ浮く。**固定値で押し下げない** —
            // 文字倍率が変わるとずれ方も変わる。`Icon` は内部が `RichText` なので
            // baseline を持つ。
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            // 箱は中身の幅だけ取る(右寄せは外側の `Align` が担う)。
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                // **字面(ink)の中心を揃えるために、baselineからさらに下げる。**
                // baselineは揃っているが(box中心の差 0.14px)、**字面の位置が違う**
                // ので上へ浮いて見える(2026-09-04 のmanual確認)。
                //
                // - Material icons は em box いっぱいに描かれ baseline の上 1em を
                //   占める → ink の中心は **baseline − 0.5em**
                // - CJKの字面は baseline の上 0.88em 〜 下 0.12em → ink の中心は
                //   **baseline − 0.38em**
                //
                // 差は **0.12em**。**固定値ではなく font size に比例させる。**
                // ただし比例先は定数なので**利用者の文字倍率には追随しない** —
                // 受容した残余risk(引き受け先 `008:T10`)。
                // [rowWarningIconInkNudge] を読むこと。
                padding: const EdgeInsets.only(right: 3),
                // **padding では下がらない。** `CrossAxisAlignment.baseline` は
                // 子の baseline を行の baseline へ固定するので、top padding を足すと
                // 箱ごと上へずれて相殺される。**paint 側でずらす。**
                child: Transform.translate(
                  offset: const Offset(
                    0,
                    rowWarningFontSize * rowWarningIconInkNudge,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: rowWarningFontSize,
                    color: label,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  warnings.map(rowWarningLabel).join('・'),
                  // 種別がすべて併発しても 2 行に収まる短さにしてある。
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: label,
                    fontSize: rowWarningFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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
    this.compact = false,
  });

  final List<Warning> warnings;
  final bool ruleIsEmpty;

  /// ルール設定button内へ入れる形(狭幅)。枠と背景を持たず見出しの右へ並ぶ。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final kinds = ruleWarningKinds(warnings, ruleIsEmpty: ruleIsEmpty);
    if (kinds.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    // **`Wrap` である。** 幅が足りないときに切り詰めると種別が読めなくなる
    // (ヘッダで2回作った退行と同じ形)。種別は最大2つなので、次の行へ落ちても
    // 増える高さは1行ぶんで止まる。
    final content = Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 13, color: colors.danger),
        for (final kind in kinds)
          Text(
            kind,
            style: TextStyle(
              color: colors.danger,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
    if (compact) return KeyedSubtree(key: ruleWarningNoticeKey, child: content);
    // **外側の余白もこの widget が持つ。** 呼び出し側が `Padding` で包むと、
    // 種別が 0 件で `SizedBox.shrink()` を返すときにも余白だけが残り、
    // 警告の無い通常状態でルールビルダーの縦を食う(独立review attempt 4 の P2-1)。
    return Container(
      key: ruleWarningNoticeKey,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: content,
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
  List<Warning> warnings, {
  required bool ruleIsEmpty,
}) async {
  if (warnings.isEmpty) return;
  final presented = presentWarnings(warnings);
  // **原因ごとの説明はここが持つ(005 REQ-009 (2))。** 常設側は種別だけなので、
  // 「何番目のトークンが何桁必要か」を読める場所はこの節である。
  final causes = ruleWarningExplanations(warnings, ruleIsEmpty: ruleIsEmpty);
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
                if (causes.isNotEmpty)
                  Column(
                    key: warningDetailCausesKey,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          'ルールの問題',
                          style: TextStyle(
                            color: colors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final cause in causes) Text('• $cause'),
                    ],
                  ),
                Column(
                  key: warningDetailFilesKey,
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
