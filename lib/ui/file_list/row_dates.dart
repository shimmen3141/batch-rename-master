import '../../core/rename_engine.dart';
import 'file_sort.dart';

/// 行の補足情報に出す日時(002 REQ-013。`008:T61`)。
///
/// **並び順またはルールが使っている日時だけを出す**(2026-10-07 の開発者の決定 案A)。
/// 日時を**使っている**とは、`sortMode` がその日時であるか、ルールがその日時を基準に
/// する日時トークンを持つこと。現在日時のトークンは数えない。
class RowDateUse {
  const RowDateUse({required this.created, required this.modified});

  /// 作成日時を使っている。
  final bool created;

  /// 更新日時を使っている。
  final bool modified;

  /// どちらも使っていない。**更新日時を、どの日時かを示さずに出す**(app 内 browser
  /// の行と同じ。2026-10-07 の開発者の決定 ①)。
  bool get none => !created && !modified;
}

/// 一覧で1回だけ決める(行ごとにルールを走査しない)。
RowDateUse rowDateUseOf(FileSortMode sortMode, RenameRule rule) {
  final sources = {
    for (final token in rule.tokens)
      if (token is DateTimeToken) token.source,
  };
  return RowDateUse(
    created:
        sortMode == FileSortMode.createdAt ||
        sources.contains(DateTimeSource.created),
    modified:
        sortMode == FileSortMode.modifiedAt ||
        sources.contains(DateTimeSource.modified),
  );
}
