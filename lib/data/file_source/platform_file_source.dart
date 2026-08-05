import 'dart:io';

import 'desktop_file_source.dart';
import 'file_source.dart';
import 'saf_file_source.dart';

/// 実行中のプラットフォームに合う [FileSource] を返す(T4)。
///
/// Android は SAF([SafFileSource])、Windows などのデスクトップは OS ピッカー
/// ([DesktopFileSource])。それ以外(未対応プラットフォーム)は、契約どおり
/// [Failed] を返す実装にフォールバックする(例外は投げない。004 REQ-001)。
FileSource createPlatformFileSource() {
  if (Platform.isAndroid) return SafFileSource();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return const DesktopFileSource();
  }
  return const UnsupportedFileSource();
}

/// 未対応プラットフォーム用の [FileSource]。常に [Failed] を返す(REQ-001/008)。
class UnsupportedFileSource implements FileSource {
  const UnsupportedFileSource();

  static const _error = PickError(
    PickErrorKind.unknown,
    'このプラットフォームではファイルの読み込みに対応していません',
  );

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async =>
      const Failed(_error);
}
