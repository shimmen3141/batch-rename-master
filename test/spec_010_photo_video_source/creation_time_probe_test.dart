// `010:T04` の観測 harness を host で回す。
//
// **人間へ実機を依頼する前に、harness 自体が働くことを CI で確かめる**ためにある
// (`013:T08` と同じ)。**ここが確かめるのは harness であって、Android の挙動ではない。**
// Linux の ext4 が btime を返し改名で変えないことは、Android の共有ストレージ
// (MediaProvider の FUSE)がそうであることを意味しない。

import 'dart:io';
import 'dart:typed_data';

import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/creation_time_probe.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-010-host-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('parseStatx', () {
    // <linux/stat.h> の `struct statx` の位置: stx_mask は 0、stx_btime は 80、
    // stx_ctime は 96、stx_mtime は 112(それぞれ int64 秒 + uint32 ナノ秒)。
    ByteData statxWith({required int mask}) {
      final data = ByteData(statxSize);
      data.setUint32(0, mask, Endian.host);
      void put(int offset, int seconds, int nanoseconds) {
        data.setInt64(offset, seconds, Endian.host);
        data.setUint32(offset + 8, nanoseconds, Endian.host);
      }

      put(80, 1000000000, 500000000); // btime
      put(96, 1500000000, 0); // ctime(読まないこと)
      put(112, 1700000000, 250000000); // mtime
      return data;
    }

    test('STATX_BTIME があれば btime を読み、mtime も正しい位置から読む', () {
      final times = parseStatx(statxWith(mask: 0x800 | 0x40));

      expect(
        times.btime,
        DateTime.fromMicrosecondsSinceEpoch(1000000000500000, isUtc: true),
      );
      expect(
        times.mtime,
        DateTime.fromMicrosecondsSinceEpoch(1700000000250000, isUtc: true),
      );
    });

    test('STATX_BTIME が無ければ btime は null(場所に残った値を読まない)', () {
      expect(parseStatx(statxWith(mask: 0x40)).btime, isNull);
    });
  });

  group('readStatx', () {
    test('statx へ作成時刻(STATX_BTIME)と更新時刻(STATX_MTIME)を要求する', () {
      // 要求しなくても値を返す filesystem があるので、実ファイルでは確かめられない。
      expect(requestedStatxMask & 0x800, 0x800);
      expect(requestedStatxMask & 0x40, 0x40);
    });

    test('host の libc に statx がある(このtestの前提)', () {
      final file = File(p.join(dir.path, 'x.txt'))..writeAsStringSync('x');
      expect(readStatx(file.path), isNotNull);
    });

    test('mtime が FileStat の更新時刻と一致する(構造体の位置を読み違えていない)', () async {
      final file = File(p.join(dir.path, 'x.txt'))..writeAsStringSync('x');
      await file.setLastModified(DateTime.utc(2001, 2, 3, 4, 5, 6));

      final times = readStatx(file.path)!;

      expect(times.mtime, DateTime.utc(2001, 2, 3, 4, 5, 6));
    });

    test('btime が読めるなら、改名しても変わらず、ctime の位置を読んでいない', () async {
      final file = File(p.join(dir.path, 'x.txt'))..writeAsStringSync('x');
      final before = readStatx(file.path)!;
      if (before.btime == null) {
        markTestSkipped('host の filesystem が btime を返さない');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // 改名と時刻の書き換えは ctime を進める。btime の位置を読んでいれば変わらない。
      final moved = file.renameSync(p.join(dir.path, 'y.txt'));
      await moved.setLastModified(DateTime.utc(2001, 2, 3));

      expect(readStatx(moved.path)!.btime, before.btime);
    });

    test('無い path は FileSystemException', () {
      expect(
        () => readStatx(p.join(dir.path, 'missing.txt')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('observeCreationTimes', () {
    test('2回改名し、各段階を読み、置いた file を残す', () async {
      final report = await observeCreationTimes(
        dir.path,
        gap: const Duration(milliseconds: 50),
      );

      expect(report.statxAvailable, isTrue);
      expect(report.renamed, isTrue);
      expect(report.steps.map((step) => p.basename(step.path)), [
        'brm-010-a.txt',
        'brm-010-a-renamed-1.txt',
        'brm-010-a-renamed-2.txt',
      ]);
      expect(report.mtimeStable, isTrue);
      // 人間が DATE_ADDED を照会するので、最後の名前と対照は残っている。
      expect(File(report.steps.last.path).existsSync(), isTrue);
      expect(File(report.control.path).existsSync(), isTrue);
      expect(File(report.steps.first.path).existsSync(), isFalse);
    });

    test('前回の残骸だけを消してから始める', () async {
      File(
        p.join(dir.path, 'brm-010-a-renamed-2.txt'),
      ).writeAsStringSync('old');
      final other = File(p.join(dir.path, 'keep.txt'))..writeAsStringSync('k');

      final report = await observeCreationTimes(
        dir.path,
        gap: const Duration(milliseconds: 50),
      );

      // 前回の最後の名前が残っていると、2回目の改名が名前の衝突になる。
      expect(report.renamed, isTrue);
      expect(other.existsSync(), isTrue);
    });
  });

  group('shell で置いた file', () {
    test('あれば2回改名して各段階を報告し、後片付けで消さない', () async {
      File(p.join(dir.path, shellMadeName)).writeAsStringSync('x');

      final report = await observeCreationTimes(
        dir.path,
        gap: const Duration(milliseconds: 50),
      );

      expect(report.shellSteps.map((step) => p.basename(step.path)), [
        'brm010-shell.txt',
        'brm010-shell-renamed-1.txt',
        'brm010-shell-renamed-2.txt',
      ]);
      expect(
        report.shellSteps.skip(1).map((step) => step.renameResult),
        everyElement(NativeRenameResult.success),
      );
      expect(
        File(p.join(dir.path, 'brm010-shell-renamed-2.txt')).existsSync(),
        isTrue,
      );
      expect(
        creationProbeReportText(report),
        contains('shell で置いた file: 2回目の改名の後: brm010-shell-renamed-2.txt'),
      );
    });

    test('無ければ無いと報告する', () async {
      final report = await observeCreationTimes(
        dir.path,
        gap: const Duration(milliseconds: 50),
      );

      expect(report.shellSteps, isEmpty);
      expect(
        creationProbeReportText(report),
        contains('shell で置いた file(brm010-shell.txt): 無し'),
      );
    });
  });

  group('報告', () {
    test('人間が貼る範囲と、まとめの3行を持つ', () async {
      final report = await observeCreationTimes(
        dir.path,
        gap: const Duration(milliseconds: 50),
      );

      final text = creationProbeReportText(report);

      expect(text, startsWith('=== 010:T04 作成時刻の観測 ==='));
      expect(text, contains('改名: 2回とも成功'));
      expect(text, contains('mtime が改名で変わらない: true'));
      expect(text, contains('btime が改名で変わらない: '));
      expect(text.trimRight(), endsWith('この出力をそのまま貼って返してください ==='));
    });

    test('btime が1度でも読めなければ、安定とも不安定とも言わない', () {
      final at = DateTime.utc(2026);
      CreationProbeStep step(DateTime? btime) => CreationProbeStep(
        label: 'x',
        path: '/x',
        at: at,
        times: StatxTimes(btime: btime, mtime: at),
      );
      final report = CreationProbeReport(
        directory: '/d',
        statxAvailable: true,
        steps: [step(at), step(null), step(at)],
        control: step(at),
      );

      expect(report.btimeStable, isNull);
    });

    test('btime が改名で変わったら、安定でないと報告する', () {
      final at = DateTime.utc(2026);
      CreationProbeStep step(DateTime btime) => CreationProbeStep(
        label: 'x',
        path: '/x',
        at: at,
        times: StatxTimes(btime: btime, mtime: at),
      );
      final report = CreationProbeReport(
        directory: '/d',
        statxAvailable: true,
        steps: [step(at), step(at), step(at.add(const Duration(seconds: 3)))],
        control: step(at),
      );

      expect(report.btimeStable, isFalse);
      expect(
        creationProbeReportText(report),
        contains('btime が改名で変わらない: false'),
      );
    });

    test('DATE_ADDED の照会 command は手順書と同じ形(PowerShell の引用を含む)', () {
      // 端末の shell へ渡す文字列に二重引用符を入れない(1回目の観測で
      // `no closing quote` になった)。PowerShell の単一引用符と、端末の `\` の escape。
      // 名前で探し `_data` も出す(2回目の観測で、場所で探すと「登録されていない」と
      // 「条件の誤り」を見分けられなかった)。
      expect(
        dateAddedQueryCommand(),
        '& "\$env:LOCALAPPDATA\\Android\\Sdk\\platform-tools\\adb.exe" shell '
        "'content query --uri content://media/external/file "
        '--projection _display_name:_data:date_added:date_modified:datetaken '
        r"--where _display_name\ LIKE\ \''brm%\'''",
      );
      expect(dateAddedQueryCommand(), isNot(contains(r'\"')));
    });
  });
}
