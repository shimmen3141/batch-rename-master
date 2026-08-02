// VER-001: RenameRule/Token ⇔ JSON シリアライズの検証(FEAT-007 / Light)。
// 対象: REQ-001(往復可逆), REQ-002(type タグ + パラメータ), REQ-003(version),
//       REQ-004(不正JSON/未知type/欠損/非対応バージョン → null)。
import 'dart:convert';

import 'package:batch_rename_master/core/rename_rule.dart';
import 'package:batch_rename_master/core/rule_serialization.dart';
import 'package:batch_rename_master/core/token.dart';
import 'package:flutter_test/flutter_test.dart';

/// round-trip の等価判定(Token は == 未実装のため種別+パラメータで照合)。
void _expectSameToken(Token actual, Token expected) {
  expect(actual.runtimeType, expected.runtimeType);
  switch (expected) {
    case OriginalNameToken():
      break;
    case LiteralToken():
      expect((actual as LiteralToken).value, expected.value);
    case SequenceToken():
      final a = actual as SequenceToken;
      expect(a.start, expected.start);
      expect(a.digits, expected.digits);
      expect(a.increment, expected.increment);
    case DateTimeToken():
      final a = actual as DateTimeToken;
      expect(a.source, expected.source);
      expect(a.format, expected.format);
  }
}

void _expectRoundTrip(RenameRule rule) {
  final restored = deserializeRule(serializeRule(rule));
  expect(restored, isNotNull);
  expect(restored!.tokens.length, rule.tokens.length);
  for (var i = 0; i < rule.tokens.length; i++) {
    _expectSameToken(restored.tokens[i], rule.tokens[i]);
  }
}

void main() {
  group('REQ-001: round-trip 可逆', () {
    test('全種別を含むルール', () {
      _expectRoundTrip(
        const RenameRule([
          OriginalNameToken(),
          LiteralToken('_'),
          SequenceToken(start: 1, digits: 2, increment: 1),
          DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
        ]),
      );
    });

    test('日時の全 source', () {
      for (final s in DateTimeSource.values) {
        _expectRoundTrip(RenameRule([DateTimeToken(source: s, format: 'YY')]));
      }
    });

    test('連番の非既定パラメータ', () {
      _expectRoundTrip(
        const RenameRule([SequenceToken(start: 100, digits: 4, increment: 5)]),
      );
    });

    test('空ルール', () {
      _expectRoundTrip(RenameRule.empty);
    });

    test('リテラルの空白・記号', () {
      _expectRoundTrip(
        const RenameRule([LiteralToken('　'), LiteralToken('-')]),
      );
    });
  });

  group('REQ-002/003: スキーマ(type タグ + パラメータ + version)', () {
    test('version と type タグが確定スキーマどおり', () {
      final json = serializeRule(
        const RenameRule([
          OriginalNameToken(),
          LiteralToken('x'),
          SequenceToken(start: 1, digits: 2, increment: 1),
          DateTimeToken(source: DateTimeSource.modified, format: 'YYYY'),
        ]),
      );
      final map = jsonDecode(json) as Map<String, Object?>;
      expect(map['version'], 1);
      final tokens = (map['tokens'] as List).cast<Map<String, Object?>>();
      expect(tokens[0]['type'], 'original_name');
      expect(tokens[1], {'type': 'text', 'value': 'x'});
      expect(tokens[2], {
        'type': 'sequence_number',
        'start': 1,
        'digits': 2,
        'increment': 1,
      });
      expect(tokens[3], {
        'type': 'datetime',
        'source': 'modified',
        'format': 'YYYY',
      });
    });
  });

  group('REQ-004: 異常入力は null(例外を投げない)', () {
    test('不正な JSON', () {
      expect(deserializeRule('{壊れた'), isNull);
      expect(deserializeRule(''), isNull);
      expect(deserializeRule('[]'), isNull); // Map でない
    });

    test('非対応バージョン', () {
      expect(deserializeRule('{"version":2,"tokens":[]}'), isNull);
      expect(deserializeRule('{"tokens":[]}'), isNull); // version 欠損
    });

    test('tokens が不正', () {
      expect(deserializeRule('{"version":1}'), isNull);
      expect(deserializeRule('{"version":1,"tokens":{}}'), isNull);
    });

    test('未知 type', () {
      expect(
        deserializeRule('{"version":1,"tokens":[{"type":"unknown"}]}'),
        isNull,
      );
    });

    test('必須フィールド欠損', () {
      // text の value 欠損
      expect(
        deserializeRule('{"version":1,"tokens":[{"type":"text"}]}'),
        isNull,
      );
      // sequence_number の digits 欠損
      expect(
        deserializeRule(
          '{"version":1,"tokens":[{"type":"sequence_number","start":1,"increment":1}]}',
        ),
        isNull,
      );
      // datetime の source が不正値
      expect(
        deserializeRule(
          '{"version":1,"tokens":[{"type":"datetime","source":"bad","format":"YY"}]}',
        ),
        isNull,
      );
    });

    test('正当な JSON は復元できる(異常系の対比)', () {
      final rule = deserializeRule(
        '{"version":1,"tokens":[{"type":"original_name"}]}',
      );
      expect(rule, isNotNull);
      expect(rule!.tokens.single, isA<OriginalNameToken>());
    });
  });
}
