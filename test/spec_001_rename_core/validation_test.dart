// VER-003: ドライラン検証の検証(FEAT-001)。
// 対象: REQ-007(重複), REQ-008(桁不足), REQ-009(空名), REQ-014(基準日時不明),
//       OP-003(validate)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name, {bool selected = true}) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
  selected: selected,
);

final DateTime _now = DateTime(2026, 7, 26, 9, 8, 7);

Iterable<T> _of<T>(List<Warning> ws) => ws.whereType<T>();

void main() {
  group('REQ-007: 重複警告', () {
    test('例7: 選択同士が同じ生成後名 -> 両方を重複警告', () {
      const rule = RenameRule([LiteralToken('dup')]);
      final files = [_file('a.jpg'), _file('b.jpg')];
      final dups = _of<DuplicateWarning>(validate(rule, files, _now)).toList();
      expect(dups.length, 2);
      expect(dups.map((w) => w.file.name).toSet(), {'a.jpg', 'b.jpg'});
      expect(dups.every((w) => w.resultName == 'dup.jpg'), isTrue);
    });

    test('例8: 選択の生成後名が未選択の既存ファイル名と衝突', () {
      const rule = RenameRule([LiteralToken('keep')]);
      final files = [_file('x.png'), _file('keep.png', selected: false)];
      final dups = _of<DuplicateWarning>(validate(rule, files, _now)).toList();
      expect(dups.length, 1);
      expect(dups.single.file.name, 'x.png');
      expect(dups.single.resultName, 'keep.png');
    });

    test('自分の現在名と同じになるだけなら重複ではない', () {
      const rule = RenameRule([OriginalNameToken()]);
      final files = [_file('a.jpg')];
      expect(_of<DuplicateWarning>(validate(rule, files, _now)), isEmpty);
    });

    test('別々の生成後名なら重複なし', () {
      const rule = RenameRule([OriginalNameToken()]);
      final files = [_file('a.jpg'), _file('b.jpg'), _file('c.jpg')];
      expect(_of<DuplicateWarning>(validate(rule, files, _now)), isEmpty);
    });
  });

  group('REQ-008: 桁不足警告', () {
    test('例9相当: 桁2 で最大値が100 -> 桁不足(必要3桁)', () {
      const rule = RenameRule([SequenceToken(start: 99, digits: 2)]);
      final files = [_file('a'), _file('b')]; // pos2 -> 100
      final shortages = _of<DigitShortageWarning>(
        validate(rule, files, _now),
      ).toList();
      expect(shortages.length, 1);
      expect(shortages.single.tokenIndex, 0);
      expect(shortages.single.requiredDigits, 3);
    });

    test('桁に収まるなら桁不足なし', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 2)]);
      final files = List.generate(99, (i) => _file('f$i')); // 最大99 -> 2桁
      expect(_of<DigitShortageWarning>(validate(rule, files, _now)), isEmpty);
    });

    test('選択0件なら桁不足判定はしない', () {
      const rule = RenameRule([SequenceToken(start: 1, digits: 1)]);
      final files = [_file('a', selected: false)];
      expect(_of<DigitShortageWarning>(validate(rule, files, _now)), isEmpty);
    });
  });

  group('REQ-009: 空名警告', () {
    test('例10: 空リテラルのみ(拡張子あり)-> 空名警告', () {
      const rule = RenameRule([LiteralToken('')]);
      final files = [_file('a.jpg')];
      final empties = _of<EmptyNameWarning>(
        validate(rule, files, _now),
      ).toList();
      expect(empties.length, 1);
      expect(empties.single.file.name, 'a.jpg');
    });

    test('拡張子なしファイルでベース名が空 -> 空名警告', () {
      const rule = RenameRule([LiteralToken('')]);
      final files = [_file('noext')];
      expect(_of<EmptyNameWarning>(validate(rule, files, _now)).length, 1);
    });

    test('ベース名が空でなければ空名警告なし', () {
      const rule = RenameRule([OriginalNameToken()]);
      final files = [_file('a.jpg')];
      expect(_of<EmptyNameWarning>(validate(rule, files, _now)), isEmpty);
    });
  });

  group('REQ-014: 基準日時不明の警告', () {
    /// 作成日時が不明(取得できなかった)ファイル。
    FileEntry unknownCreated(String name, {bool selected = true}) => FileEntry(
      name: name,
      modifiedAt: DateTime(2021, 8, 9, 10, 11, 12),
      size: 0,
      selected: selected,
    );

    const createdRule = RenameRule([
      DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      OriginalNameToken(),
    ]);

    test('例14: 作成日時が不明な選択ファイル + 基準=作成日時 -> 基準日時不明の警告', () {
      final warnings = validate(createdRule, [unknownCreated('x.txt')], _now);
      final missing = _of<MissingSourceDateWarning>(warnings).toList();
      expect(missing.length, 1);
      expect(missing.single.file.name, 'x.txt');
      expect(missing.single.tokenIndex, 0);
      expect(missing.single.token.source, DateTimeSource.created);
    });

    test('作成日時が判明していれば警告しない', () {
      final warnings = validate(createdRule, [_file('x.txt')], _now);
      expect(_of<MissingSourceDateWarning>(warnings), isEmpty);
    });

    test('基準が更新日時・現在日時なら不明にならず警告しない', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.modified, format: 'YYYYMMDD'),
        DateTimeToken(source: DateTimeSource.current, format: 'YYYYMMDD'),
      ]);
      final warnings = validate(rule, [unknownCreated('x.txt')], _now);
      expect(_of<MissingSourceDateWarning>(warnings), isEmpty);
    });

    test('未選択ファイルは警告しない(選択ファイルのみが対象)', () {
      final warnings = validate(createdRule, [
        unknownCreated('x.txt', selected: false),
      ], _now);
      expect(_of<MissingSourceDateWarning>(warnings), isEmpty);
    });

    test('該当トークンごとに1件(同一ファイルで2つの作成日時トークン)', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
        LiteralToken('_'),
        DateTimeToken(source: DateTimeSource.created, format: 'MMDD'),
      ]);
      final missing = _of<MissingSourceDateWarning>(
        validate(rule, [unknownCreated('x.txt')], _now),
      ).toList();
      expect(missing.map((w) => w.tokenIndex), [0, 2]);
    });

    test('ファイルごとに判定する(判明分は警告なし・不明分だけ警告)', () {
      final files = [_file('known.txt'), unknownCreated('unknown.txt')];
      final missing = _of<MissingSourceDateWarning>(
        validate(createdRule, files, _now),
      ).toList();
      expect(missing.map((w) => w.file.name), ['unknown.txt']);
    });

    test('日時部分が空になり生成後ベース名も空なら空名警告も併発する', () {
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]);
      final warnings = validate(rule, [unknownCreated('x.txt')], _now);
      expect(_of<MissingSourceDateWarning>(warnings).length, 1);
      expect(_of<EmptyNameWarning>(warnings).length, 1);
    });
  });

  group('OP-003: 該当が無ければ警告なし / 複数条件の同時検出', () {
    test('健全なルール -> 警告ゼロ', () {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('_v2')]);
      final files = [_file('a.jpg'), _file('b.jpg')];
      expect(validate(rule, files, _now), isEmpty);
    });

    test('空リテラルで全選択が同名 -> 各ファイルに重複と空名の両方', () {
      const rule = RenameRule([LiteralToken('')]);
      final files = [_file('a.jpg'), _file('b.jpg')];
      final warnings = validate(rule, files, _now);
      expect(_of<DuplicateWarning>(warnings).length, 2);
      expect(_of<EmptyNameWarning>(warnings).length, 2);
    });
  });
}
