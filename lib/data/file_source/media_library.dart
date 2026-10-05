import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// 写真・動画の選択画面に並ぶ1件の種類(004 REQ-022)。
enum MediaKind { photo, video }

/// 種類の絞り込み(004 REQ-022: すべて・写真・動画)。
enum MediaKindFilter { all, photos, videos }

/// MediaStore に載っている写真・動画の1件(004 REQ-022)。
class MediaItem {
  const MediaItem({
    required this.id,
    required this.path,
    required this.kind,
    this.taken,
    this.added,
    this.modified,
    this.content,
    this.duration,
    this.albumId,
  });

  /// MediaStore の行の id。サムネイルを引くのに使う。
  final int id;

  /// ファイルの絶対 path。読み込みはこの path で行う(004 REQ-002)。
  final String path;

  final MediaKind kind;

  /// `DATE_TAKEN`。端末の時刻帯の [DateTime]。無ければ `null`。
  final DateTime? taken;

  /// `DATE_ADDED`。端末の時刻帯の [DateTime]。無ければ `null`。
  final DateTime? added;

  /// `DATE_MODIFIED`。中身の日時を覚えておくときの鍵に使う(中身が変われば変わる)。
  final DateTime? modified;

  /// ファイルの中身の日時(004 REQ-010 の①)。**`DATE_TAKEN` が無い item だけ**読んで
  /// 入れる(REQ-022。[withContent])。読んでいない・取れなければ `null`。
  final DateTime? content;

  /// 動画の再生時間。写真・記録の無い動画は `null`。
  final Duration? duration;

  /// 属するアルバム(MediaStore のバケット)の id。無ければ `null`。
  final int? albumId;

  /// 並び順と見出しの日付(004 REQ-022: `DATE_TAKEN`、無ければ中身の日時、それも
  /// 無ければ `DATE_ADDED`)。
  ///
  /// `DATE_TAKEN` が無い item では、読み込んだ後の作成日時(REQ-010)と同じになる。
  DateTime? get date => taken ?? content ?? added;

  /// 中身の日時を入れた写し。
  MediaItem withContent(DateTime? content) => MediaItem(
    id: id,
    path: path,
    kind: kind,
    taken: taken,
    added: added,
    modified: modified,
    content: content,
    duration: duration,
    albumId: albumId,
  );
}

/// アルバム(写真・動画のある folder の1つ。MediaStore のバケット)。
class MediaAlbum {
  const MediaAlbum({
    required this.id,
    required this.name,
    required this.count,
    required this.folder,
    this.cover,
  });

  final int id;

  /// 利用者へ見せる名前(`BUCKET_DISPLAY_NAME`、無ければ folder の名前)。
  final String name;

  /// このアルバムの写真・動画の件数(種類で絞らない数)。
  final int count;

  /// このアルバムの folder の絶対 path(場所)。
  final String folder;

  /// 代表の item(いちばん新しいもの)。
  final MediaItem? cover;
}

/// 一覧の絞り込み(004 REQ-022: 種類とアルバム)。
class MediaFilter {
  const MediaFilter({this.kind = MediaKindFilter.all, this.albumId});

  final MediaKindFilter kind;

  /// `null` は「すべてのアルバム」。
  final int? albumId;

  /// [item] がこの絞り込みで並ぶか。
  bool matches(MediaItem item) =>
      (albumId == null || item.albumId == albumId) &&
      switch (kind) {
        MediaKindFilter.all => true,
        MediaKindFilter.photos => item.kind == MediaKind.photo,
        MediaKindFilter.videos => item.kind == MediaKind.video,
      };
}

/// [MediaLibraryPort.list] の結果。
///
/// **「取れなかった」と「1件も無い」を型で区別する。** 空の一覧へ落とすと、
/// 照会に失敗したときに「写真・動画が無い」と見せてしまう(004 REQ-022 は
/// 無いときに無いことを示す)。
sealed class MediaListResult {
  const MediaListResult();
}

/// 取れた。**空でも「取れた」である。**
class MediaListed extends MediaListResult {
  const MediaListed(this.items);

  /// 並びは決めていない。並べるのは [sortedByDate]。
  final List<MediaItem> items;
}

/// 取れなかった。**空の [MediaListed] と混同しない。**
class MediaListFailed extends MediaListResult {
  const MediaListFailed(this.reason);

  /// 利用者と開発者の両方が読める理由。
  final String reason;
}

/// [items] を並び順(004 REQ-022)に並べる: [MediaItem.date] の新しい順、日時の無い
/// ものは最後、同じ日時は id の大きい順(並びが揺れないように)。
List<MediaItem> sortedByDate(Iterable<MediaItem> items) {
  final sorted = items.toList();
  sorted.sort((a, b) {
    final x = a.date;
    final y = b.date;
    if (x != y) {
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    }
    return b.id.compareTo(a.id);
  });
  return sorted;
}

/// [MediaLibraryPort.albums] の結果。[MediaListResult] と同じ区別を持つ。
sealed class MediaAlbumsResult {
  const MediaAlbumsResult();
}

class MediaAlbumsListed extends MediaAlbumsResult {
  const MediaAlbumsListed(this.albums);

  /// いちばん新しい item が新しい順。
  final List<MediaAlbum> albums;
}

class MediaAlbumsFailed extends MediaAlbumsResult {
  const MediaAlbumsFailed(this.reason);

  final String reason;
}

/// 端末の写真・動画とアルバムを MediaStore から供給する port(004 REQ-022)。
///
/// **並ぶのは MediaStore に載っていて、この app から見えるものだけ**である。
/// `adb push` など shell が置いた file は載っていても見えない(`010:T03`)。
/// ゴミ箱に入ったもの・保存途中のものは含まない。
abstract interface class MediaLibraryPort {
  /// 写真・動画の全件。絞り込みと並べ替えは app の側で行う — 並び順に中身の日時が
  /// 要る(REQ-022)ので、MediaStore には並べさせられない(`010:T11`)。
  Future<MediaListResult> list();

  /// アルバムの一覧。
  Future<MediaAlbumsResult> albums();

  /// [item] のサムネイル(JPEG)。長辺は [maxEdge] 前後。作れなければ `null`。
  Future<Uint8List?> thumbnail(MediaItem item, {required int maxEdge});
}

/// Android の MediaStore を platform channel 越しに引く。
///
/// **この class は Linux 上の test で Kotlin 側まで実行できない。** channel を
/// 差し替えて Dart 側の写像を確かめ、Kotlin 側の照会そのものは端末の確認
/// (`010:T07` の manual)が引き受ける。`MethodChannelMediaDates` と同じ形である。
class MethodChannelMediaLibrary implements MediaLibraryPort {
  const MethodChannelMediaLibrary();

  /// channel 名。Kotlin 側(`MainActivity.kt`)と一致させる。
  static const channel = MethodChannel(
    'com.example.batch_rename_master/media_library',
  );

  /// **失敗を握りつぶさない。** channel が無い・Kotlin 側が失敗した・想定外の
  /// 値が返った、はどれも [MediaListFailed] である。
  ///
  /// 形の崩れた行(id・path・種類が無い)は落とす。並べても読み込めない。
  @override
  Future<MediaListResult> list() async {
    final List<Object?>? raw;
    try {
      raw = await channel.invokeMethod<List<Object?>>('list');
    } catch (error) {
      return MediaListFailed('写真・動画を取得できませんでした: $error');
    }
    if (raw == null) {
      return const MediaListFailed('写真・動画を取得できませんでした: 応答がありません');
    }
    return MediaListed([for (final row in raw) ?_itemOf(row)]);
  }

  @override
  Future<MediaAlbumsResult> albums() async {
    final List<Object?>? raw;
    try {
      raw = await channel.invokeMethod<List<Object?>>('albums');
    } catch (error) {
      return MediaAlbumsFailed('アルバムを取得できませんでした: $error');
    }
    if (raw == null) {
      return const MediaAlbumsFailed('アルバムを取得できませんでした: 応答がありません');
    }
    final albums = <MediaAlbum>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = row['id'];
      final folder = row['folder'];
      final count = row['count'];
      if (id is! int || folder is! String || folder.isEmpty || count is! int) {
        continue;
      }
      final name = row['name'];
      albums.add(
        MediaAlbum(
          id: id,
          name: name is String && name.isNotEmpty ? name : p.basename(folder),
          count: count,
          folder: folder,
          cover: _itemOf(row['cover']),
        ),
      );
    }
    return MediaAlbumsListed(albums);
  }

  /// 作れなかったときは `null`。サムネイルが無いだけで、選ぶことはできる。
  @override
  Future<Uint8List?> thumbnail(MediaItem item, {required int maxEdge}) async {
    try {
      return await channel.invokeMethod<Uint8List>('thumbnail', {
        'id': item.id,
        'kind': item.kind.name,
        'maxEdge': maxEdge,
      });
    } catch (error) {
      debugPrint('media_library: thumbnail failed: $error');
      return null;
    }
  }

  /// 値は UTC の時刻(`DATE_TAKEN` はミリ秒、`DATE_ADDED`・`DATE_MODIFIED` は秒、
  /// `DURATION` はミリ秒)で届く。日時は**端末の時刻帯へ直す**(004 REQ-022)。
  static MediaItem? _itemOf(Object? row) {
    if (row is! Map) return null;
    final id = row['id'];
    final path = row['path'];
    final kind = switch (row['kind']) {
      'photo' => MediaKind.photo,
      'video' => MediaKind.video,
      _ => null,
    };
    if (id is! int || path is! String || path.isEmpty || kind == null) {
      return null;
    }
    final taken = _positive(row['taken']);
    final added = _positive(row['added']);
    final modified = _positive(row['modified']);
    final duration = _positive(row['duration']);
    final albumId = row['albumId'];
    return MediaItem(
      id: id,
      path: path,
      kind: kind,
      taken: taken == null ? null : DateTime.fromMillisecondsSinceEpoch(taken),
      added: added == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(added * 1000),
      modified: modified == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modified * 1000),
      duration: kind == MediaKind.video && duration != null
          ? Duration(milliseconds: duration)
          : null,
      albumId: albumId is int ? albumId : null,
    );
  }

  /// 0 以下は「記録していない」として扱う。
  static int? _positive(Object? value) =>
      value is int && value > 0 ? value : null;
}
