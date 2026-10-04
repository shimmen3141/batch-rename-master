// 010:T04 — このアプリで改名したときに、「ファイルがこの端末に作られた時刻」が
// 変わるかを観測する核。
//
// 端末側の runner(`creation_time_probe_test.dart`)と、host での dry-run
// (`test/spec_010_photo_video_source/creation_time_probe_test.dart`)が**同じ核**を
// 使う。人間へ依頼する前に harness 自体を CI で確かめるためである(`013:T08` と同じ形)。
//
// 見るのは2つの候補のうち、**app の中から読める方**だけである。
// - `statx` の作成時刻(btime): ここで読む。改名でファイルの実体は変わらないので、
//   変わらない見込みだが、Android の共有ストレージ(MediaProvider の FUSE)が値を
//   返すかは分からない。
// - MediaStore の `DATE_ADDED`: app からは platform channel が無いと読めない。
//   **製品の code を仕様の承認前に増やさない**ため、ここでは読まず、改名の時刻と
//   照会の command を報告に出し、人間が `adb shell content query` で読む。
//
// **観測するだけで、判定しない。** btime が無い・変わる、はどちらも正常な結果で、
// 分かるのは `010:T01` が作成日時の3番目の経路に何を使えるかである。

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

/// 置く file 名の接頭辞。**残骸をこれで判別できる。**
const creationProbePrefix = 'brm-010-';

/// 端末で観測に使う directory。ダウンロードしたファイルが置かれる場所である。
const deviceCreationProbeDirectory =
    '/storage/emulated/0/Download/brm-010-probe';

// <linux/stat.h> の値。Android(bionic)と glibc で同じである。
const _atFdcwd = -100;
const _statxMtime = 0x40;
const _statxBtime = 0x800;

// `struct statx` は 256 byte。時刻は `struct statx_timestamp`(int64 秒 + uint32 ナノ秒)。
const _statxSize = 256;
const _btimeOffset = 80;
const _mtimeOffset = 112;

typedef _StatxNative =
    Int32 Function(Int32, Pointer<Utf8>, Int32, Uint32, Pointer<Uint8>);
typedef _StatxDart = int Function(int, Pointer<Utf8>, int, int, Pointer<Uint8>);

/// `statx` へ要求する項目(作成時刻と更新時刻)。
///
/// 要求しなくても filesystem が値を返すことがあるので、host の test では要求の
/// 取り違えを観測できない。値そのものを test で確かめる(独立review attempt 1 の F1)。
@visibleForTesting
const requestedStatxMask = _statxBtime | _statxMtime;

/// `statx` で読んだ時刻。
class StatxTimes {
  const StatxTimes({required this.btime, required this.mtime});

  /// 作成時刻。**filesystem が返さなければ `null`**(`stx_mask` に `STATX_BTIME` が無い)。
  final DateTime? btime;

  final DateTime mtime;
}

/// [path] の作成時刻と更新時刻を `statx` で読む。
///
/// `statx` という関数が process に無ければ `null`(Android 11 未満の bionic など)。
/// 呼び出しが失敗したら [FileSystemException]。
StatxTimes? readStatx(String path) {
  final statx = _lookupStatx();
  if (statx == null) return null;
  final buffer = calloc<Uint8>(_statxSize);
  final nativePath = path.toNativeUtf8();
  try {
    final result = statx(_atFdcwd, nativePath, 0, requestedStatxMask, buffer);
    if (result != 0) {
      throw FileSystemException('statx が失敗した', path);
    }
    return parseStatx(ByteData.sublistView(buffer.asTypedList(_statxSize)));
  } finally {
    calloc.free(buffer);
    calloc.free(nativePath);
  }
}

/// `struct statx` の中身([statxSize] byte)から時刻を取り出す。
///
/// 端末の filesystem を選べない host の test でも、構造体の読み方を確かめられるように
/// 分けてある。
StatxTimes parseStatx(ByteData data) {
  final mask = data.getUint32(0, Endian.host);
  return StatxTimes(
    btime: mask & _statxBtime == 0 ? null : _timestampAt(data, _btimeOffset),
    mtime: _timestampAt(data, _mtimeOffset),
  );
}

/// `struct statx` の大きさ。
const statxSize = _statxSize;

DateTime _timestampAt(ByteData data, int offset) {
  final seconds = data.getInt64(offset, Endian.host);
  final nanoseconds = data.getUint32(offset + 8, Endian.host);
  return DateTime.fromMicrosecondsSinceEpoch(
    seconds * Duration.microsecondsPerSecond + nanoseconds ~/ 1000,
    isUtc: true,
  );
}

/// 1つの段階(作った直後・1回目の改名の後・2回目の改名の後)の観測。
class CreationProbeStep {
  const CreationProbeStep({
    required this.label,
    required this.path,
    required this.at,
    required this.times,
    this.renameResult,
    this.error,
  });

  final String label;
  final String path;

  /// この段階の操作を終えた壁時計の時刻(UTC)。
  final DateTime at;

  /// `statx` が無いか読めなければ `null`。
  final StatxTimes? times;

  /// 改名した段階だけ持つ。
  final NativeRenameResult? renameResult;

  final String? error;
}

/// 観測の全体。
class CreationProbeReport {
  const CreationProbeReport({
    required this.directory,
    required this.statxAvailable,
    required this.steps,
    required this.control,
  });

  final String directory;

  /// process に `statx` があったか。
  final bool statxAvailable;

  /// 改名する file の各段階。
  final List<CreationProbeStep> steps;

  /// 改名しない対照の file。`DATE_ADDED` が作った時刻になることを見比べるためにある。
  final CreationProbeStep control;

  /// 改名の前後で btime が変わらなかったか。btime が1度でも読めなければ `null`。
  bool? get btimeStable {
    final btimes = steps.map((step) => step.times?.btime).toList();
    if (btimes.isEmpty || btimes.any((btime) => btime == null)) return null;
    return btimes.every((btime) => btime == btimes.first);
  }

  /// 改名の前後で mtime が変わらなかったか。
  bool? get mtimeStable {
    final mtimes = steps.map((step) => step.times?.mtime).toList();
    if (mtimes.isEmpty || mtimes.any((mtime) => mtime == null)) return null;
    return mtimes.every((mtime) => mtime == mtimes.first);
  }

  /// 2回の改名がどちらも成功したか。
  bool get renamed =>
      steps.where((step) => step.renameResult != null).length == 2 &&
      steps.every(
        (step) =>
            step.renameResult == null ||
            step.renameResult == NativeRenameResult.success,
      );
}

/// [directory] に file を置き、製品と同じ改名(`renameFileWithoutOverwrite`)を
/// [gap] をあけて2回行い、各段階の時刻を読む。
///
/// **置いた file は消さない。** 人間が後から `DATE_ADDED` を照会するためである。
/// 前回の残骸(接頭辞 [creationProbePrefix])は始める前に消す。
Future<CreationProbeReport> observeCreationTimes(
  String directory, {
  Duration gap = const Duration(seconds: 3),
}) async {
  final dir = Directory(directory);
  await dir.create(recursive: true);
  await for (final entity in dir.list()) {
    if (entity is File &&
        p.basename(entity.path).startsWith(creationProbePrefix)) {
      await entity.delete();
    }
  }

  final statxAvailable = _statxAvailable();
  final names = [
    '${creationProbePrefix}a.txt',
    '${creationProbePrefix}a-renamed-1.txt',
    '${creationProbePrefix}a-renamed-2.txt',
  ];
  final controlPath = p.join(directory, '${creationProbePrefix}control.txt');

  await File(controlPath).writeAsString('brm-010-control');
  final control = _stepOf('対照(改名しない)', controlPath);

  final first = p.join(directory, names[0]);
  await File(first).writeAsString('brm-010-renamed');
  final steps = [_stepOf('作った直後', first)];
  for (var i = 1; i < names.length; i++) {
    await Future<void>.delayed(gap);
    final from = p.join(directory, names[i - 1]);
    final to = p.join(directory, names[i]);
    final result = renameFileWithoutOverwrite(from, to);
    steps.add(_stepOf('$i回目の改名の後', to, renameResult: result));
  }

  return CreationProbeReport(
    directory: directory,
    statxAvailable: statxAvailable,
    steps: steps,
    control: control,
  );
}

bool _statxAvailable() => _lookupStatx() != null;

/// `statx` を探す。process の大域の symbol に無ければ libc を直接開く。
///
/// 端末で観測できる機会は少ないので、探し方の違いだけで btime を見損なわないよう
/// 2通り試す(独立review attempt 1 の F4)。
_StatxDart? _lookupStatx() {
  for (final open in [
    DynamicLibrary.process,
    () => DynamicLibrary.open('libc.so'),
    () => DynamicLibrary.open('libc.so.6'),
  ]) {
    try {
      return open().lookupFunction<_StatxNative, _StatxDart>('statx');
    } on ArgumentError {
      continue;
    }
  }
  return null;
}

CreationProbeStep _stepOf(
  String label,
  String path, {
  NativeRenameResult? renameResult,
}) {
  final at = DateTime.now().toUtc();
  try {
    return CreationProbeStep(
      label: label,
      path: path,
      at: at,
      times: readStatx(path),
      renameResult: renameResult,
    );
  } catch (error) {
    return CreationProbeStep(
      label: label,
      path: path,
      at: at,
      times: null,
      renameResult: renameResult,
      error: '$error',
    );
  }
}

String _epoch(DateTime? time) => time == null
    ? '(無し)'
    : '${time.millisecondsSinceEpoch ~/ 1000} (${time.toIso8601String()})';

/// 人間がそのまま貼って返す報告。
String creationProbeReportText(CreationProbeReport report) {
  final buffer = StringBuffer()
    ..writeln('=== 010:T04 作成時刻の観測 ===')
    ..writeln('directory: ${report.directory}')
    ..writeln('statx: ${report.statxAvailable ? 'あり' : '無し'}');
  for (final step in [report.control, ...report.steps]) {
    buffer
      ..writeln('--- ${step.label}: ${p.basename(step.path)}')
      ..writeln('  時刻(UTC 秒): ${_epoch(step.at)}')
      ..writeln('  btime: ${_epoch(step.times?.btime)}')
      ..writeln('  mtime: ${_epoch(step.times?.mtime)}');
    if (step.renameResult != null) {
      buffer.writeln('  改名の結果: ${step.renameResult!.name}');
    }
    if (step.error != null) buffer.writeln('  エラー: ${step.error}');
  }
  buffer
    ..writeln('--- まとめ')
    ..writeln('  改名: ${report.renamed ? '2回とも成功' : '失敗あり'}')
    ..writeln('  btime が改名で変わらない: ${report.btimeStable ?? '読めない'}')
    ..writeln('  mtime が改名で変わらない: ${report.mtimeStable ?? '読めない'}')
    ..writeln('=== ここまで。この出力をそのまま貼って返してください ===');
  return buffer.toString();
}

/// 人間が `DATE_ADDED` を読むための command(Windows の PowerShell 向け)。
String dateAddedQueryCommand(String directory) =>
    '& "\$env:LOCALAPPDATA\\Android\\Sdk\\platform-tools\\adb.exe" shell '
    "\"content query --uri content://media/external/file "
    '--projection _display_name:date_added:date_modified:datetaken '
    "--where \\\"_data LIKE '$directory/%'\\\"\"";
