import '../../core/rename_engine.dart';

/// 追加ボタンが表す 5 種のトークン(003 spec 決定済み事項)。
///
/// 自由テキストと区切りはどちらも 001 の [LiteralToken] だが、UI 上は別ボタンで
/// 別の初期値・別の詳細エディタを持つ(区切りはプリセット選択、自由テキストは入力)。
enum TokenKind { originalName, freeText, separator, sequence, dateTime }

/// 各追加ボタンが開くエディタの初期値(003 spec の決定済み事項)。
///
/// **列へは入れない。** エディタで確定した値だけが追加される(003 REQ-008)。
/// 元の名前は設定項目が無いので、この値がそのまま追加される(REQ-010)。
/// 自由テキストは空から始め、空のあいだ確定できない(REQ-012)。
Token initialTokenFor(TokenKind kind) => switch (kind) {
  TokenKind.originalName => const OriginalNameToken(),
  TokenKind.freeText => const LiteralToken(''),
  TokenKind.separator => const LiteralToken('_'),
  TokenKind.sequence => const SequenceToken(start: 1, digits: 2),
  TokenKind.dateTime => const DateTimeToken(
    source: DateTimeSource.created,
    format: 'YYYYMMDD',
  ),
};

/// 区切りプリセット(003 spec 決定済み: ハイフン/アンダーバー/半角/全角スペース)。
const List<String> separatorPresets = ['-', '_', ' ', '　'];

/// 日時フォーマットのプリセット(003 spec 決定済み。参考デザイン準拠)。
const List<String> dateTimePresets = [
  'YYYYMMDD',
  'YYYY-MM-DD',
  'YYYYMMDD_HHmmss',
  'YYMMDD',
];

/// Chip に表示するトークンの短いラベル。
String tokenLabel(Token token) => switch (token) {
  OriginalNameToken() => '元の名前',
  LiteralToken(:final value) => _literalLabel(value),
  SequenceToken(:final digits, :final zeroPad) =>
    zeroPad ? '連番($digits桁)' : '連番(ゼロ埋めなし)',
  DateTimeToken(:final format) => '日時 $format',
};

String _literalLabel(String value) {
  if (value.isEmpty) return '(未入力)';
  // 空白は Chip 上で見えないため可視記号に置き換える。
  return value.replaceAll(' ', '␣').replaceAll('　', '␣');
}

/// チップの上段に出す種類名(参考デザイン `docs/design/Bulk Renamer.html` の
/// tokenChips。008:T45)。
///
/// 文字列トークンは入口を持たない(003 REQ-011)ので、値が区切りのプリセットなら
/// 「区切り」、それ以外は「テキスト」と呼ぶ。日時は基準の名前にする。
String tokenKindLabel(Token token) => switch (token) {
  // 「元名」から変えた(2026-09-30 の開発者の指定。`008:T47`)。
  OriginalNameToken() => '元の名前',
  LiteralToken(:final value) =>
    separatorPresets.contains(value) ? '区切り' : 'テキスト',
  SequenceToken() => '連番',
  DateTimeToken(:final source) => switch (source) {
    DateTimeSource.created => '作成日時',
    DateTimeSource.modified => '更新日時',
    DateTimeSource.current => '現在日時',
  },
};

/// チップの下段に出す値: 一覧の1件目([sample])で描いた実際の値(参考デザイン。
/// 008:T45)。
///
/// 元の名前はファイルごとに違うので `ファイル名`(2026-09-30 に `[元のファイル名]` から変えた。`008:T47`)。連番は1番目の値。日時は
/// 1件目が無ければフォーマットそのもの、基準の日時が不明なら「不明」(001 INV-006。
/// 別の日時で代えない)。空白は見えないので `␣` にする。
String tokenChipValue(Token token, FileEntry? sample) {
  final raw = switch (token) {
    OriginalNameToken() => 'ファイル名',
    LiteralToken(:final value) => value,
    SequenceToken() => token.render(
      RenameContext(
        file: sample ?? _placeholderFile,
        position: 1,
        now: DateTime.now(),
      ),
    ),
    DateTimeToken(:final format) =>
      sample == null
          ? format
          : token.render(
              RenameContext(file: sample, position: 1, now: DateTime.now()),
            ),
  };
  if (raw.isEmpty) return token is DateTimeToken ? '不明' : '␣';
  return raw.replaceAll(' ', '␣').replaceAll('　', '␣');
}

/// 連番の値を描くためだけの入れ物(連番はファイルを見ない。001 REQ-003)。
final FileEntry _placeholderFile = FileEntry(
  name: '',
  createdAt: null,
  modifiedAt: DateTime(2000),
  size: 0,
);
