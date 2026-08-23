import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Native wrapperから返す、OSのerror stateに依存しない安定した結果。
enum NativeRenameResult {
  success,
  nameConflict,
  notFound,
  permissionDenied,
  unsupported,
  io,
}

@Native<Int32 Function(Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'brm_rename_no_replace_utf8',
)
external int _renameNoReplaceUtf8(
  Pointer<Utf8> source,
  Pointer<Utf8> destination,
);

@Native<Int32 Function(Pointer<Utf16>, Pointer<Utf16>)>(
  symbol: 'brm_rename_no_replace_utf16',
)
external int _renameNoReplaceUtf16(
  Pointer<Utf16> source,
  Pointer<Utf16> destination,
);

/// この OS が UTF-8 path の C wrapper を使うか(Windows は UTF-16)。
///
/// **Android を含む。** C 側は Android のとき**生の syscall** で `renameat2` を
/// 呼ぶので、bionic の wrapper が公開された API level に依存しない
/// (013 spec D-1 / `013:T05`)。
///
/// **純関数として切り出してある。** `Platform.isAndroid` を条件式へ直接書くと、
/// Linux 上の test から Android の分岐を観測できず、**Android を分岐から外しても
/// suite が緑のまま**になる(独立review attempt 1 の P1-2)。
bool usesUtf8NativePath(String operatingSystem) => switch (operatingSystem) {
  'linux' || 'macos' || 'android' => true,
  _ => false,
};

/// OSの原子的な「既存名を置換しないrename」を実行する。
///
/// C wrapper内でrenameとerrno/GetLastError取得を連続して行い、Dartへは安定した
/// [NativeRenameResult]だけを返す。**この関数は通常renameへのfallbackを行わない。**
/// Androidでflagが効かないときの劣化は、実在確認を済ませた呼び出し側が持つ
/// (`android_rename_executor.dart` の `androidRenameOperation`。013 REQ-005)。
NativeRenameResult renameFileWithoutOverwrite(
  String source,
  String destination,
) {
  if (Platform.isWindows) {
    final sourcePointer = _extendedWindowsPath(source).toNativeUtf16();
    final destinationPointer = _extendedWindowsPath(
      destination,
    ).toNativeUtf16();
    try {
      return _resultOf(
        _renameNoReplaceUtf16(sourcePointer, destinationPointer),
      );
    } finally {
      calloc.free(sourcePointer);
      calloc.free(destinationPointer);
    }
  }
  if (usesUtf8NativePath(Platform.operatingSystem)) {
    final sourcePointer = source.toNativeUtf8();
    final destinationPointer = destination.toNativeUtf8();
    try {
      return _resultOf(_renameNoReplaceUtf8(sourcePointer, destinationPointer));
    } finally {
      calloc.free(sourcePointer);
      calloc.free(destinationPointer);
    }
  }
  return NativeRenameResult.unsupported;
}

NativeRenameResult _resultOf(int value) {
  if (value < 0 || value >= NativeRenameResult.values.length) {
    return NativeRenameResult.io;
  }
  return NativeRenameResult.values[value];
}

String _extendedWindowsPath(String path) {
  if (path.startsWith(r'\\?\')) return path;
  if (path.startsWith(r'\\')) return r'\\?\UNC\' + path.substring(2);
  return r'\\?\' + path;
}
