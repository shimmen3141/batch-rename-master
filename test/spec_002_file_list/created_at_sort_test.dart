// VER-001(T6): 時系列ソート2種と作成日時不明の扱い(FEAT-002 / Light)。
// 対象: REQ-002(作成日時ソートは不明を更新日時で代替・更新日時ソート),
//       REQ-011(不明件数の警告), REQ-012(不明を含んでも失敗しない),
//       REQ-013(行データが両日時 + 不明かを供給)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:flutter_test/flutter_test.dart';

/// 作成日時が判明しているファイル。
FileEntry _known(String name, DateTime created, {DateTime? modified}) =>
    FileEntry(
      name: name,
      createdAt: created,
      modifiedAt: modified ?? DateTime(2026, 1, 1),
      size: 0,
    );

/// 作成日時が不明なファイル(更新日時のみ判明)。
FileEntry _unknown(String name, DateTime modified) =>
    FileEntry(name: name, modifiedAt: modified, size: 0);

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

void main() {
  group('REQ-002: 作成日時ソートは不明を更新日時で代替する', () {
    test('例8: [b=2024, a=2023, c=不明(更新2022)] -> [c, a, b]', () {
      final c = FileListController(
        files: [
          _known('b', DateTime(2024)),
          _known('a', DateTime(2023)),
          _unknown('c', DateTime(2022)),
        ],
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(_names(c), ['c', 'a', 'b']);
    });

    test('代替キーは当該 item の更新日時(固定値・現在時刻ではない)', () {
      // 不明な2件は互いの更新日時の順に並ぶ。固定値で代替すると入力順のままになる。
      final c = FileListController(
        files: [
          _unknown('late', DateTime(2030)),
          _unknown('early', DateTime(1990)),
        ],
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(_names(c), ['early', 'late']);
    });

    test('createdAtSortKey: 判明していればその値、不明なら更新日時', () {
      final known = _known('k', DateTime(2023), modified: DateTime(2025));
      final unknown = _unknown('u', DateTime(2022));
      expect(createdAtSortKey(known), DateTime(2023));
      expect(createdAtSortKey(unknown), DateTime(2022));
    });

    test('代替は並べ替えキーのみ。FileEntry.createdAt は書き換えない', () {
      final c = FileListController(files: [_unknown('c', DateTime(2022))]);

      c.setSortMode(FileSortMode.createdAt);

      expect(c.items.single.createdAt, isNull);
    });

    test('同値(代替後)は元の相対順を保つ(安定ソート)', () {
      final same = DateTime(2024, 5, 5);
      final c = FileListController(
        files: [
          _unknown('first', same),
          _known('second', same),
          _unknown('third', same),
        ],
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(_names(c), ['first', 'second', 'third']);
    });

    test('更新日時ソートは modifiedAt 昇順', () {
      final c = FileListController(
        files: [
          _known('b', DateTime(2020), modified: DateTime(2026, 3)),
          _known('a', DateTime(2021), modified: DateTime(2026, 1)),
        ],
      );

      c.setSortMode(FileSortMode.modifiedAt);

      expect(c.sortMode, FileSortMode.modifiedAt);
      expect(_names(c), ['a', 'b']);
    });

    test('例11↔12: 全件不明なら作成日時ソートと更新日時ソートの結果が一致する', () {
      List<FileEntry> files() => [
        _unknown('z', DateTime(2026, 3)),
        _unknown('a', DateTime(2026, 1)),
        _unknown('m', DateTime(2026, 2)),
      ];
      final byCreated = FileListController(files: files())
        ..setSortMode(FileSortMode.createdAt);
      final byModified = FileListController(files: files())
        ..setSortMode(FileSortMode.modifiedAt);

      expect(_names(byCreated), ['a', 'm', 'z']);
      expect(_names(byCreated), _names(byModified));
    });
  });

  group('REQ-011: 作成日時が不明な件数の警告', () {
    test('例9: 作成日時ソートで不明が1件 -> 件数を供給', () {
      final c = FileListController(
        files: [_known('a', DateTime(2023)), _unknown('c', DateTime(2022))],
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(c.unknownCreatedAtCount, 1);
      expect(c.createdAtSortWarning?.unknownCount, 1);
    });

    test('例10: 全件判明していれば警告を供給しない', () {
      final c = FileListController(
        files: [_known('a', DateTime(2023)), _known('b', DateTime(2024))],
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(c.unknownCreatedAtCount, 0);
      expect(c.createdAtSortWarning, isNull);
    });

    test('作成日時以外のソートでは供給しない(不明があっても)', () {
      final c = FileListController(files: [_unknown('c', DateTime(2022))]);

      for (final mode in [
        FileSortMode.name,
        FileSortMode.modifiedAt,
        FileSortMode.size,
        FileSortMode.custom,
      ]) {
        c.setSortMode(mode);
        expect(c.createdAtSortWarning, isNull, reason: '$mode');
      }
    });

    test('判定は取得可否で行う(拡張子・種別に依存しない)', () {
      // 画像でも作成日時が不明なら数える(スクショ等)。文書でも判明していれば数えない。
      final c = FileListController(
        files: [
          _unknown('screenshot.png', DateTime(2026, 1)),
          _known('memo.txt', DateTime(2023)),
          _unknown('report.pdf', DateTime(2026, 2)),
        ],
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(c.createdAtSortWarning?.unknownCount, 2);
    });

    test('作業セットの増減に追随する', () {
      final c = FileListController(files: const [])
        ..setSortMode(FileSortMode.createdAt);
      expect(c.createdAtSortWarning, isNull);

      c.setFiles([
        FileEntry(
          name: 'u.txt',
          modifiedAt: DateTime(2026, 1),
          size: 0,
          sourceHandle: 'h:u',
        ),
      ]);
      expect(c.createdAtSortWarning?.unknownCount, 1);

      c.removeFile('h:u');
      expect(c.createdAtSortWarning, isNull);
    });
  });

  group('REQ-012: 不明を含んでも失敗しない', () {
    test('全件不明でも作成日時ソート・プレビューが成立する', () {
      final c = FileListController(
        files: [
          _unknown('a.txt', DateTime(2026, 2)),
          _unknown('b.txt', DateTime(2026, 1)),
        ],
        rule: const RenameRule([
          LiteralToken('IMG_'),
          SequenceToken(start: 1, digits: 2, increment: 1),
        ]),
      );

      c.setSortMode(FileSortMode.createdAt);

      expect(_names(c), ['b.txt', 'a.txt']);
      expect(c.rows.map((r) => r.newName), ['IMG_01.txt', 'IMG_02.txt']);
      expect(c.createdAtSortWarning?.unknownCount, 2);
    });
  });

  group('REQ-013: 行データが両日時と不明かを供給する', () {
    test('作成日時が不明な行は createdAt が null・modifiedAt は実値', () {
      final c = FileListController(
        files: [_unknown('c.txt', DateTime(2026, 8, 4, 16))],
      );

      final row = c.rows.single;

      expect(row.source.createdAt, isNull);
      expect(row.source.modifiedAt, DateTime(2026, 8, 4, 16));
    });

    test('作成日時が判明している行は双方が実値', () {
      final c = FileListController(
        files: [
          _known('k.txt', DateTime(2023, 5, 6), modified: DateTime(2024, 7, 8)),
        ],
      );

      final row = c.rows.single;

      expect(row.source.createdAt, DateTime(2023, 5, 6));
      expect(row.source.modifiedAt, DateTime(2024, 7, 8));
    });
  });
}
