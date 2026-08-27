import 'dart:ui' as ui;

import '../../core/file_entry.dart';
import 'file_preview.dart';

/// 画像の thumbnail を Dart の decoder で作る(008:T07)。
///
/// **platform 判定を持たない。** 元場所ハンドルが filesystem path として開ければ
/// 動き、開けなければ結果値で返す。ADR-003 の「OS で劣化の要否を判定しない —
/// 実装が返す結果値で決める」に沿う。Android(013 以降は実 path)でも Windows でも
/// 同じ code が動く。
///
/// **decode 時点で縮小する。** [ui.instantiateImageCodecWithSize] へ目標サイズを
/// 渡すので、元画像が何 MB でも保持するのは thumbnail の分だけである。file 全体を
/// Dart の heap へ読み込まない([ui.ImmutableBuffer.fromFilePath] が engine 側で
/// 開く)。
class ImageFilePreview implements FilePreviewPort {
  const ImageFilePreview();

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

    ui.ImmutableBuffer? buffer;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          final longest = width > height ? width : height;
          // 元が既に小さければ拡大しない(粗い絵を引き伸ばさない)。
          if (longest <= maxEdge) {
            return ui.TargetImageSize(width: width, height: height);
          }
          final scale = maxEdge / longest;
          return ui.TargetImageSize(
            width: (width * scale).round().clamp(1, maxEdge),
            height: (height * scale).round().clamp(1, maxEdge),
          );
        },
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) {
        return const PreviewFailed('thumbnail を PNG へ書き出せませんでした');
      }
      return PreviewReady(encoded.buffer.asUint8List());
    } catch (error) {
      // **握りつぶさない。** 読めなかったことと preview が無いことは別である。
      return PreviewFailed('$error');
    } finally {
      image?.dispose();
      // **codec を作れたら buffer は codec のもの。** 渡した後に自分でも
      // 捨てると二重解放になる(assert で落ちる)。渡す前に失敗したときだけ
      // こちらで捨てる。
      if (codec == null) {
        buffer?.dispose();
      } else {
        codec.dispose();
      }
    }
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
