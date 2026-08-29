import 'package:flutter/services.dart';

import '../../core/file_entry.dart';
import 'file_preview.dart';
import 'image_file_preview.dart';

/// 動画の1frame目を platform channel 越しに取り出す(008:T07)。
///
/// **OS を判定しない。** channel の相手が居ない platform(Windows desktop)では
/// [MissingPluginException] が飛ぶので、それを [PreviewUnsupported] として扱う。
/// 「Android かどうか」ではなく「**channel が応えるかどうか**」で決めるので、
/// ADR-003 が禁じた Dart 側の OS 分岐にならず、`013 ADR-002` の退避手順にも
/// 合成点が増えない。
///
/// **この class は Linux 上の test で実行できない**(channel の相手が居ない)。
/// `TestDefaultBinaryMessenger` で channel を差し替えれば **Dart 側の写像**は
/// 検査できるが、`MediaMetadataRetriever` が本当に frame を返すかは実機確認が
/// 引き受ける(`task.md` の宣言表)。`MethodChannelStorageVolumes` と同じ形である。
class MethodChannelVideoPreview implements FilePreviewPort {
  const MethodChannelVideoPreview();

  /// channel 名。Kotlin 側(`MainActivity.kt`)と一致させる。
  static const channel = MethodChannel(
    'com.example.batch_rename_master/video_thumbnail',
  );

  @override
  Future<PreviewResult> thumbnail(
    FileEntry entry, {
    required int maxEdge,
  }) async {
    if (previewKindOf(entry.name) != PreviewKind.video) {
      return const PreviewUnsupported('動画ではない');
    }
    final path = filesystemPathOf(entry.sourceHandle);
    if (path == null) {
      return const PreviewUnsupported('元場所ハンドルが path ではない');
    }

    final Uint8List? bytes;
    try {
      bytes = await channel.invokeMethod<Uint8List>('thumbnail', {
        'path': path,
        'maxEdge': maxEdge,
      });
    } on MissingPluginException {
      // channel が無い platform。**失敗ではない** — この端末では動画の preview を
      // 出さない、というだけである。行は種別アイコンへ落ちる。
      return const PreviewUnsupported('この platform に動画 thumbnail は無い');
    } on PlatformException catch (error) {
      // Kotlin 側が理由付きで断った。**[PreviewUnsupported] へ潰さない。**
      return PreviewFailed(error.message ?? error.code);
    } catch (error) {
      return PreviewFailed('$error');
    }
    if (bytes == null) {
      // frame を取り出せない動画はある(壊れている、対応 codec が無い)。
      // 応答はあったので「この platform に無い」ではなく失敗として扱う。
      return const PreviewFailed('動画から frame を取り出せませんでした');
    }
    return PreviewReady(bytes);
  }
}

/// 種別ごとに実装を振り分ける [FilePreviewPort](008:T07)。
///
/// **ここも OS を判定しない。** 動画側は channel が無ければ自分で
/// [PreviewUnsupported] を返すので、両 platform へ同じ合成を配れる。
class KindRoutingFilePreview implements FilePreviewPort {
  const KindRoutingFilePreview({
    this.image = const ImageFilePreview(),
    this.video = const MethodChannelVideoPreview(),
  });

  final FilePreviewPort image;
  final FilePreviewPort video;

  @override
  Future<PreviewResult> thumbnail(FileEntry entry, {required int maxEdge}) {
    switch (previewKindOf(entry.name)) {
      case PreviewKind.image:
        return image.thumbnail(entry, maxEdge: maxEdge);
      case PreviewKind.video:
        return video.thumbnail(entry, maxEdge: maxEdge);
      case PreviewKind.other:
        // 読みに行かない。**preview を出さない種別を毎回開くのは無駄で、
        // 件数の多い folder では速度に直接効く。**
        return Future.value(const PreviewUnsupported('preview を出さない種別'));
    }
  }
}
