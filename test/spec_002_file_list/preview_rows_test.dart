// VER-001(続き): 行データ(プレビュー連携)の検証(FEAT-002 / Light)。
// 対象: REQ-005(setRule が行データに反映), REQ-006(items 順・選択行の変更後名が
//       generatePreview に一致), REQ-007(未選択行は変更後名を持たない),
//       REQ-015(行データが、その item を対象とする警告を持つ)。
//
// **REQ-015 の unit 検証はここにある。** 008:T16 の独立review attempt 4 が
// 「spec の VER-001 は `test/spec_002_file_list/` を指しているのに、そこに
// `warnings` を見る assertion が1つも無い」を指摘した(P2-3)。実際に押さえて
// いたのは `test/spec_005_rename_exec/warning_display_test.dart` で、要求自体は
// 守られていたが、**宣言した場所に実体が無かった。**widget 層を経由せずに
// 行データそのものを見る形をここへ置く。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {DateTime? created}) => FileEntry(
  name: name,
  createdAt: created ?? DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
);

const _seq2 = RenameRule([SequenceToken(start: 1, digits: 2)]);

List<String?> _newNames(FileListController c) =>
    c.rows.map((r) => r.newName).toList();

void main() {
  group('REQ-006: 行データは items 順・選択行は generatePreview に一致', () {
    test('rows は items と同じ順・件数で、currentName は name に等しい', () {
      final files = [_f('b.txt'), _f('a.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      expect(c.rows.map((r) => r.currentName).toList(), [
        'b.txt',
        'a.txt',
        'c.txt',
      ]);
      expect(c.rows.length, files.length);
    });

    test('選択行の変更後名は表示順の連番割り当て(generatePreview と一致)', () {
      final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      expect(_newNames(c), ['01.txt', '02.txt', '03.txt']);
      // 参照実装(generatePreview)と一致することを直接照合。
      final ref = generatePreview(
        _seq2,
        files, // 全選択(FileEntry.selected 既定 true)
        DateTime(2026, 1, 1),
      ).map((e) => e.resultName).toList();
      expect(ref, ['01.txt', '02.txt', '03.txt']);
    });

    test('reorder すると連番は新しい表示順で振り直される', () {
      final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.reorder(2, 0); // c を先頭へ -> [c, a, b]
      expect(c.rows.map((r) => r.currentName).toList(), [
        'c.txt',
        'a.txt',
        'b.txt',
      ]);
      expect(_newNames(c), ['01.txt', '02.txt', '03.txt']);
    });

    test('setRule でルールを差し替えると行データに反映される(REQ-005)', () {
      final files = [_f('photo.jpg')];
      final c = FileListController(files: files);
      // 既定(空ルール)は元名のみ相当 -> ベース名なしで拡張子のみ… ではなく空。
      expect(c.rows.single.newName, '.jpg');
      c.setRule(const RenameRule([OriginalNameToken()]));
      expect(c.rows.single.newName, 'photo.jpg');
    });

    test('現在日時トークンは注入した clock を用いる', () {
      final files = [_f('a.txt')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([
          DateTimeToken(source: DateTimeSource.current, format: 'YYYY'),
        ]),
        clock: () => DateTime(2030, 5, 6),
      );
      expect(c.rows.single.newName, '2030.txt');
    });
  });

  group('REQ-007: 未選択行は変更後名を持たない', () {
    test('中間の未選択行は newName=null、選択行のみ連番', () {
      final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.toggleSelection(files[1]); // b を未選択
      final rows = c.rows;
      expect(rows[1].newName, isNull);
      expect(rows[1].hasNewName, isFalse);
      // 選択行 a, c は表示順で 01, 02。
      expect(rows[0].newName, '01.txt');
      expect(rows[2].newName, '02.txt');
    });

    test('全解除ならすべて newName=null', () {
      final files = [_f('a.txt'), _f('b.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.clearAll();
      expect(c.rows.every((r) => r.newName == null), isTrue);
    });

    test('空 files では rows も空', () {
      final c = FileListController(files: const [], rule: _seq2);
      expect(c.rows, isEmpty);
    });

    test('rows の selected は選択状態を反映する', () {
      final files = [_f('a'), _f('b')];
      final c = FileListController(files: files, rule: _seq2);
      c.toggleSelection(files[0]);
      final rows = c.rows;
      expect(rows[0].selected, isFalse);
      expect(rows[1].selected, isTrue);
    });
  });

  group('反映: ソートも行データに反映される', () {
    test('name ソート後は rows も並び替わる', () {
      final files = [_f('b.txt'), _f('a.txt')];
      final c = FileListController(files: files, rule: _seq2);
      c.setSortMode(FileSortMode.name);
      expect(c.rows.map((r) => r.currentName).toList(), ['a.txt', 'b.txt']);
    });
  });

  group('REQ-015: 行データが、その item を対象とする警告を持つ', () {
    test('例18: 変更後名が重複する item は、重複警告を重複名とともに持つ', () {
      // 同じ固定文字だけのルール → 2 件とも同じ名前になる。
      final files = [_f('alpha.txt'), _f('bravo.txt')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([LiteralToken('same')]),
      );

      for (final row in c.rows) {
        final duplicate = row.warnings.whereType<DuplicateWarning>().single;
        // 001 が持たせている識別情報(重複する変更後名)まで供給する。
        expect(duplicate.resultName, 'same.txt');
        expect(duplicate.file.name, row.currentName);
      }
    });

    test('例19: 桁不足はどの行データにも入らない(対象ファイルを持たない)', () {
      // 開始 100・1 桁なので 1 件でも 3 桁必要になる。
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([SequenceToken(start: 100, digits: 1)]),
      );

      // 判定としては出ている。**行データへ載せないだけである。**
      expect(c.warnings.whereType<DigitShortageWarning>(), isNotEmpty);
      for (final row in c.rows) {
        expect(row.warnings.whereType<DigitShortageWarning>(), isEmpty);
        expect(row.warnings, isEmpty);
      }
    });

    test('例20: 該当しない item の行データは警告を空で持つ', () {
      final c = FileListController(
        files: [_f('alpha.txt'), _f('bravo.txt')],
        rule: const RenameRule([OriginalNameToken()]),
      );

      expect(c.warnings, isEmpty);
      for (final row in c.rows) {
        expect(row.warnings, isEmpty);
      }
    });

    test('例21: 作成日時が不明な item だけが基準日時不明を持つ', () {
      // 元名トークンがあるので名前は空にならない。**影響は受けている。**
      final known = _f('dated.jpg');
      final unknown = FileEntry(
        name: 'nodate.jpg',
        modifiedAt: DateTime(2026, 1, 1),
        size: 0,
      );
      final c = FileListController(
        files: [known, unknown],
        rule: const RenameRule([
          OriginalNameToken(),
          DateTimeToken(source: DateTimeSource.created, format: 'yyyyMMdd'),
        ]),
      );

      final rows = {for (final row in c.rows) row.currentName: row};
      expect(rows['dated.jpg']!.warnings, isEmpty);
      final missing = rows['nodate.jpg']!.warnings
          .whereType<MissingSourceDateWarning>()
          .single;
      // 001 が持たせている識別情報(空になるトークンの位置)まで供給する。
      expect(missing.tokenIndex, 1);
      expect(missing.file.name, 'nodate.jpg');
    });

    test('選択を外すと、その item の行データからも警告が消える', () {
      final files = [_f('alpha.txt'), _f('bravo.txt')];
      final c = FileListController(
        files: files,
        rule: const RenameRule([LiteralToken('same')]),
      );
      c.toggleSelection(c.rows.first.source);

      // **`validate` は選択を写した複製しか見ない。** 選択を外した行は改名の
      // 対象にならないので、001 の判定からも外れる。したがって「未選択でも
      // 自分の警告を持つ」という性質は**原理的に成立しえず、検査もできない**
      // (独立review attempt 5 のP2-1。testの名前が中身と食い違っていた)。
      final unselected = c.rows.firstWhere((row) => !row.selected);
      expect(unselected.warnings, isEmpty);
      final selected = c.rows.firstWhere((row) => row.selected);
      expect(selected.warnings, isEmpty, reason: '1 件だけなら重複しない');
    });
  });
}
