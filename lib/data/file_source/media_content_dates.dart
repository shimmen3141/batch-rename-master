import 'dart:isolate';

import 'content_created_at.dart';
import 'media_library.dart';

/// 写真・動画の中身の日時(004 REQ-010 の①)を読む port(REQ-022。`010:T11`)。
///
/// 選択画面の並び順と見出しの日付を、`DATE_TAKEN` が無い item について読み込んだ
/// 後の作成日時と同じにするために使う。
abstract interface class MediaContentDatesPort {
  /// [items] の中身の日時。**取れなかった item は結果に含めない。**
  ///
  /// 例外を投げない。読めないファイルは「①が無い」である(REQ-010)。
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items);
}

/// 中身を別の isolate で読む。
///
/// ファイルを開いて先頭を読むので、件数が多いと UI の thread を止める。読むのは
/// 日時が書かれた部分だけで、形式が違えば先頭 12 バイトで諦める(`T02`)。
class IsolateMediaContentDates implements MediaContentDatesPort {
  const IsolateMediaContentDates();

  @override
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items) async {
    if (items.isEmpty) return const {};
    final targets = [for (final item in items) (item.id, item.path)];
    try {
      return await Isolate.run(() => _read(targets));
    } catch (_) {
      // isolate を起こせなくても選択画面は開く。中身の日時が無いだけになる。
      return const {};
    }
  }

  static Map<int, DateTime> _read(List<(int, String)> targets) => {
    for (final (id, path) in targets) id: ?readContentCreatedAt(path),
  };
}

/// 読んだ結果を覚えておく(app が生きている間)。
///
/// **鍵は path と `DATE_MODIFIED`。** 中身が変わると `DATE_MODIFIED` が変わり、
/// 改名すると path が変わるので、古い結果を使わない。取れなかったことも覚える —
/// 開くたびにスクリーンショットを読み直さないためである。
class CachedMediaContentDates implements MediaContentDatesPort {
  CachedMediaContentDates(this._source);

  final MediaContentDatesPort _source;
  final Map<(String, DateTime?), DateTime?> _cache = {};

  @override
  Future<Map<int, DateTime>> datesOf(List<MediaItem> items) async {
    final missing = [
      for (final item in items)
        if (!_cache.containsKey(_keyOf(item))) item,
    ];
    if (missing.isNotEmpty) {
      final read = await _source.datesOf(missing);
      for (final item in missing) {
        _cache[_keyOf(item)] = read[item.id];
      }
    }
    return {for (final item in items) item.id: ?_cache[_keyOf(item)]};
  }

  static (String, DateTime?) _keyOf(MediaItem item) =>
      (item.path, item.modified);
}

/// [items] のうち **`DATE_TAKEN` が無いものだけ**中身の日時を読んで入れ、並び順
/// (REQ-022)に並べる。
///
/// `DATE_TAKEN` がある item の中身は読まない(全件を読むと開くのが遅くなる。
/// 2026-10-05 開発者の決定)。port が投げても、中身の日時が無いものとして並べる。
Future<List<MediaItem>> withDisplayDates(
  List<MediaItem> items,
  MediaContentDatesPort contentDates,
) async {
  final untaken = [
    for (final item in items)
      if (item.taken == null) item,
  ];
  Map<int, DateTime> dates;
  try {
    dates = await contentDates.datesOf(untaken);
  } catch (_) {
    dates = const {};
  }
  return sortedByDate([
    for (final item in items)
      // `DATE_TAKEN` がある item には入れない(port が余計に返しても)。
      if (dates[item.id] case final date? when item.taken == null)
        item.withContent(date)
      else
        item,
  ]);
}
