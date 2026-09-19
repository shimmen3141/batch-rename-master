// 除去のための選択モード(002 REQ-018)を操作する共通手順。
//
// **testごとに書き写さない。** `008:T28` で「行の × を押す」から
// 「モードへ入る → 行を選ぶ → 外す」へ変わったので、経路が1か所に無いと
// 次に変わったとき一部のtestだけ古い前提のまま残る。
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 一覧のケバブメニューを開く(`008:T29`)。
Future<void> openListMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(listMenuKey));
  await tester.pumpAndSettle();
}

/// 長押しに依存しない入口(REQ-018 (b))からモードへ入る。
///
/// `008:T29` でヘッダのbuttonからケバブの項目へ移した。
Future<void> enterRemovalMode(WidgetTester tester) async {
  await openListMenu(tester);
  await tester.tap(find.byKey(removalModeEnterKey));
  await tester.pumpAndSettle();
}

/// ケバブの「すべて選択」。
Future<void> selectAllForRemoval(WidgetTester tester) async {
  await openListMenu(tester);
  await tester.tap(find.byKey(menuSelectAllKey));
  await tester.pumpAndSettle();
}

/// ケバブの「すべてをリネーム対象から外す」(旧 `一覧を空にする`)。
Future<void> clearAllFiles(WidgetTester tester) async {
  await openListMenu(tester);
  await tester.tap(find.byKey(menuClearAllKey));
  await tester.pumpAndSettle();
}

/// 選択件数の表示(`〇件選択中`)。モードでなければ `null`。
String? removalModeCountText(WidgetTester tester) {
  final found = find.byKey(removalModeCountKey);
  if (found.evaluate().isEmpty) return null;
  return tester.widget<Text>(found).data;
}

/// [handle] の行を外す候補にする(またはやめる)。
Future<void> toggleRemovalMark(WidgetTester tester, String handle) async {
  await tester.tap(find.byKey(removalMarkKeyOf(handle)));
  await tester.pump();
}

/// 選んだ行をまとめて外す。**モードは抜ける**(REQ-018)。
Future<void> removeMarked(WidgetTester tester) async {
  await tester.tap(find.byKey(removalModeRemoveKey));
  await tester.pumpAndSettle();
}

/// 1件だけ外す(旧・行の × に相当する経路)。
Future<void> removeOneFile(WidgetTester tester, String handle) async {
  await enterRemovalMode(tester);
  await toggleRemovalMark(tester, handle);
  await removeMarked(tester);
}
