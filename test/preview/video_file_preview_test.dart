// 008:T07 動画 thumbnail の **Dart 側の写像**。
//
// **Kotlin 側は検査していない。** `MediaMetadataRetriever` が本当に frame を返すかは
// CI で実行できず、このtaskの実機確認が引き受ける(task.md の宣言表)。ここが固定する
// のは「channel が何を返したときに何になるか」だけである。
// `MethodChannelStorageVolumes` の test と同じ立て付け。

import 'package:batch_rename_master/core/file_entry.dart';
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:batch_rename_master/data/preview/video_file_preview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _video() => FileEntry(
  name: 'VID_0001.mp4',
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceHandle: '/storage/emulated/0/DCIM/Camera/VID_0001.mp4',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannelVideoPreview.channel;

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  test('bytes が返れば thumbnail になる', () async {
    answerWith((call) async {
      expect(call.method, 'thumbnail');
      expect(call.arguments['path'], endsWith('VID_0001.mp4'));
      expect(call.arguments['maxEdge'], 128);
      return Uint8List.fromList([137, 80, 78, 71]);
    });

    final result = await const MethodChannelVideoPreview().thumbnail(
      _video(),
      maxEdge: 128,
    );

    expect(result, isA<PreviewReady>());
    expect((result as PreviewReady).thumbnail, hasLength(4));
  });

  test('null が返れば「読めなかった」になる', () async {
    // Kotlin 側が frame を取り出せなかった場合。応答自体はあったので
    // 「この platform に無い」ではない。
    answerWith((call) async => null);

    final result = await const MethodChannelVideoPreview().thumbnail(
      _video(),
      maxEdge: 128,
    );

    expect(result, isA<PreviewFailed>());
  });

  test('Kotlin 側の error は「読めなかった」になる', () async {
    answerWith(
      (call) async => throw PlatformException(
        code: 'failed',
        message: 'setDataSource に失敗しました',
      ),
    );

    final result = await const MethodChannelVideoPreview().thumbnail(
      _video(),
      maxEdge: 128,
    );

    expect(
      result,
      isA<PreviewFailed>().having(
        (r) => r.message,
        'message',
        'setDataSource に失敗しました',
      ),
    );
  });

  test('channel が無い platform では「対象外」になる', () async {
    // mock を登録しない = 相手が居ない。Windows desktop がこの状態である。
    // **失敗ではない** — この端末では動画の preview を出さない、というだけで、
    // 行は種別アイコンへ落ちる。OS を判定せずにこう決まるのが要点である
    // (ADR-003: 劣化の要否を OS で判定しない)。
    final result = await const MethodChannelVideoPreview().thumbnail(
      _video(),
      maxEdge: 128,
    );

    expect(result, isA<PreviewUnsupported>());
  });
}
