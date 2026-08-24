// 013 REQ-001〜004 / INV-002: Android の権限 port が channel の応答をどう写すか。
//
// **Kotlin 側が本当に動くかは見ていない**(`013:T08` の実機確認が引き受ける)。
// ここで閉じるのは **Dart 側の写像**である — channel が何を返しても、
// **「権限がある」と言えないときに `granted` を返さない**こと。
// これは Linux 上で `TestDefaultBinaryMessenger` を使えば完全に検査できるので、
// `task.md` の宣言表でいう「ここで閉じる」側に入る。
import 'package:batch_rename_master/data/permission/android_storage_permission.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('どの platform がどの port を使うか', () {
    // **Androidだけが制限を持つ**(013 REQ-001)。desktopは素通しで、013は
    // desktopの振る舞いを変えない。`Platform.isAndroid`を条件式へ直接書くと、
    // この写像をLinux上で固定できない(独立review attempt 1 / 2 / 3)。
    test('Android は channel 越しの port を使う', () {
      expect(
        storagePermissionFor(isAndroid: true),
        isA<AndroidStoragePermission>(),
      );
    });

    test('Android 以外は素通しの port を使う', () {
      expect(
        storagePermissionFor(isAndroid: false),
        isA<UnrestrictedStoragePermission>(),
      );
    });

    test('素通しの port は制限しない(desktop の振る舞いを変えない)', () async {
      final port = storagePermissionFor(isAndroid: false);
      expect(await port.check(), StoragePermissionState.notApplicable);
      expect(await port.openSettings(), isFalse, reason: '開く設定画面が無い');
    });
  });

  const permission = AndroidStoragePermission();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// channel の応答を差し替える。[respond] が投げれば platform 例外になる。
  void stub(Object? Function(MethodCall call) respond) {
    messenger.setMockMethodCallHandler(
      AndroidStoragePermission.channel,
      (call) async => respond(call),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        AndroidStoragePermission.channel,
        null,
      ),
    );
  }

  group('check', () {
    test('true なら granted', () async {
      stub((call) {
        expect(call.method, 'isGranted');
        return true;
      });
      expect(await permission.check(), StoragePermissionState.granted);
    });

    test('false なら denied', () async {
      stub((_) => false);
      expect(await permission.check(), StoragePermissionState.denied);
    });

    // **ここが要点。** 分からないときに通すと 013 INV-002(権限が無い状態で
    // filesystem へ書き込まない)が破れる。**すべて denied へ倒す。**
    test('答えが得られないときは denied へ倒す', () async {
      for (final respond in <Object? Function(MethodCall)>[
        (_) => null, // 値を返さない
        (_) => 'yes', // 型が違う
        (_) => throw PlatformException(code: 'error'), // Kotlin 側が失敗
        (_) => throw MissingPluginException(), // channel の相手が居ない
      ]) {
        stub(respond);
        expect(
          await permission.check(),
          StoragePermissionState.denied,
          reason: '「権限がある」と言えないなら granted を返さない',
        );
      }
    });
  });

  group('openSettings', () {
    test('true なら開けたと answers する', () async {
      stub((call) {
        expect(call.method, 'openSettings');
        return true;
      });
      expect(await permission.openSettings(), isTrue);
    });

    test('開けなかった・失敗した場合は false', () async {
      for (final respond in <Object? Function(MethodCall)>[
        (_) => false,
        (_) => null,
        (_) => throw PlatformException(code: 'error'),
        (_) => throw MissingPluginException(),
      ]) {
        stub(respond);
        expect(await permission.openSettings(), isFalse);
      }
    });
  });
}
