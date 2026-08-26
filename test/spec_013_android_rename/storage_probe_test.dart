// `013:T08` の観測 harness を host で回す。
//
// **人間へ実機を依頼する前に、harness 自体が働くことを CI で確かめる**ためにある
// (依頼して初めて harness の誤りに気づくと、実機の時間を捨てる。
// `development-findings/2026-08-25-manual-preconditions-were-not-executable-on-the-verification-device.md`)。
//
// **ここが確かめるのは harness であって、Android の挙動ではない。** Linux の ext4 は
// `RENAME_NOREPLACE` を解釈するので、この test の PASS は「Android でも効く」を
// 一切意味しない。それは端末でしか分からない。

import 'dart:io';

import 'package:batch_rename_master/data/file_source/android_storage_browser.dart';
import 'package:batch_rename_master/data/rename_exec/native_exclusive_rename.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/storage_probe.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brm-t08-host-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('probeDirectory', () {
    test('実 filesystem を観測し、保証が破れていなければ defect は無い', () async {
      final row = await probeDirectory(ProbeTarget(dir.path, 'host'));

      expect(row.observed, isTrue);
      expect(row.defect, isNull);
      // Linux の ext4 はフラグを解釈する。**Android がそうだとは言っていない。**
      expect(row.exclusive, NativeRenameResult.nameConflict);
      expect(row.observedTargetBody, targetBody);
      expect(row.observedSourceBody, sourceBody);
      // 対照が実際に置換していること。ここが崩れると因果を読めない。
      expect(row.control, NativeRenameResult.success);
      expect(row.observedControlBody, sourceBody);
    });

    test('観測に使った file を残さない', () async {
      await probeDirectory(ProbeTarget(dir.path, 'host'));

      final left = dir
          .listSync()
          .map((entity) => p.basename(entity.path))
          .where((name) => name.startsWith(probePrefix))
          .toList();
      expect(left, isEmpty);
    });

    test('**排他 rename が投げても skip として返し、後片付けする**(P1-1)', () async {
      // native の symbol 解決に失敗する経路。**この構成は端末で一度も走らせて
      // いない**ので、投げたときに報告が消えないことを host で固定する。
      final row = await probeDirectory(
        ProbeTarget(dir.path, 'host'),
        exclusiveRename: (source, destination) =>
            throw ArgumentError('native を呼べない'),
      );

      expect(row.observed, isFalse);
      expect(row.skipReason, contains('排他 rename を呼べない'));
      expect(row.defect, isNull);
      // **残骸を残さない。** 端末では共有ストレージに残る。
      final left = dir
          .listSync()
          .map((entity) => p.basename(entity.path))
          .where((name) => name.startsWith(probePrefix))
          .toList();
      expect(left, isEmpty);
    });

    test('**対照が投げても後片付けする**(後片付けを finally に置いた)', () async {
      final row = await probeDirectory(
        ProbeTarget(dir.path, 'host'),
        plainRename: (source, destination) async =>
            throw ArgumentError('通常 rename を呼べない'),
      );

      // 対照が取れなかったことは defect が拾う。
      expect(row.defect, contains('対照'));
      final left = dir
          .listSync()
          .map((entity) => p.basename(entity.path))
          .where((name) => name.startsWith(probePrefix))
          .toList();
      expect(left, isEmpty);
    });

    test('書けない場所は skip として返し、例外を投げない', () async {
      final missing = p.join(dir.path, 'no-such-directory');

      final row = await probeDirectory(ProbeTarget(missing, 'host'));

      expect(row.observed, isFalse);
      expect(row.skipReason, isNotNull);
      // **skip を「問題なし」と混同しない。** defect は立てないが observed も false。
      expect(row.defect, isNull);
    });
  });

  // **升目で回す。** 1件ずつ足す形は、隣が空いたまま残る — attempt 1 で
  // `fallbackRequired` × 目標名 を足したら、attempt 2 で `fallbackRequired` × 対照 が
  // 空いていた(独立review attempt 2 の P2-9)。**結果 × 破れ方**を表にして埋める。
  group('defect の判定(結果 × 破れ方)', () {
    ProbeRow rowWith({
      NativeRenameResult exclusive = NativeRenameResult.nameConflict,
      String? observedTargetBody = targetBody,
      String? observedSourceBody = sourceBody,
      NativeRenameResult? control = NativeRenameResult.success,
      String? observedControlBody = sourceBody,
    }) => ProbeRow(
      target: const ProbeTarget('/somewhere', 'test'),
      exclusive: exclusive,
      observedTargetBody: observedTargetBody,
      observedSourceBody: observedSourceBody,
      control: control,
      observedControlBody: observedControlBody,
    );

    /// **観測できた結果**の3種。この3つ以外は「想定外」で捕まる。
    const results = [
      NativeRenameResult.nameConflict,
      NativeRenameResult.fallbackRequired,
      NativeRenameResult.permissionDenied,
    ];

    /// 実体の破れ方。**どの結果でも欠陥である**(005 INV-002 / REQ-016)。
    final bodyBreakages = <String, ProbeRow Function(NativeRenameResult)>{
      '目標名が置換された': (result) =>
          rowWith(exclusive: result, observedTargetBody: sourceBody),
      '目標名が消えた': (result) =>
          rowWith(exclusive: result, observedTargetBody: null),
      'source が変わった': (result) =>
          rowWith(exclusive: result, observedSourceBody: 'changed'),
      'source が消えた': (result) =>
          rowWith(exclusive: result, observedSourceBody: null),
    };

    /// 対照の破れ方。**書けない場所では免除する**(そこでは対照も失敗して当然)。
    final controlBreakages = <String, ProbeRow Function(NativeRenameResult)>{
      '対照が失敗した': (result) => rowWith(
        exclusive: result,
        control: NativeRenameResult.io,
        observedControlBody: targetBody,
      ),
      '対照が取れなかった': (result) =>
          rowWith(exclusive: result, control: null, observedControlBody: null),
      '対照が success でも置換していない': (result) =>
          rowWith(exclusive: result, observedControlBody: targetBody),
    };

    for (final result in results) {
      test('${result.name}: 破れていなければ欠陥にしない', () {
        expect(rowWith(exclusive: result).defect, isNull);
      });

      for (final entry in bodyBreakages.entries) {
        test('${result.name} × ${entry.key} は欠陥', () {
          expect(entry.value(result).defect, isNotNull);
        });
      }

      for (final entry in controlBreakages.entries) {
        final exempt = result == NativeRenameResult.permissionDenied;
        test('${result.name} × ${entry.key} は'
            '${exempt ? '欠陥にしない(書けない場所なので免除)' : '欠陥'}', () {
          final defect = entry.value(result).defect;
          expect(defect, exempt ? isNull : contains('対照'));
        });
      }
    }

    test('想定外の結果は欠陥', () {
      expect(rowWith(exclusive: NativeRenameResult.io).defect, contains('想定外'));
      expect(
        rowWith(exclusive: NativeRenameResult.success).defect,
        contains('想定外'),
      );
    });

    test('skip は欠陥にしない', () {
      expect(
        ProbeRow.skipped(const ProbeTarget('/x', 'test'), '理由').defect,
        isNull,
      );
    });
  });

  group('answersTheQuestion(runner の guard が数える対象)', () {
    ProbeRow rowOf(NativeRenameResult? exclusive) => exclusive == null
        ? ProbeRow.skipped(const ProbeTarget('/x', 'test'), '理由')
        : ProbeRow(
            target: const ProbeTarget('/x', 'test'),
            exclusive: exclusive,
            observedTargetBody: targetBody,
            observedSourceBody: sourceBody,
            control: NativeRenameResult.success,
            observedControlBody: sourceBody,
          );

    test('効いた場合と劣化した場合だけ、フラグについて分かったと数える', () {
      expect(rowOf(NativeRenameResult.nameConflict).answersTheQuestion, isTrue);
      expect(
        rowOf(NativeRenameResult.fallbackRequired).answersTheQuestion,
        isTrue,
      );
    });

    test('**書けない場所と skip は数えない**(緑でも収穫ゼロなので)', () {
      expect(
        rowOf(NativeRenameResult.permissionDenied).answersTheQuestion,
        isFalse,
      );
      expect(rowOf(null).answersTheQuestion, isFalse);
      // observed とは別物である。permissionDenied は「観測できた」ではある。
      expect(rowOf(NativeRenameResult.permissionDenied).observed, isTrue);
    });
  });

  group('cleanUpProbeDirectory', () {
    test('空の directory は消す', () async {
      final target = Directory(p.join(dir.path, 'empty'));
      await target.create();

      await cleanUpProbeDirectory(target.path);

      expect(await target.exists(), isFalse);
    });

    test('**中身があれば消さない**(元からあった場所を巻き添えにしない)', () async {
      final target = Directory(p.join(dir.path, 'not-empty'));
      await target.create();
      await File(p.join(target.path, 'keep.txt')).writeAsString('keep');

      await cleanUpProbeDirectory(target.path);

      expect(await target.exists(), isTrue);
    });

    test('存在しない directory でも例外を投げない', () async {
      await cleanUpProbeDirectory(p.join(dir.path, 'missing'));
    });
  });

  group('androidProbeTargets', () {
    test('列挙された volume の root と、実在する Download を観測対象にする', () async {
      final volume = Directory(p.join(dir.path, 'volume'));
      await Directory(p.join(volume.path, 'Download')).create(recursive: true);

      final targets = await androidProbeTargets(
        browser: AndroidStorageBrowser(
          primaryRoot: volume.path,
          volumesDirectory: p.join(dir.path, 'no-volumes'),
        ),
      );

      final directories = targets.map((target) => target.directory).toList();
      expect(directories, contains(volume.path));
      expect(directories, contains(p.join(volume.path, 'Download')));
    });

    test('実在しない Download は観測対象にしない', () async {
      final volume = Directory(p.join(dir.path, 'volume'));
      await volume.create(recursive: true);

      final targets = await androidProbeTargets(
        browser: AndroidStorageBrowser(
          primaryRoot: volume.path,
          volumesDirectory: p.join(dir.path, 'no-volumes'),
        ),
      );

      expect(
        targets.map((target) => target.directory),
        isNot(contains(p.join(volume.path, 'Download'))),
      );
    });

    test('取り外し可能な volume も観測対象にする(項目7はここで埋まる)', () async {
      final volumes = Directory(p.join(dir.path, 'storage'));
      final sdCard = Directory(p.join(volumes.path, '1234-ABCD'));
      await sdCard.create(recursive: true);
      final primary = Directory(p.join(dir.path, 'primary'));
      await primary.create(recursive: true);

      final targets = await androidProbeTargets(
        browser: AndroidStorageBrowser(
          primaryRoot: primary.path,
          volumesDirectory: volumes.path,
        ),
      );

      expect(targets.map((target) => target.directory), contains(sdCard.path));
    });

    test('**非FUSE の対照(app の内部領域)も観測対象にする**(項目4)', () async {
      final primary = Directory(p.join(dir.path, 'primary'));
      await primary.create(recursive: true);

      final targets = await androidProbeTargets(
        browser: AndroidStorageBrowser(
          primaryRoot: primary.path,
          volumesDirectory: p.join(dir.path, 'no-volumes'),
        ),
      );

      expect(
        targets.map((target) => target.directory),
        contains(Directory.systemTemp.path),
      );
    });

    test('**辿れない volume があっても投げず、他の観測対象を返す**(P1-2)', () async {
      // `/storage` には辿れない entry(取り外し済み・別 user・stale mount)が
      // 並びうる。`Directory.exists()` はそこで **`false` を返さず投げる**。
      final volume = Directory(p.join(dir.path, 'unreadable'));
      await volume.create(recursive: true);
      final result = await Process.run('chmod', ['000', volume.path]);
      expect(result.exitCode, 0, reason: 'chmod できないと前提が崩れる');
      addTearDown(() => Process.run('chmod', ['700', volume.path]));

      final targets = await androidProbeTargets(
        browser: AndroidStorageBrowser(
          primaryRoot: volume.path,
          volumesDirectory: p.join(dir.path, 'no-volumes'),
        ),
      );

      // **報告をゼロにしない。** root と非FUSE の対照は残る。
      final directories = targets.map((target) => target.directory).toList();
      expect(directories, contains(volume.path));
      expect(directories, contains(Directory.systemTemp.path));
    });

    test('--dart-define で足した場所を観測対象にする', () async {
      final primary = Directory(p.join(dir.path, 'primary'));
      await primary.create(recursive: true);

      final targets = await androidProbeTargets(
        browser: AndroidStorageBrowser(
          primaryRoot: primary.path,
          volumesDirectory: p.join(dir.path, 'no-volumes'),
        ),
        extraDirs: '/storage/1234-ABCD, ',
      );

      expect(
        targets.map((target) => target.directory),
        contains('/storage/1234-ABCD'),
      );
    });
  });

  group('reportOf', () {
    test('観測できなかった場所は理由を出す', () async {
      final report = reportOf([
        ProbeRow.skipped(const ProbeTarget('/x', 'test'), '書けない'),
      ]);

      expect(report, contains('観測できず: 書けない'));
    });

    test('保証が破れた行はそう出す', () async {
      final report = reportOf([
        ProbeRow(
          target: const ProbeTarget('/x', 'test'),
          exclusive: NativeRenameResult.nameConflict,
          observedTargetBody: sourceBody,
          observedSourceBody: sourceBody,
          control: NativeRenameResult.success,
          observedControlBody: sourceBody,
        ),
      ]);

      expect(report, contains('保証が破れた'));
    });
  });
}
