import 'dart:async';
import 'dart:collection';

import '../../core/file_entry.dart';
import 'file_preview.dart';

/// 別の [FilePreviewPort] へ cache と同時実行の上限を被せる(008:T07)。
///
/// `T13` が「先に決めること」として挙げていた**数百件あるときのメモリと速度**を
/// ここで閉じる。行 widget は見えている分しか build されない(遅延読み込みは
/// `ListView.builder` が既に持つ)が、それでも次の3つが要る。
///
/// - **同じ file を何度も読まない。** scroll で行が作り直されるたびに decode すると、
///   同じ絵を何度も作ることになる。
/// - **保持量に上限を持つ。** folder に数千件あっても、cache は [maxEntries] 件で
///   止まる(古いものから捨てる LRU)。
/// - **同時に走る数を絞る。** 速く scroll すると数百件が一度に走りうる。
///   [maxConcurrent] 件までに抑え、残りは順番を待つ。
///
/// **失敗も cache する。** 読めない file は次に見えたときも読めない見込みが高く、
/// scroll のたびに再試行すると、いちばん遅い file をいちばん多く叩くことになる。
class CachedFilePreview implements FilePreviewPort {
  CachedFilePreview(this.inner, {this.maxEntries = 256, this.maxConcurrent = 4})
    : assert(maxEntries > 0),
      assert(maxConcurrent > 0);

  final FilePreviewPort inner;

  /// 保持する件数の上限。超えたら**最も長く使われていないもの**から捨てる。
  final int maxEntries;

  /// 同時に [inner] を走らせる数の上限。
  final int maxConcurrent;

  /// 挿入順を保つ Map を LRU として使う(参照のたび末尾へ入れ直す)。
  /// Dart の Map literal は [LinkedHashMap] なので挿入順が保たれる。
  final _entries = <String, PreviewResult>{};

  /// 進行中の要求。同じ鍵の要求が重なっても [inner] は1回しか呼ばない。
  final _inFlight = <String, Future<PreviewResult>>{};

  int _running = 0;
  final _waiting = Queue<Completer<void>>();

  /// cache の現在の件数(検査用)。
  int get entryCount => _entries.length;

  /// cache の鍵。
  ///
  /// **更新日時を含める。** 同じ path の file が差し替わったとき、古い絵を出し
  /// 続けないためである。**長辺も含める** — 別の大きさで要求されたら作り直す。
  static String keyOf(FileEntry entry, int maxEdge) =>
      '${entry.sourceHandle}|${entry.modifiedAt.microsecondsSinceEpoch}|$maxEdge';

  @override
  Future<PreviewResult> thumbnail(FileEntry entry, {required int maxEdge}) {
    final key = keyOf(entry, maxEdge);
    final cached = _entries.remove(key);
    if (cached != null) {
      // 参照したので末尾へ戻す(LRU)。
      _entries[key] = cached;
      return Future.value(cached);
    }
    final running = _inFlight[key];
    if (running != null) return running;

    final future = _run(entry, maxEdge: maxEdge, key: key);
    _inFlight[key] = future;
    return future;
  }

  Future<PreviewResult> _run(
    FileEntry entry, {
    required int maxEdge,
    required String key,
  }) async {
    await _acquire();
    try {
      final result = await inner.thumbnail(entry, maxEdge: maxEdge);
      _store(key, result);
      return result;
    } finally {
      _inFlight.remove(key);
      _release();
    }
  }

  void _store(String key, PreviewResult result) {
    _entries[key] = result;
    while (_entries.length > maxEntries) {
      // LinkedHashMap の先頭が最も長く使われていない鍵。
      _entries.remove(_entries.keys.first);
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waiting.isEmpty) {
      _running--;
      return;
    }
    // 走っている数は変えず、待っている次の要求へ席を渡す。
    _waiting.removeFirst().complete();
  }
}
