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

    test('書けない場所は skip として返し、例外を投げない', () async {
      final missing = p.join(dir.path, 'no-such-directory');

      final row = await probeDirectory(ProbeTarget(missing, 'host'));

      expect(row.observed, isFalse);
      expect(row.skipReason, isNotNull);
      // **skip を「問題なし」と混同しない。** defect は立てないが observed も false。
      expect(row.defect, isNull);
    });
  });

  group('defect の判定', () {
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

    test('劣化(fallbackRequired)は欠陥ではない', () {
      expect(
        rowWith(exclusive: NativeRenameResult.fallbackRequired).defect,
        isNull,
      );
    });

    test('**目標名が置換されたら欠陥**(005 INV-002)', () {
      expect(rowWith(observedTargetBody: sourceBody).defect, contains('目標名'));
    });

    test('**目標名が消えていても欠陥**(置換の一形態を見逃さない)', () {
      expect(rowWith(observedTargetBody: null).defect, contains('目標名'));
    });

    test('**改名されていないのに source が変わったら欠陥**(005 REQ-016)', () {
      expect(rowWith(observedSourceBody: null).defect, contains('source'));
    });

    test('**対照が置換しなければ欠陥**(因果を読めない)', () {
      expect(
        rowWith(
          control: NativeRenameResult.io,
          observedControlBody: targetBody,
        ).defect,
        contains('対照'),
      );
    });

    test('対照が success でも置換していなければ欠陥', () {
      expect(rowWith(observedControlBody: targetBody).defect, contains('対照'));
    });

    test('想定外の結果は欠陥', () {
      expect(rowWith(exclusive: NativeRenameResult.io).defect, contains('想定外'));
    });

    test('書けない場所(permissionDenied)は欠陥にしない', () {
      expect(
        rowWith(
          exclusive: NativeRenameResult.permissionDenied,
          observedTargetBody: targetBody,
        ).defect,
        isNull,
      );
    });

    test('skip は欠陥にしない', () {
      expect(
        ProbeRow.skipped(const ProbeTarget('/x', 'test'), '理由').defect,
        isNull,
      );
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
