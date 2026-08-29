import 'dart:ui' as ui;

import '../../core/file_entry.dart';
import 'file_preview.dart';

/// [ui.ImmutableBuffer.fromFilePath] と同じ形で file を engine 側へ開く手続き。
typedef OpenImageBuffer = Future<ui.ImmutableBuffer> Function(String path);

/// 画像の thumbnail を Dart の decoder で作る(008:T07)。
///
/// **platform 判定を持たない。** 元場所ハンドルが filesystem path として開ければ
/// 動き、開けなければ結果値で返す。ADR-003 の「OS で劣化の要否を判定しない —
/// 実装が返す結果値で決める」に沿う。Android(013 以降は実 path)でも Windows でも
/// 同じ code が動く。
///
/// **decode 時点で縮小する。** [ui.ImageDescriptor.instantiateCodec] へ目標サイズを
/// 渡すので、元画像が何 MB でも保持するのは thumbnail の分だけである。file 全体を
/// Dart の heap へ読み込まない([ui.ImmutableBuffer.fromFilePath] が engine 側で
/// 開く)。
class ImageFilePreview implements FilePreviewPort {
  const ImageFilePreview({this.openBuffer = ui.ImmutableBuffer.fromFilePath});

  /// file を engine 側で開く手続き。
  ///
  /// **test が engine 側の資源解放を観測するための継ぎ目である。** 開いた buffer は
  /// 呼び出し側から見えないので、差し替えられないと「読めなかった file の buffer が
  /// 残る」を検査できない。production では既定のまま使う。
  final OpenImageBuffer openBuffer;

  @override
  Future<PreviewResult> thumbnail(
    FileEntry entry, {
    required int maxEdge,
  }) async {
    if (previewKindOf(entry.name) != PreviewKind.image) {
      return const PreviewUnsupported('画像ではない');
    }
    final path = filesystemPathOf(entry.sourceHandle);
    if (path == null) {
      return const PreviewUnsupported('元場所ハンドルが path ではない');
    }

    try {
      return await _decode(path, maxEdge);
    } catch (error) {
      // **握りつぶさない。** 読めなかったことと preview が無いことは別である。
      return PreviewFailed('$error');
    }
  }

  Future<PreviewResult> _decode(String path, int maxEdge) async {
    final descriptor = await _describe(path);
    ui.Codec? codec;
    ui.Image? image;
    try {
      final target = _targetSize(descriptor.width, descriptor.height, maxEdge);
      codec = await descriptor.instantiateCodec(
        targetWidth: target.width,
        targetHeight: target.height,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) {
        return const PreviewFailed('thumbnail を PNG へ書き出せませんでした');
      }
      return PreviewReady(encoded.buffer.asUint8List());
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor.dispose();
    }
  }

  /// file を開いて descriptor を作る。**buffer の解放をここで閉じる。**
  ///
  /// [ui.ImageDescriptor.encoded] が成功すれば中身は descriptor のものになり、
  /// 失敗すれば buffer は誰にも渡っていない。**どちらでも捨てるのが正しい**ので、
  /// 境界は `try/finally` ひとつで足りる(SDK の `instantiateImageCodecWithSize` も
  /// 同じことをしている)。
  ///
  /// その SDK helper を使わないのは、**成否を呼び出し側から判別できない**ためである。
  /// helper は成否に関わらず buffer を捨てるので、外側で「codec を作れたか」を見て
  /// 捨て分けると、目標サイズの計算が投げたときに**二重解放**になる。
  Future<ui.ImageDescriptor> _describe(String path) async {
    final buffer = await openBuffer(path);
    try {
      return await ui.ImageDescriptor.encoded(buffer);
    } finally {
      buffer.dispose();
    }
  }

  /// 長辺を [maxEdge] 以下に収める decode 先の大きさ。
  ///
  /// **投げない。** ここで例外を出すと buffer の持ち主が曖昧な地点で巻き戻ることに
  /// なるので、上限が 0 以下でも 1px へ丸める。
  static ui.TargetImageSize _targetSize(int width, int height, int maxEdge) {
    final edge = maxEdge < 1 ? 1 : maxEdge;
    final longest = width > height ? width : height;
    // 元が既に小さければ拡大しない(粗い絵を引き伸ばさない)。
    if (longest <= edge) {
      return ui.TargetImageSize(width: width, height: height);
    }
    final scale = edge / longest;
    return ui.TargetImageSize(
      width: (width * scale).round().clamp(1, edge),
      height: (height * scale).round().clamp(1, edge),
    );
  }
}

/// 元場所ハンドルを filesystem path として解釈できるなら返す。
///
/// **`013 ADR-002` の退避経路を壊さないための境界である。** `SafFileSource` は
/// ハンドルへ SAF の document URI(`content://...`)を入れる。それを path として
/// 開こうとすると必ず失敗し、行には「読めなかった」が並ぶ。URI と分かる形なら
/// **試みずに [PreviewUnsupported] へ落とす** — 退避しても preview が静かに
/// 消えるだけで、壊れたようには見えない。
///
/// scheme 付き URI かどうかだけを見る。Windows の `C:\...` は `://` を含まない。
String? filesystemPathOf(String? handle) {
  if (handle == null || handle.isEmpty) return null;
  if (handle.contains('://')) return null;
  return handle;
}
