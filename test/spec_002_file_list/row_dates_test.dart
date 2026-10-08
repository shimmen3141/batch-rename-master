// 008:T61 行の補足情報に出す日時を決める(002 REQ-013。`008:T60` で更新)。
//
// 日時を**使っている** = 並び順がその日時、またはルールがその日時を基準にする
// 日時トークンを持つ。現在日時のトークンは数えない。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/row_dates.dart';
import 'package:flutter_test/flutter_test.dart';

const _created = DateTimeToken(source: DateTimeSource.created, format: 'YYYY');
const _modified = DateTimeToken(
  source: DateTimeSource.modified,
  format: 'YYYY',
);
const _current = DateTimeToken(source: DateTimeSource.current, format: 'YYYY');

void main() {
  test('並び順もルールも日時を使わなければ none(名前・大きさ・手動の並び)', () {
    for (final mode in [
      FileSortMode.name,
      FileSortMode.size,
      FileSortMode.custom,
    ]) {
      final use = rowDateUseOf(mode, const RenameRule([LiteralToken('x')]));
      expect(use.none, isTrue, reason: '$mode');
    }
  });

  test('並び順だけで決まる', () {
    final created = rowDateUseOf(FileSortMode.createdAt, RenameRule.empty);
    expect((created.created, created.modified), (true, false));
    final modified = rowDateUseOf(FileSortMode.modifiedAt, RenameRule.empty);
    expect((modified.created, modified.modified), (false, true));
  });

  test('ルールの日時トークンだけで決まる', () {
    final created = rowDateUseOf(
      FileSortMode.name,
      const RenameRule([LiteralToken('a'), _created]),
    );
    expect((created.created, created.modified), (true, false));
    final modified = rowDateUseOf(
      FileSortMode.name,
      const RenameRule([_modified]),
    );
    expect((modified.created, modified.modified), (false, true));
  });

  test('並び順とルールを合わせる(両方)', () {
    final use = rowDateUseOf(
      FileSortMode.createdAt,
      const RenameRule([_modified]),
    );
    expect((use.created, use.modified), (true, true));
  });

  test('現在日時のトークンは数えない', () {
    final use = rowDateUseOf(FileSortMode.name, const RenameRule([_current]));
    expect(use.none, isTrue);
  });
}
