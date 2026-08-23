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
      defines: nativeDefines(targetOS),
    );
    await library.build(input: input, output: output);
  });
}

/// target OS ごとの C 側 define。
///
/// **純関数として出してある。** `if (targetOS == OS.android)` のような literal を
/// test が文字列で見ていると、**別の書き方で同じことをされたときに素通りする**
/// (独立review attempt 9 の P2-2。`targetOS.name == 'android'` を1行足すだけで
/// Android が未対応へ戻るのに、`contains` は通っていた)。ここを純関数にすれば
/// **全 OS を回して振る舞いで検査できる**。
///
/// Android は `013:T05` で生の `renameat2` syscall を使う経路へ移った。
/// iOS は対象外のまま(このアプリの対象 platform ではない)。
Map<String, String?> nativeDefines(OS targetOS) => {
  if (targetOS == OS.iOS) 'BRM_UNSUPPORTED_PLATFORM': null,
};
