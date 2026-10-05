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

  /// 動画の再生時間。写真・記録の無い動画は `null`。
  final Duration? duration;

  /// 属するアルバム(MediaStore のバケット)の id。無ければ `null`。
  final int? albumId;

  /// 並び順と見出しの日付(004 REQ-022: `DATE_TAKEN`、無ければ `DATE_ADDED`)。
  ///
  /// **読み込んだ後の作成日時(REQ-010)とは別物である。** 中身の日時は読まない。
  DateTime? get date => taken ?? added;
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
}

/// [MediaLibraryPort.page] の結果。
///
/// **「取れなかった」と「1件も無い」を型で区別する。** 空の一覧へ落とすと、
/// 照会に失敗したときに「写真・動画が無い」と見せてしまう(004 REQ-022 は
/// 無いときに無いことを示す)。
sealed class MediaPageResult {
  const MediaPageResult();
}

/// 取れた。**空でも「取れた」である。**
class MediaPage extends MediaPageResult {
  const MediaPage(this.items, {required this.hasMore});

  /// 新しい順(`DATE_TAKEN`、無ければ `DATE_ADDED`)。
  final List<MediaItem> items;

  /// 続きがありうる。`false` ならこれで終わり。
  final bool hasMore;
}

/// 取れなかった。**空の [MediaPage] と混同しない。**
class MediaPageFailed extends MediaPageResult {
  const MediaPageFailed(this.reason);

  /// 利用者と開発者の両方が読める理由。
  final String reason;
}

/// [MediaLibraryPort.albums] の結果。[MediaPageResult] と同じ区別を持つ。
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
  /// [filter] で絞った一覧の、新しい順で [offset] 件目から最大 [limit] 件。
  Future<MediaPageResult> page(
    MediaFilter filter, {
    required int offset,
    required int limit,
  });

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
  /// 値が返った、はどれも [MediaPageFailed] である。
  ///
  /// 形の崩れた行(id・path・種類が無い)は落とす。並べても読み込めない。
  @override
  Future<MediaPageResult> page(
    MediaFilter filter, {
    required int offset,
    required int limit,
  }) async {
    final List<Object?>? raw;
    try {
      raw = await channel.invokeMethod<List<Object?>>('page', {
        'kind': filter.kind.name,
        'albumId': filter.albumId,
        'offset': offset,
        'limit': limit,
      });
    } catch (error) {
      return MediaPageFailed('写真・動画を取得できませんでした: $error');
    }
    if (raw == null) {
      return const MediaPageFailed('写真・動画を取得できませんでした: 応答がありません');
    }
    final items = [for (final row in raw) ?_itemOf(row)];
    // **落とした行も数える。** 数えないと、形の崩れた行があるだけで続きを
    // 取りに行かなくなる。
    return MediaPage(items, hasMore: raw.length >= limit);
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

  /// 値は UTC の時刻(`DATE_TAKEN` はミリ秒、`DATE_ADDED` は秒、`DURATION` は
  /// ミリ秒)で届く。日時は**端末の時刻帯へ直す**(004 REQ-022)。
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
