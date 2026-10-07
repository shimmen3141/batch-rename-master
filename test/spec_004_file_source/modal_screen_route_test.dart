// 015:T04 選択画面(app 内 browser・写真・動画)は下からせり上がって開き、閉じると下へ下がる
// (2026-10-07 の開発者の決定)。リネーム画面は動かさない。
import 'dart:io';

import 'package:batch_rename_master/ui/file_source/modal_screen_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _renameKey = Key('rename-screen');
const _modalKey = Key('modal-screen');

/// リネーム画面に見立てた画面を出し、[ModalScreenRoute] を開く準備をする。
Future<NavigatorState> _pumpHome(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: const Scaffold(key: _renameKey, body: Text('rename')),
    ),
  );
  return navigatorKey.currentState!;
}

ModalScreenRoute<String> _route() => ModalScreenRoute<String>(
  builder: (_) => const Scaffold(key: _modalKey, body: Text('modal')),
);

void main() {
  testWidgets('開くときは下からせり上がり、リネーム画面は動かない', (tester) async {
    final navigator = await _pumpHome(tester);
    final renameBefore = tester.getRect(find.byKey(_renameKey));

    navigator.push(_route());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final midway = tester.getRect(find.byKey(_modalKey));
    expect(midway.top, greaterThan(0), reason: 'まだ上がりきっていない');
    expect(midway.top, lessThan(800), reason: '画面の下から出てきている');
    expect(midway.left, 0, reason: '横には動かさない');
    expect(midway.size, const Size(400, 800), reason: '全画面のまま');
    expect(
      tester.getRect(find.byKey(_renameKey)),
      renameBefore,
      reason: 'リネーム画面は縮んだり動いたりしない',
    );

    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_modalKey)).top, 0);
  });

  testWidgets('閉じるときは下へ下がり、リネーム画面は動かない', (tester) async {
    final navigator = await _pumpHome(tester);
    final renameBefore = tester.getRect(find.byKey(_renameKey));
    final result = navigator.push(_route());
    await tester.pumpAndSettle();

    navigator.pop('done');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final midway = tester.getRect(find.byKey(_modalKey));
    expect(midway.top, greaterThan(0), reason: '下がっている途中');
    expect(midway.left, 0);
    expect(tester.getRect(find.byKey(_renameKey)), renameBefore);

    await tester.pumpAndSettle();
    expect(find.byKey(_modalKey), findsNothing);
    expect(await result, 'done', reason: '閉じ方の結果はそのまま返る');
  });

  test('開くのに 300ms、閉じるのに 250ms かける', () {
    final route = _route();
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 250));
  });

  testWidgets('「アニメーションを削除」が有効なら動かさずに出す', (tester) async {
    final navigator = await _pumpHome(tester, disableAnimations: true);

    navigator.push(_route());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.getRect(find.byKey(_modalKey)).top, 0);
  });

  // main.dart の結線は widget test で開けない(実際の platform を使う)ので、
  // 選択画面を開くすべての箇所がこの route を使っていることを source で確かめる。
  test('リネーム画面から選択画面を開く箇所はすべて ModalScreenRoute を使う', () {
    final main = File('lib/main.dart').readAsStringSync();
    final screens = RegExp(
      r'=> (StorageBrowserView|MediaPickerView)\(',
    ).allMatches(main);
    final routed = RegExp(
      r'(\w+)\(\s*builder: \(_\) => (StorageBrowserView|MediaPickerView)\(',
    ).allMatches(main).toList();

    expect(screens.length, 3, reason: 'browser・開き直し・写真・動画');
    expect(routed.length, screens.length);
    for (final match in routed) {
      expect(match.group(1), 'ModalScreenRoute', reason: match.group(2));
    }
  });
}
