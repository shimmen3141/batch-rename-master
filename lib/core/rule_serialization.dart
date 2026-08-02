import 'dart:convert';

import 'rename_rule.dart';
import 'token.dart';

/// ルール永続化(FEAT-007)の JSON シリアライズ。純粋 Dart で `package:flutter` /
/// `dart:io` に依存しない(`dart:convert` のみ)。正本は spec.md。
///
/// スキーマ: `{"version": 1, "tokens": [ {type タグ + パラメータ}, ... ]}`。
/// type タグ: `original_name` / `text`(自由テキスト・区切り兼用の [LiteralToken])/
/// `sequence_number` / `datetime`。

/// 現在のスキーマバージョン(REQ-003)。これ以外は復元不可として `null`(REQ-004)。
const int ruleSchemaVersion = 1;

/// [rule] を JSON 文字列にする(REQ-001/002/003)。
String serializeRule(RenameRule rule) => jsonEncode(<String, Object?>{
  'version': ruleSchemaVersion,
  'tokens': [for (final token in rule.tokens) _tokenToJson(token)],
});

/// JSON 文字列を [RenameRule] に戻す(REQ-001/004)。
///
/// 不正な JSON・非対応バージョン・`tokens` 不正・未知 type・必須フィールド欠損の
/// いずれでも `null` を返す(例外を投げない)。呼び出し側は `null` を空ルールへ
/// フォールバックする。
RenameRule? deserializeRule(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['version'] != ruleSchemaVersion) return null;
  final rawTokens = decoded['tokens'];
  if (rawTokens is! List) return null;

  final tokens = <Token>[];
  for (final raw in rawTokens) {
    final token = _tokenFromJson(raw);
    if (token == null) return null;
    tokens.add(token);
  }
  return RenameRule(tokens);
}

Map<String, Object?> _tokenToJson(Token token) => switch (token) {
  OriginalNameToken() => {'type': 'original_name'},
  LiteralToken(:final value) => {'type': 'text', 'value': value},
  SequenceToken(:final start, :final digits, :final increment) => {
    'type': 'sequence_number',
    'start': start,
    'digits': digits,
    'increment': increment,
  },
  DateTimeToken(:final source, :final format) => {
    'type': 'datetime',
    'source': _sourceToJson(source),
    'format': format,
  },
};

Token? _tokenFromJson(Object? raw) {
  if (raw is! Map) return null;
  switch (raw['type']) {
    case 'original_name':
      return const OriginalNameToken();
    case 'text':
      final value = raw['value'];
      return value is String ? LiteralToken(value) : null;
    case 'sequence_number':
      final start = raw['start'];
      final digits = raw['digits'];
      final increment = raw['increment'];
      if (start is! int || digits is! int || increment is! int) return null;
      return SequenceToken(start: start, digits: digits, increment: increment);
    case 'datetime':
      final source = _sourceFromJson(raw['source']);
      final format = raw['format'];
      if (source == null || format is! String) return null;
      return DateTimeToken(source: source, format: format);
    default:
      return null; // 未知 type
  }
}

String _sourceToJson(DateTimeSource source) => switch (source) {
  DateTimeSource.created => 'created',
  DateTimeSource.modified => 'modified',
  DateTimeSource.current => 'current',
};

DateTimeSource? _sourceFromJson(Object? raw) => switch (raw) {
  'created' => DateTimeSource.created,
  'modified' => DateTimeSource.modified,
  'current' => DateTimeSource.current,
  _ => null,
};
