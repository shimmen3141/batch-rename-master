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

/// OSの原子的な「既存名を置換しないrename」を実行する。
///
/// C wrapper内でrenameとerrno/GetLastError取得を連続して行い、Dartへは安定した
/// [NativeRenameResult]だけを返す。通常renameへのfallbackは行わない。
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
  if (Platform.isLinux || Platform.isMacOS) {
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
