// VER-001: RenameRule/Token ⇔ JSON シリアライズの検証(FEAT-007 / Light)。
// 対象: REQ-001(往復可逆), REQ-002(type タグ + パラメータ), REQ-003(version),
//       REQ-004(不正JSON/未知type/欠損/非対応バージョン → null)。
import 'dart:convert';

import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/core/rule_serialization.dart';
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
      expect(a.zeroPad, expected.zeroPad);
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

    test('例8: ゼロ埋めなしの連番(014:T03)', () {
      _expectRoundTrip(
        const RenameRule([
          SequenceToken(start: 1, digits: 2, increment: 1, zeroPad: false),
        ]),
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

  group('REQ-002/REQ-003: スキーマ(type タグ + パラメータ + version)', () {
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
        'zero_padding': true,
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

    test('例10: 連番の zero_padding が真偽値でない(014:T03)', () {
      for (final bad in ['"no"', '0', 'null']) {
        expect(
          deserializeRule(
            '{"version":1,"tokens":[{"type":"sequence_number","start":1,'
            '"digits":2,"increment":1,"zero_padding":$bad}]}',
          ),
          isNull,
          reason: 'zero_padding = $bad',
        );
      }
    });

    test('正当な JSON は復元できる(異常系の対比)', () {
      final rule = deserializeRule(
        '{"version":1,"tokens":[{"type":"original_name"}]}',
      );
      expect(rule, isNotNull);
      expect(rule!.tokens.single, isA<OriginalNameToken>());
    });
  });

  // 014:T03。**版は 1 のまま**、`zero_padding` を任意フィールドとして足した
  // (007 spec の「014:T01 由来の更新」)。014 より前に保存されたルールが消えず、
  // 今と同じ名前をつけるまま復元されることをここで固定する。
  group('REQ-004: zero_padding の無い既存の保存(014 より前の形)', () {
    const legacy =
        '{"version":1,"tokens":[{"type":"original_name"},{"type":"text","value":"_"},'
        '{"type":"sequence_number","start":1,"digits":2,"increment":1}]}';

    test('例9: 復元でき、連番はゼロ埋めあり', () {
      final rule = deserializeRule(legacy);
      expect(rule, isNotNull);
      final seq = rule!.tokens[2] as SequenceToken;
      expect(seq.start, 1);
      expect(seq.digits, 2);
      expect(seq.increment, 1);
      expect(seq.zeroPad, isTrue);
    });

    test('例9: 今と同じ名前をつける(IMG.jpg の3番目 -> IMG_03.jpg)', () {
      final rule = deserializeRule(legacy)!;
      final file = FileEntry(
        name: 'IMG.jpg',
        createdAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 1),
        size: 0,
      );
      expect(buildName(rule, file, 3, DateTime(2026)), 'IMG_03.jpg');
    });

    test('書き直すと zero_padding を含む', () {
      final map =
          jsonDecode(serializeRule(deserializeRule(legacy)!))
              as Map<String, Object?>;
      final seq = (map['tokens'] as List)[2] as Map<String, Object?>;
      expect(seq['zero_padding'], true);
      expect(map['version'], 1);
    });
  });
}
