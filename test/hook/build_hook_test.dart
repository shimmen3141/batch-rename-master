import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/src/test.dart';

import '../../hook/build.dart' as build_hook;

void main() {
  test('code assetsを要求しない呼び出しではcode configへアクセスしない', () async {
    await testBuildHook(
      mainMethod: build_hook.main,
      extensions: const [],
      check: (input, output) {
        expect(input.config.buildCodeAssets, isFalse);
      },
    );
  });

  // **release build は `linkingEnabled: true` で hook を呼ぶ**(`013:T13`)。debug は
  // `false`。以前の hook(`CLibrary`)は true のとき静的ライブラリを**同じ package の
  // link hook へ送り**、link hook が無いので Flutter の release build が失敗した。
  // debug では露見しなかったので、**両方の値で実際に C を build して**見る。
  for (final linkingEnabled in [false, true]) {
    test('linkingEnabled=$linkingEnabled でも、改名ライブラリを動的ライブラリとして'
        'app に同梱する(link hook へ送らない)', () async {
      await testBuildHook(
        mainMethod: build_hook.main,
        linkingEnabled: linkingEnabled,
        extensions: [
          CodeAssetExtension(
            targetArchitecture: Architecture.current,
            targetOS: OS.current,
            linkModePreference: LinkModePreference.dynamic,
          ),
        ],
        check: (input, output) {
          expect(
            output.assets.encodedAssetsForLinking,
            isEmpty,
            reason: 'link hook は無い。送れば release build が壊れる',
          );
          final codeAssets = output.assets.code;
          expect(codeAssets, hasLength(1));
          final asset = codeAssets.single;
          expect(
            asset.id,
            'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart',
          );
          expect(
            asset.linkMode,
            isA<DynamicLoadingBundled>(),
            reason: 'debug と同じく .so を app に同梱する(013:T08 が実機で確かめた形)',
          );
        },
      );
    });
  }
}
