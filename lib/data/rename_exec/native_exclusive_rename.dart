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

  /// このplatformでは排他的renameを利用できなかった。**呼び出し側は、目標名が実在
  /// しないことを確認済みなら通常renameへ落としてよい**(013 REQ-005)。
  ///
  /// [unsupported]とは意味が違う — あちらは「この機能自体を提供しない」であって、
  /// 落としてよいとは言っていない。**どのOSがこれを返すかをDartは知らない**
  /// (ADR-003)。現状返すのはAndroidのCだけだが、それはC側の事実である。
  fallbackRequired,
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
/// [NativeRenameResult]だけを返す。**この関数は通常renameへのfallbackを行わない。**
/// 劣化は、実在確認を済ませた呼び出し側が[NativeRenameResult.fallbackRequired]を
/// 見て行う(013 REQ-005)。
///
/// **ここにOSの許可リストを持たない**(ADR-003)。分けるのはpath文字列のencodingだけで、
/// Windowsか否かがその唯一の軸である。「このOSに対応しているか」はCと`hook/build.dart`が
/// 持つ — 未対応platform向けにも**同じsymbolが必ずbuildされ**、C側が
/// [NativeRenameResult.unsupported]を返す。Dartで再度OSを判定すると、
/// **同じ事実を2箇所が持つことになり、Linux上のtestからは片方しか観測できない。**
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
  final sourcePointer = source.toNativeUtf8();
  final destinationPointer = destination.toNativeUtf8();
  try {
    return _resultOf(_renameNoReplaceUtf8(sourcePointer, destinationPointer));
  } finally {
    calloc.free(sourcePointer);
    calloc.free(destinationPointer);
  }
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
