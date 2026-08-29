import 'dart:async';
import 'dart:typed_data';

import '../../core/file_entry.dart';

/// 行に出す preview の結果(008:T07)。
///
/// **「preview が無い」と「読めなかった」を型で分ける。** 潰すと、読めない file が
/// 「preview の無い普通の file」に見える。004 の [NameListResult](列挙できない /
/// 空)と `013:T12` の `StorageVolumesResult` が採ったのと同じ形である。
sealed class PreviewResult {
  const PreviewResult();
}

/// thumbnail を作れた。
class PreviewReady extends PreviewResult {
  const PreviewReady(this.thumbnail);

  /// 縮小済みの PNG バイト列。**元 file のバイト列ではない** — 行に出す大きさまで
  /// 落としてから返すので、大きな画像でも保持量は上限で決まる。
  final Uint8List thumbnail;
}

/// この file に preview は無い。**失敗ではない。**
///
/// 文書・書庫・不明な拡張子、そして**元場所ハンドルが filesystem path でない**場合
/// (SAF の document URI。`013 ADR-002` の退避経路)がここに入る。行は種別アイコンを
/// 出す。
class PreviewUnsupported extends PreviewResult {
  const PreviewUnsupported(this.reason);

  /// 開発者向けの理由。利用者へは出さない(行は静かにアイコンへ落ちる)。
  final String reason;
}

/// preview を作ろうとして失敗した。
///
/// 権限、IO、壊れた file、decode 不能など。**[PreviewUnsupported] へ潰さない。**
class PreviewFailed extends PreviewResult {
  const PreviewFailed(this.message);

  /// 開発者向けの理由。
  final String message;
}

/// preview を作れる可能性のある種別(008:T07)。
///
/// **拡張子から決める表示専用の分類である。** 読み込み対象の絞り込み(004 REQ-011 の
/// 種類)にも、改名の判定にも使わない — 004 の決定 D-2「実装が返したものをそのまま
/// 扱う」を曲げないこと。ここで種別を推測して読み込む file を変えてはならない。
enum PreviewKind {
  /// 画像。Dart の decode で thumbnail を作れる(両 platform)。
  image,

  /// 動画。platform 側の thumbnail 生成が要る。
  video,

  /// preview を出さない種別。
  other,
}

/// 拡張子から [PreviewKind] を決める。
///
/// 大文字小文字を区別しない。**判定できないものは [PreviewKind.other]** で、
/// 迷ったら preview を出さない側へ倒す。中身を読んで種別を推測しない
/// (読んでから「違った」と分かるのは、避けたい方のコストである)。
PreviewKind previewKindOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return PreviewKind.other;
  final extension = fileName.substring(dot + 1).toLowerCase();
  if (_imageExtensions.contains(extension)) return PreviewKind.image;
  if (_videoExtensions.contains(extension)) return PreviewKind.video;
  return PreviewKind.other;
}

/// Flutter の decoder が扱える一般的な画像拡張子。
///
/// **`heic` を入れていない。** Android では decode できるが Windows では
/// できず、「対応している」と書くと片方で必ず [PreviewFailed] になる。
/// 出せる platform で出すなら、そこだけ platform 側の thumbnail を通す形で
/// 後から足す(このtaskの範囲外)。
const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

/// 一般的な動画コンテナ。**実際に frame を取り出せるかは実装が返す。**
const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'mkv', 'webm', 'avi'};

/// 行の preview を供給する port。
///
/// **実 file を触る側を UI から分ける。** `013:T07` の `StorageBrowserPort` と同じ形で、
/// widget test が実機に依存しなくなる。
///
/// **例外を投げない。** 失敗は [PreviewFailed] で返す(004 の `FileSource` と同じ約束)。
abstract interface class FilePreviewPort {
  /// [entry] の thumbnail を作る。長辺を [maxEdge] px 以下に収める。
  Future<PreviewResult> thumbnail(FileEntry entry, {required int maxEdge});
}

/// あらかじめ与えた結果を返す [FilePreviewPort](test 用の fake)。
class FakeFilePreview implements FilePreviewPort {
  FakeFilePreview({
    Map<String, PreviewResult>? byHandle,
    this.fallback = const PreviewUnsupported('fake: 既定'),
  }) : byHandle = byHandle ?? {};

  /// 元場所ハンドル → 返す結果。
  final Map<String, PreviewResult> byHandle;

  /// [byHandle] に無いハンドルへ返す結果。
  final PreviewResult fallback;

  /// [thumbnail] が呼ばれたハンドル(呼ばれた順)。**重複を含む** — cache が効いて
  /// いれば同じハンドルは1回しか現れない。
  final List<String> requested = [];

  /// 応答を保留する。`true` の間 [thumbnail] は完了しない(同時実行数の検査用)。
  bool hold = false;
  final List<(FileEntry, Completer<PreviewResult>)> _pending = [];

  /// 保留していた応答をすべて返す。
  ///
  /// **要求された entry ごとの結果を返す。** 一律 [fallback] にすると、
  /// 「古い要求の応答が、後から別の行へ届く」ような検査が書けない。
  void release() {
    hold = false;
    for (final (entry, completer) in _pending) {
      completer.complete(_resultFor(entry));
    }
    _pending.clear();
  }

  PreviewResult _resultFor(FileEntry entry) =>
      byHandle[entry.sourceHandle] ?? fallback;

  @override
  Future<PreviewResult> thumbnail(
    FileEntry entry, {
    required int maxEdge,
  }) async {
    requested.add(entry.sourceHandle ?? '(handleなし)');
    if (hold) {
      final completer = Completer<PreviewResult>();
      _pending.add((entry, completer));
      return completer.future;
    }
    return _resultFor(entry);
  }
}
