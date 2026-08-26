// 013:T08 — 排他 rename が実際に効くかを、**1つの directory について観測する**核。
//
// 端末側の runner(`android_storage_probe_test.dart`)と、host での dry-run
// (`test/spec_013_android_rename/storage_probe_test.dart`)が**同じ核**を使う。
// 分けてあるのは、**人間へ依頼する前に harness 自体を CI で確かめる**ためである
// (依頼して初めて harness の誤りに気づくと、実機の時間を捨てることになる)。
//
// **観測するだけで、環境を判定しない。** 「効いた」も「劣化した」も正常な結果で
// ある(005 contract revision 4)。欠陥は**保証が破れたとき**だけである。

import 'dart:io';

import 'package:batch_rename_master/data/file_source/android_storage_browser.dart';
import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:batch_rename_master/data/rename_exec/plain_rename.dart';
import 'package:path/path.dart' as p;

/// 観測用の中身。**どちらが残ったかを結果コードではなく中身で見分ける。**
const sourceBody = 'brm-t08-source';
const targetBody = 'brm-t08-target';

/// 置く file 名の接頭辞。**残骸をこれで判別できる。**
const probePrefix = 'brm-t08-';

/// この app の package。`Android/media/<package>` は共有ストレージの一部で、
/// 全ファイルアクセスがあれば書ける場所である(004 REQ-018 が注記を出さない側)。
const probePackage = 'com.example.batch_rename_master';

/// app ごとの保存領域のうち、この観測が使う directory。
///
/// **runner が後片付けに使う**ので関数として出してある(独立review attempt 1 の P2-7)。
String mediaProbeDirectoryOf(String primaryRoot) =>
    p.join(primaryRoot, 'Android', 'media', probePackage);

/// 観測する場所と、報告に出す説明。
class ProbeTarget {
  const ProbeTarget(this.directory, this.label);

  final String directory;
  final String label;
}

/// 1 directory 分の観測結果。
class ProbeRow {
  ProbeRow({
    required this.target,
    required this.exclusive,
    required this.observedTargetBody,
    required this.observedSourceBody,
    required this.control,
    required this.observedControlBody,
  }) : skipReason = null;

  ProbeRow.skipped(this.target, this.skipReason)
    : exclusive = null,
      observedTargetBody = null,
      observedSourceBody = null,
      control = null,
      observedControlBody = null;

  final ProbeTarget target;

  /// 排他 rename の結果。`null` は観測できなかったことを表す。
  final NativeRenameResult? exclusive;

  /// 排他 rename のあとの、目標名の中身。
  final String? observedTargetBody;

  /// 排他 rename のあとの、source の中身。
  final String? observedSourceBody;

  /// 対照(通常 rename)の結果。
  final NativeRenameResult? control;

  /// 対照のあとの、目標名の中身。
  final String? observedControlBody;

  /// 観測できなかった理由。
  final String? skipReason;

  String get directory => target.directory;

  bool get observed => exclusive != null;

  /// **フラグについて何か分かった行か。**
  ///
  /// `permissionDenied` や skip は「観測できた」ではあっても、
  /// **`RENAME_NOREPLACE` が効くかどうかを何も言っていない**。全 volume がこれだと
  /// 緑になっても収穫はゼロなので、runner はこちらで数える
  /// (独立review attempt 1 の P2-6)。
  bool get answersTheQuestion =>
      exclusive == NativeRenameResult.nameConflict ||
      exclusive == NativeRenameResult.fallbackRequired;

  /// 排他 rename が実際に効いたか。**判定ではなく観測の言い換えである。**
  String get verdict => switch (exclusive) {
    null => '観測できず',
    NativeRenameResult.nameConflict => 'RENAME_NOREPLACE が効いた',
    NativeRenameResult.fallbackRequired => '効かない(通常 rename へ劣化する)',
    NativeRenameResult.permissionDenied => '書き込めない場所',
    final other => '想定外: ${other.name}',
  };

  /// **保証が破れた観測**。`null` なら破れていない。
  ///
  /// 環境依存の違い(効いた / 劣化した)は欠陥ではない。破れているのは次の場合だけ。
  ///
  /// - 目標名の中身が変わった(005 INV-002)
  /// - 失敗したのに source が変わった(005 REQ-016)
  /// - 対照が置換しなかった(この場所の結果から因果を読めない。`013:T01` の
  ///   初回 spike が対照を欠いて review で P1 になった型)
  String? get defect {
    if (skipReason != null) return null;
    if (exclusive != NativeRenameResult.nameConflict &&
        exclusive != NativeRenameResult.fallbackRequired &&
        exclusive != NativeRenameResult.permissionDenied) {
      return '排他 rename が想定外の結果を返した: ${exclusive?.name}';
    }
    // **実体の検査は書けない場所でも飛ばさない。** fixture を置けた場所でしか
    // ここへ来ないので、`permissionDenied` でも「目標名と source は無傷」は
    // 成り立たなければならない(独立review attempt 1 の P2-5)。免除するのは
    // **対照だけ**である。
    if (observedTargetBody != targetBody) {
      return '**目標名の中身が変わった**(005 INV-002)。'
          'expected=$targetBody actual=$observedTargetBody';
    }
    if (observedSourceBody != sourceBody) {
      return '**改名されなかったのに source が変わった**(005 REQ-016)。'
          'expected=$sourceBody actual=$observedSourceBody';
    }
    if (exclusive == NativeRenameResult.permissionDenied) return null;
    if (control != NativeRenameResult.success ||
        observedControlBody != sourceBody) {
      return '対照(通常 rename)が置換しなかった。この場所の結果は因果を示せない。'
          'control=${control?.name} body=$observedControlBody';
    }
    return null;
  }
}

/// 排他 rename の呼び出し。**test から差し替えられるようにしてある** — 失敗経路
/// (native を呼べない)を host で固定するため(独立review attempt 1 の P1-1)。
typedef ExclusiveRenameOperation =
    NativeRenameResult Function(String source, String destination);

/// [target] を観測する。**この関数は例外を投げない** — 観測できない理由も結果である。
///
/// **native の呼び出しも保護する。** `@Native` の symbol 解決に失敗すると
/// `FileSystemException` ではない例外が飛び、**報告が1行も出ないまま端末に残骸が
/// 残る**(独立review attempt 1 の P1-1)。この構成は端末で一度も走らせていないので、
/// **失敗経路も観測結果として返す**。
Future<ProbeRow> probeDirectory(
  ProbeTarget target, {
  ExclusiveRenameOperation exclusiveRename = renameFileWithoutOverwrite,
  PlainRenameOperation plainRename = plainRenameFile,
}) async {
  final source = p.join(target.directory, '${probePrefix}source.txt');
  final destination = p.join(target.directory, '${probePrefix}target.txt');
  final controlSource = p.join(
    target.directory,
    '${probePrefix}control-source.txt',
  );
  final controlTarget = p.join(
    target.directory,
    '${probePrefix}control-target.txt',
  );
  final all = [source, destination, controlSource, controlTarget];

  // **後片付けは `finally` に置く。** 個別の `await` を catch で囲む形は、
  // **`await` を1つ足すたびに漏れる** — 独立review attempt 1 の P1-1 を「native の
  // 呼び出しだけ囲む」で直したところ、attempt 2 で列挙側(`androidProbeTargets`)に
  // 同じ穴が見つかった。このprojectは同じ結論に既に達している
  // (`lib/data/rename_exec/desktop_rename_executor.dart` の「個別のawaitをcatchで
  // 囲むのではなく、まとめて囲む」)。
  try {
    try {
      await cleanUpProbeFiles(all);
      await File(source).writeAsString(sourceBody, flush: true);
      await File(destination).writeAsString(targetBody, flush: true);
    } on FileSystemException catch (error) {
      return ProbeRow.skipped(
        target,
        'fixture を置けない: ${error.osError?.message ?? error.message}',
      );
    }

    // (1) 排他 rename。**目標名は実在している。**
    final NativeRenameResult exclusive;
    try {
      exclusive = exclusiveRename(source, destination);
    } catch (error) {
      return ProbeRow.skipped(target, '排他 rename を呼べない: $error');
    }

    // (2) 実体がどうなったか。
    final observedTargetBody = await _read(destination);
    final observedSourceBody = await _read(source);

    // (3) 対照。同じ場所で**通常 rename が置換する**ことを確かめる。これが起きない
    //     場所では、(1) の結果を「フラグが効いた」と読めない。
    NativeRenameResult? control;
    String? observedControlBody;
    try {
      await File(controlSource).writeAsString(sourceBody, flush: true);
      await File(controlTarget).writeAsString(targetBody, flush: true);
      control = await plainRename(controlSource, controlTarget);
      observedControlBody = await _read(controlTarget);
    } catch (_) {
      // 対照を実行できなかったことは `defect` が拾う。**注入された実装が
      // `FileSystemException` 以外を投げても同じ**(P2-13)。
    }

    return ProbeRow(
      target: target,
      exclusive: exclusive,
      observedTargetBody: observedTargetBody,
      observedSourceBody: observedSourceBody,
      control: control,
      observedControlBody: observedControlBody,
    );
  } finally {
    await cleanUpProbeFiles(all);
  }
}

/// Android で観測する場所。
///
/// **実際に mount されている volume** から作る(`AndroidStorageBrowser` が製品で
/// 使っているのと同じ列挙)。SD カード・USB を挿していれば**自動でその volume も
/// 観測する** — `task.md` の項目7はここで埋まる。
Future<List<ProbeTarget>> androidProbeTargets({
  AndroidStorageBrowser browser = const AndroidStorageBrowser(),
  String extraDirs = '',
}) async {
  final targets = <ProbeTarget>[];
  // **1つの volume で失敗しても、他の volume の観測を捨てない。**
  // `/storage` には辿れない entry(取り外し済み・別 user・stale mount)が並びうる。
  // `Directory.exists()` はそこで `PathAccessException` を投げる — **`false` を
  // 返すのではない**(独立review attempt 2 の P1-2 が実測した)。
  try {
    for (final location in await browser.locations()) {
      targets.add(ProbeTarget(location.root, '${location.name} の root'));
      try {
        final download = p.join(location.root, 'Download');
        if (await Directory(download).exists()) {
          targets.add(ProbeTarget(download, '${location.name} の Download'));
        }
      } catch (_) {
        // この volume の Download は観測しない。root は観測対象に残っており、
        // 読めなければ `probeDirectory` が理由つきで skip を返す。
      }
    }

    // app ごとの保存領域。共有ストレージの一部だが FUSE の扱いが違いうるので、
    // 内部共有ストレージの root とは別に観測する。
    final media = mediaProbeDirectoryOf(browser.primaryRoot);
    try {
      await Directory(media).create(recursive: true);
      targets.add(ProbeTarget(media, 'app ごとの保存領域'));
    } catch (_) {
      // 作れなければ観測しない。**`/Android/` 配下は読めないことがある**という
      // 既知の事実で、`013:T07` の manual で確認済みである。
    }

    // **非FUSE の対照。** ここまでの対象はすべて共有ストレージ(MediaProvider の
    // FUSE)である。`013:T01` の項目4「FUSE 自身が判定したのか下位へ委譲したのか」は、
    // FUSE を経由しない場所と**同じ app プロセスで**比べて初めて前進する。
    // app の内部領域は `/data` 上にあり FUSE を経由しない(実際の path は報告に出る)。
    targets.add(ProbeTarget(Directory.systemTemp.path, 'app の内部領域(非FUSE の対照)'));
  } catch (_) {
    // **本体をまとめて囲む。** 個別の文を囲む形は、`await` を1つ足すたびに漏れる
    // (独立review attempt 1 → 2 → 3 で同じ型を3回踏んだ)。ここまでに作れた
    // 観測対象を返して先へ進む — **報告をゼロにしない。**
  }

  for (final extra in extraDirs.split(',')) {
    final trimmed = extra.trim();
    if (trimmed.isEmpty) continue;
    targets.add(ProbeTarget(trimmed, '--dart-define で追加'));
  }
  return targets;
}

/// 人間がそのまま貼れる形の報告。
String reportOf(List<ProbeRow> rows) {
  final buffer = StringBuffer()
    ..writeln('=== 013:T08 排他 rename の観測 ===')
    ..writeln(
      'platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    )
    ..writeln('観測対象: ${rows.length} 件');
  for (final row in rows) {
    buffer
      ..writeln('---')
      ..writeln('場所: ${row.directory}(${row.target.label})');
    if (row.skipReason != null) {
      buffer.writeln('観測できず: ${row.skipReason}');
      continue;
    }
    buffer
      ..writeln('排他 rename: ${row.exclusive?.name} → ${row.verdict}')
      ..writeln('目標名の中身: ${row.observedTargetBody}(変わっていなければ $targetBody)')
      ..writeln('source の中身: ${row.observedSourceBody}(残っていれば $sourceBody)')
      ..writeln(
        '対照(通常 rename): ${row.control?.name} '
        '目標名の中身=${row.observedControlBody}(置換されていれば $sourceBody)',
      );
    if (row.defect != null) buffer.writeln('**保証が破れた**: ${row.defect}');
  }
  buffer.writeln('=== ここまで。この出力をそのまま貼って返してください ===');
  return buffer.toString();
}

Future<String?> _read(String path) async {
  try {
    return await File(path).readAsString();
  } on FileSystemException {
    return null;
  }
}

/// 観測のために作った directory を消す。**空のときだけ消える**(非再帰)。
///
/// 元からあった directory を巻き添えにしないため、中身があれば何もしない。
Future<void> cleanUpProbeDirectory(String path) async {
  try {
    await Directory(path).delete();
  } on FileSystemException {
    // 元からあった / 中身がある / 消す権限が無い。**どれでも観測には影響しない。**
  }
}

/// 観測用に置いた file を消す。**消せなくても観測は続ける。**
Future<void> cleanUpProbeFiles(List<String> paths) async {
  for (final path in paths) {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // 残骸は接頭辞で判別できる。
    }
  }
}
