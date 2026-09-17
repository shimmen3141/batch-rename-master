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
  SequenceToken(:final digits) => '連番($digits桁)',
  DateTimeToken(:final format) => '日時 $format',
};

String _literalLabel(String value) {
  if (value.isEmpty) return '(未入力)';
  // 空白は Chip 上で見えないため可視記号に置き換える。
  return value.replaceAll(' ', '␣').replaceAll('　', '␣');
}
