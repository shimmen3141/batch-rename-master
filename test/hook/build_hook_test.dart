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
}
