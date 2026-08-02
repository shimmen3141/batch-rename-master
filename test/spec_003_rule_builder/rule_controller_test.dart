// VER-001: RuleController の状態・操作の検証(FEAT-003 / Light)。
// 対象: REQ-001(初期化・rule 一致), REQ-002(addToken), REQ-003(removeAt),
//       REQ-004(reorder, onReorderItem 規約), REQ-005(replaceAt),
//       REQ-006(rule 常時一致・変更通知), REQ-007(空状態)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('REQ-001: 初期化', () {
    test('既定は空で、rule.tokens は tokens に等しい', () {
      final c = RuleController();
      expect(c.tokens, isEmpty);
      expect(c.rule.tokens, isEmpty);
    });

    test('初期トークン列を順に保持する', () {
      const a = OriginalNameToken();
      const b = LiteralToken('_');
      final c = RuleController(tokens: const [a, b]);
      expect(c.tokens, [a, b]);
      expect(c.rule.tokens, [a, b]);
    });

    test('tokens は読み取り専用ビュー', () {
      final c = RuleController();
      expect(
        () => c.tokens.add(const OriginalNameToken()),
        throwsUnsupportedError,
      );
    });

    test('rule はスナップショット(取得後の編集は影響しない)', () {
      final c = RuleController();
      final snapshot = c.rule;
      c.addToken(const OriginalNameToken());
      expect(snapshot.tokens, isEmpty);
      expect(c.rule.tokens, hasLength(1));
    });
  });

  group('REQ-002: addToken', () {
    test('末尾に追加する', () {
      final c = RuleController();
      const a = OriginalNameToken();
      const b = SequenceToken(start: 1, digits: 2);
      c.addToken(a);
      c.addToken(b);
      expect(c.tokens, [a, b]);
      expect(c.rule.tokens, [a, b]);
    });
  });

  group('REQ-003: removeAt', () {
    test('指定要素だけ取り除き相対順を保つ', () {
      const a = OriginalNameToken();
      const b = LiteralToken('_');
      const d = SequenceToken(start: 1, digits: 2);
      final c = RuleController(tokens: const [a, b, d]);
      c.removeAt(1);
      expect(c.tokens, [a, d]);
    });
  });

  group('REQ-004: reorder(onReorderItem 規約)', () {
    test('下方向: reorder(0,1)', () {
      const a = OriginalNameToken();
      const b = LiteralToken('b');
      const d = LiteralToken('c');
      final c = RuleController(tokens: const [a, b, d]);
      c.reorder(0, 1); // a を index1 へ -> [b, a, c]
      expect(c.tokens, [b, a, d]);
    });

    test('末尾へ: reorder(0,2)', () {
      const a = OriginalNameToken();
      const b = LiteralToken('b');
      const d = LiteralToken('c');
      final c = RuleController(tokens: const [a, b, d]);
      c.reorder(0, 2); // 削除後 index2 へ -> [b, c, a]
      expect(c.tokens, [b, d, a]);
    });
  });

  group('REQ-005: replaceAt', () {
    test('位置を保って差し替える', () {
      const a = OriginalNameToken();
      const seq1 = SequenceToken(start: 1, digits: 1);
      const seq3 = SequenceToken(start: 1, digits: 3);
      final c = RuleController(tokens: const [a, seq1]);
      c.replaceAt(1, seq3);
      expect(c.tokens, [a, seq3]);
    });
  });

  group('REQ-006: rule 常時一致・変更通知', () {
    test('各変更操作後に rule.tokens が現在の tokens に一致', () {
      final c = RuleController();
      c.addToken(const LiteralToken('x'));
      expect(c.rule.tokens, c.tokens);
      c.replaceAt(0, const OriginalNameToken());
      expect(c.rule.tokens, c.tokens);
    });

    test('各操作で listener に通知する', () {
      final c = RuleController(tokens: const [OriginalNameToken()]);
      var n = 0;
      c.addListener(() => n++);
      c.addToken(const LiteralToken('_')); // 1
      c.replaceAt(0, const LiteralToken('y')); // 2
      c.reorder(0, 1); // 3
      c.removeAt(0); // 4
      expect(n, 4);
    });
  });

  group('REQ-007: 空状態', () {
    test('全削除後も有効で rule は空トークンの RenameRule', () {
      final c = RuleController(tokens: const [OriginalNameToken()]);
      c.removeAt(0);
      expect(c.tokens, isEmpty);
      expect(c.rule.tokens, isEmpty);
    });
  });
}
