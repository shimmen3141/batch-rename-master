import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final targetOS = input.config.code.targetOS;
    final library = CLibrary(
      name: 'batch_rename_native',
      assetName: 'data/rename_exec/native_exclusive_rename.dart',
      sources: ['src/native_exclusive_rename.c'],
      // **header も依存として宣言する。** `sources` だけだと
      // `src/brm_renameat2_abi.h` を編集しても再 build されず、古い .so が残る
      // (独立review attempt 7 の P2-1)。`013:T08` の Android build 反復に効く。
      includes: ['src'],
      defines: {
        // Android は 013:T05 で生の renameat2 syscall を使う経路へ移った。
        // iOS は対象外のまま(このアプリの対象 platform ではない)。
        if (targetOS == OS.iOS) 'BRM_UNSUPPORTED_PLATFORM': null,
      },
    );
    await library.build(input: input, output: output);
  });
}
