// 004 REQ-015: 保存場所の列挙を platform から受け取る側の写像(`013:T12`)。
//
// **Kotlin 側が本当に volume を返すかは、ここでは分からない。** channel の相手を
// 差し替えて、**返ってきた値をどう読むか**だけを閉じる。実機は `T12` の manual が
// 引き受ける(`task.md` の宣言表)。`AndroidStoragePermission` と同じ形である。

import 'package:batch_rename_master/data/file_source/storage_volumes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const port = MethodChannelStorageVolumes();

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      MethodChannelStorageVolumes.channel,
      handler,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        MethodChannelStorageVolumes.channel,
        null,
      ),
    );
  }

  group('返ってきた一覧の写像', () {
    test('path と name をそのまま持つ', () async {
      answerWith(
        (call) async => [
          {'path': '/storage/emulated/0', 'name': '内部ストレージ'},
          {'path': '/storage/1A2B-3C4D', 'name': 'SD カード'},
        ],
      );

      final result = await port.list();

      expect(result, isA<VolumesListed>());
      final volumes = (result as VolumesListed).volumes;
      expect(volumes.map((v) => v.path), [
        '/storage/emulated/0',
        '/storage/1A2B-3C4D',
      ]);
      expect(volumes.map((v) => v.name), ['内部ストレージ', 'SD カード']);
    });

    test('**空でも「取得できた」である**(取得できなかったのとは違う)', () async {
      answerWith((call) async => []);

      final result = await port.list();

      expect(result, isA<VolumesListed>());
      expect((result as VolumesListed).volumes, isEmpty);
    });

    test('**path が無い行は落とす**(名前だけあっても辿れない)', () async {
      answerWith(
        (call) async => [
          {'name': '名前だけ'},
          {'path': '', 'name': '空'},
          {'path': '/storage/emulated/0', 'name': '内部ストレージ'},
        ],
      );

      final result = await port.list();

      expect((result as VolumesListed).volumes.map((v) => v.path), [
        '/storage/emulated/0',
      ]);
    });

    test('name が無ければ path を名前にする(無名では選べない)', () async {
      answerWith(
        (call) async => [
          {'path': '/storage/1A2B-3C4D'},
        ],
      );

      final result = await port.list();

      expect(
        (result as VolumesListed).volumes.single.name,
        '/storage/1A2B-3C4D',
      );
    });

    test('**空の name も path へ落とす**(無名の行が並ばない)', () async {
      // `getDescription()` が空文字を返す端末がありうる。
      answerWith(
        (call) async => [
          {'path': '/storage/1A2B-3C4D', 'name': ''},
        ],
      );

      final result = await port.list();

      expect(
        (result as VolumesListed).volumes.single.name,
        '/storage/1A2B-3C4D',
      );
    });

    test('Map でない行は落とす', () async {
      answerWith(
        (call) async => [
          'ただの文字列',
          {'path': '/storage/emulated/0', 'name': '内部ストレージ'},
        ],
      );

      expect((await port.list() as VolumesListed).volumes, hasLength(1));
    });
  });

  group('取得できなかったとき', () {
    test('**例外を空の一覧へ落とさない**(装着されている媒体を「無い」と見せない)', () async {
      answerWith(
        (call) async => throw PlatformException(
          code: 'failed',
          message: 'StorageManager を取得できませんでした',
        ),
      );

      final result = await port.list();

      expect(result, isA<VolumesUnavailable>());
      expect(
        (result as VolumesUnavailable).reason,
        contains('StorageManager を取得できませんでした'),
      );
    });

    test('応答が無いときも失敗として扱う', () async {
      answerWith((call) async => null);

      expect(await port.list(), isA<VolumesUnavailable>());
    });

    test('channel の相手が居ないときも失敗として扱う', () async {
      // handler を差し替えない = `MissingPluginException`。
      final result = await port.list();

      expect(result, isA<VolumesUnavailable>());
    });

    test('**API 30 未満は理由つきの失敗**(Kotlin 側が `unsupported` を返す)', () async {
      answerWith(
        (call) async => throw PlatformException(
          code: 'unsupported',
          message: 'この Android では保存場所を列挙できません',
        ),
      );

      final result = await port.list();

      expect(
        (result as VolumesUnavailable).reason,
        contains('この Android では保存場所を列挙できません'),
      );
    });
  });

  test('呼ぶ method は `list` である(Kotlin 側と一致させる)', () async {
    final calls = <String>[];
    answerWith((call) async {
      calls.add(call.method);
      return const <Object?>[];
    });

    await port.list();

    expect(calls, ['list']);
  });
}
