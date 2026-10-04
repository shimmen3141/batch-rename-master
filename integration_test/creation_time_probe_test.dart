// 010:T04 — 端末の app プロセスから、このアプリの改名で「ファイルがこの端末に
// 作られた時刻」が変わるかを観測する runner。
//
// **CI では走らない。** 端末が要る。走らせ方は
// `specs/010-photo-video-source/tasks/T04-verify-creation-time-stability/manual-verification.md`
// にある。観測の中身は `creation_time_probe.dart` にあり、host の test が同じ核を回している
// (`test/spec_010_photo_video_source/creation_time_probe_test.dart`)。
//
// 製品と同じ package・同じ権限・同じ mount view で走らせるために app の中から観測する
// (`013:T08` と同じ理由)。

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'creation_time_probe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 既定の `debugPrint` は throttle するので、長い報告が千切れて届く。
  debugPrint = debugPrintSynchronously;

  testWidgets('改名の前後で作成時刻が変わるかを観測する', (tester) async {
    // **失敗も報告として出す。** 2回目の観測では書き込みが権限で落ち、報告が1行も
    // 出ないまま null の扱いで2つ目の例外になった。
    Object? failure;
    final report = await tester.runAsync(() async {
      try {
        return await observeCreationTimes(deviceCreationProbeDirectory);
      } catch (error) {
        failure = error;
        return null;
      }
    });
    if (report == null) {
      debugPrint('=== 010:T04 作成時刻の観測: 途中で失敗した ===\n$failure');
      fail('観測が途中で失敗した: $failure');
    }
    debugPrint(creationProbeReportText(report));
    debugPrint('--- DATE_ADDED を読む command(このあと手で実行する)');
    debugPrint(dateAddedQueryCommand());

    // 改名できなければ、何も観測していない。
    expect(report.renamed, isTrue, reason: '改名に失敗した。上の出力を読むこと');
  });
}
