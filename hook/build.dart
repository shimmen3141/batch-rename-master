import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final library = CLibrary(
      name: 'batch_rename_native',
      assetName: 'data/rename_exec/native_exclusive_rename.dart',
      sources: ['src/native_exclusive_rename.c'],
      defines: {
        if (input.config.code.targetOS == OS.android ||
            input.config.code.targetOS == OS.iOS)
          'BRM_UNSUPPORTED_PLATFORM': null,
      },
    );
    await library.build(input: input, output: output);
  });
}
