// 013:T08 — 端末の app プロセスから、共有ストレージで**排他 rename が実際に効くか**を
// 観測する runner。
//
// **CI では走らない。** 端末が要る。走らせ方は
// `specs/013-safe-android-rename/tasks/T08-verify-device-coverage/manual-verification.md`
// にある。観測の中身は [probeDirectory] にあり、**host の test が同じ核を回している**
// (`test/spec_013_android_rename/storage_probe_test.dart`)。
//
// ## なぜ app の中から観測する必要があるか
//
// `013:T01` の spike S-2 は `adb shell`(shell uid)から観測した。**全ファイル
// アクセスを持つ app は別の mount view で `/storage` を見る**ので、同じ結果になる
// とは限らない(research-matrix「S-2で残った未検証」)。この file は**製品と同じ
// package・同じ権限・同じ mount view**で走るので、その差を埋める。
//
// ## なぜ製品の画面から観測できないか
//
// 製品経路は、目標名が実在すれば改名の前に気づいて別の経路へ行く
// (`DesktopRenameExecutor.rename` の実在確認)。したがって**画面をどう操作しても、
// 排他 rename が効いているかどうかで見え方は変わらない** — 劣化は設計どおり透過で
// ある。だから port を直接呼ぶ。

import 'package:batch_rename_master/data/file_source/android_storage_browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'storage_probe.dart';

/// 追加で観測したい directory を渡す口。
///
/// `--dart-define=BRM_PROBE_DIRS=/storage/XXXX-XXXX` のように渡す。列挙に現れない
/// 場所を人間が指定するためにある。
const _extraDirs = String.fromEnvironment('BRM_PROBE_DIRS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // **既定の `debugPrint` は throttle するので、長い報告が千切れて届く。**
  // 人間がそのまま貼れることがこの runner の成果物なので、同期出力へ替える。
  debugPrint = debugPrintSynchronously;

  testWidgets('共有ストレージの各 volume で排他 rename が効くかを観測する', (tester) async {
    // **報告と後片付けを `finally` で保証する。** 個別の `await` を囲む形は、
    // `await` を1つ足すたびに漏れる — 独立review attempt 1 で native の呼び出しを
    // 囲んだところ、attempt 2 で列挙(`androidProbeTargets`)に同じ穴が見つかった。
    // ここで落ちると**人間は1行も報告を得られず、端末に残骸が残る**。
    final rows = <ProbeRow>[];
    // **app から見た `/storage` を先に控える。** 取り外し可能な volume が
    // 「無い」のか「見えない」のかは、これが無いと区別できない(項目1・項目7)。
    var storageView = '(取得できなかった)';
    try {
      storageView = await storageViewOf();
      final targets = await androidProbeTargets(extraDirs: _extraDirs);
      for (final target in targets) {
        try {
          rows.add(await probeDirectory(target));
        } catch (error) {
          rows.add(ProbeRow.skipped(target, '観測中に例外: $error'));
        }
      }
    } finally {
      // **報告を先に出す。** `finally` の中で報告より前に filesystem 操作を置くと、
      // その1行が新しい窓になる(独立review attempt 3 の P3-5)。
      debugPrint('$storageView\n${reportOf(rows)}');
      await cleanUpProbeDirectory(
        mediaProbeDirectoryOf(const AndroidStorageBrowser().primaryRoot),
      );
    }

    // **フラグについて何も分からなければ失敗にする。** 「対象が無かった」
    // 「どこも書けなかった」を「問題なし」と読ませない(`013:T07` の listNames と
    // 同じ型の取り違え)。`observed` ではなく `answersTheQuestion` で数えるのは、
    // `permissionDenied` の行が収穫ゼロだからである(P2-6)。
    expect(
      rows.where((row) => row.answersTheQuestion).isNotEmpty,
      isTrue,
      reason: '排他 rename の可否が分かった場所が1つもない。上の出力の理由を読むこと',
    );

    final broken = rows.where((row) => row.defect != null).toList();
    expect(
      broken,
      isEmpty,
      reason: broken.map((row) => '${row.directory}: ${row.defect}').join('\n'),
    );
  });
}
