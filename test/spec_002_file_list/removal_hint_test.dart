// 008:T30 外すアイコンへ重ねる補足(吹き出し)。
//
// 002 REQ-018 は文言・配色・レイアウトを縛らないので、ここが固定するのは
// **要望として受領した振る舞い**である — モード中だけ出る、ツノが外すアイコンを
// 指す、帯に重なる、閉じられる、放っておくと消える、モードをやめたら即消える。
//
// **帯と一覧を製品と同じ組み合わせで描く。** 吹き出しは一覧ヘッダが `Overlay` へ
// 出すが、「帯に重なっている」ことは帯が無いと確かめられない。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/removal_hint.dart';
import 'package:batch_rename_master/ui/file_list/removal_selection.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'removal_mode.dart';

FileEntry _entry(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 2),
  size: 10,
  sourceHandle: 'h:$name',
  sourceLocation: 'Camera',
);

Future<FileListController> _pump(
  WidgetTester tester, {
  double scale = 1.0,
}) async {
  final controller = FileListController(files: [_entry('a.jpg')]);
  final shared = RemovalSelection();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        // **composition root と同じ組み立てにする**(`main.dart`)。吹き出しは帯へ
        // 重なるので、上に何があるかで収まり方が変わる。
        appBar: AppBar(title: const Text('一括リネーム')),
        body: Column(
          children: [
            FileSourceBar(
              source: FakeFileSource(),
              controller: controller,
              permission: const UnrestrictedStoragePermission(),
              kinds: FileKind.values,
              removalSelection: shared,
            ),
            Expanded(
              child: FileListView(
                controller: controller,
                removalSelection: shared,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return controller;
}

/// ツノが上を向いているか。
bool _tailPointsUp(WidgetTester tester) =>
    (tester.widget<CustomPaint>(find.byKey(removalHintTailKey)).painter
            as RemovalHintTailPainter)
        .pointsUp;

void main() {
  testWidgets('モード中だけ出て、ツノが外すアイコンの中心を指す', (tester) async {
    await _pump(tester);
    expect(find.byKey(removalHintKey), findsNothing);

    await enterRemovalMode(tester);

    expect(find.byKey(removalHintKey), findsOneWidget);
    expect(find.text(removalHintText), findsOneWidget);
    // **ツノがアイコンを指していること**を実測する。帯とヘッダは別の widget なので、
    // 共有した数(`header_metrics.dart`)がずれたらここで落ちる。
    expect(
      tester.getCenter(find.byKey(removalHintTailKey)).dx,
      tester.getCenter(find.byKey(removalModeRemoveKey)).dx,
    );
    // **ファイルそのものは消えないことを言い続ける**(005 / 013 の境界)。
    expect(removalHintText, contains('削除されません'));
    // 上に出ているときのツノは下を向く。
    expect(_tailPointsUp(tester), isFalse);
  });

  testWidgets('吹き出しは帯に重なり、アイコンのすぐ上に立つ(008:T30 2回目の実機確認)', (tester) async {
    // 帯の中へ収めていたときは**ツノがアイコンから遠かった**(帯の高さのぶん離れる)。
    // 重ねる形にしたので、ツノの先はアイコンの上端に接する。
    await _pump(tester);
    await enterRemovalMode(tester);

    final bar = tester.getRect(find.byKey(sourceBarKey));
    final hint = tester.getRect(find.byKey(removalHintKey));
    final tail = tester.getRect(find.byKey(removalHintTailKey));
    final icon = tester.getRect(find.byKey(removalModeRemoveKey));

    // 帯の内側まで食い込んでいる(帯の中に収まっていたときは起こらない)。
    expect(hint.top, lessThan(bar.bottom));
    // ツノの先とアイコンの上端の隙間は数px以内。
    expect(icon.top - tail.bottom, lessThan(8));
    expect(icon.top - tail.bottom, greaterThanOrEqualTo(0));
  });

  testWidgets('狭い画面と大きい文字でも画面の中に収まり、閉じる操作が押せる', (tester) async {
    // **2回ともここで壊れた。**
    // 1回目: 円は箱の角から外へ出るので、吹き出しの右端を画面の余白ぴったりに置くと
    //        円が画面外へ行き、**押せない閉じる操作**になった。
    // 2回目: 箱の高さは文字倍率で伸びるので、上へ伸ばし続けると倍率2.0で円が、
    //        倍率3.0では**本文ごと**画面の上端より外へ出た(独立review attempt 2 の P1)。
    //        誤解を防ぐための注記が、いちばん助けが要る設定で消えていた。
    const height = 800.0;
    for (final width in [320.0, 411.0, 800.0]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        await tester.binding.setSurfaceSize(Size(width, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pump(tester, scale: scale);
        await enterRemovalMode(tester);
        // 向きを決めるのに1 frame 測るので、落ち着くまで回す。
        await tester.pump();

        final where = '幅 $width / 文字 $scale';
        final close = tester.getRect(find.byKey(removalHintCloseKey));
        final hint = tester.getRect(find.byKey(removalHintKey));
        for (final rect in [close, hint]) {
          expect(rect.left, greaterThanOrEqualTo(0), reason: where);
          expect(rect.right, lessThanOrEqualTo(width), reason: where);
          expect(rect.top, greaterThanOrEqualTo(0), reason: where);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: where);
        }
        // **押せること**まで見る(枠の外や画面の外の円は hit test に載らない)。
        await tester.tap(find.byKey(removalHintCloseKey));
        await tester.pump();
        expect(find.byKey(removalHintKey), findsNothing, reason: where);
      }
    }
  });

  testWidgets('上に収まらないときはアイコンの下へ回る(008:T30 independent review attempt 2)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, scale: 3.0);
    await enterRemovalMode(tester);
    await tester.pump();

    final icon = tester.getRect(find.byKey(removalModeRemoveKey));
    final hint = tester.getRect(find.byKey(removalHintKey));
    final tail = tester.getRect(find.byKey(removalHintTailKey));

    // 箱はアイコンより下にあり、ツノは箱の上(= アイコン側)にある。
    expect(hint.top, greaterThan(icon.top));
    expect(tail.bottom, lessThanOrEqualTo(hint.top));
    // ツノは向きが変わってもアイコンを指したままである。
    expect(tail.center.dx, icon.center.dx);
    // **ツノが上を向いている。** 描いた結果からは読めないので painter を見る。
    expect(_tailPointsUp(tester), isTrue);
  });

  testWidgets('面もツノも同じ色で塗る(境界線を見せない)', (tester) async {
    await _pump(tester);
    await enterRemovalMode(tester);

    final colors = appDarkTheme().extension<AppColors>()!;
    final box = tester.widget<Container>(find.byKey(removalHintKey));
    expect((box.decoration as BoxDecoration).color, colors.primary);
    // **枠線を引かない。** 引くと箱とツノの継ぎ目が線になって見える
    // (2026-09-19 の2回目の実機確認)。
    expect((box.decoration as BoxDecoration).border, isNull);
  });

  testWidgets('閉じる操作を押すとその瞬間に消える', (tester) async {
    await _pump(tester);
    await enterRemovalMode(tester);
    expect(find.byKey(removalHintCloseKey), findsOneWidget);

    await tester.tap(find.byKey(removalHintCloseKey));
    await tester.pump();

    expect(find.byKey(removalHintKey), findsNothing);
    // **モードは続く。** 閉じたのは補足だけである。
    expect(removalModeCountText(tester), isNotNull);
  });

  testWidgets('放っておくと3秒でフェードアウトして消える', (tester) async {
    await _pump(tester);
    await enterRemovalMode(tester);
    expect(find.byKey(removalHintKey), findsOneWidget);

    // **3秒までは残る。**
    await tester.pump(removalHintLifetime - const Duration(milliseconds: 100));
    expect(find.byKey(removalHintKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byKey(removalHintKey), findsNothing);
    expect(removalModeCountText(tester), isNotNull);
  });

  testWidgets('モードをやめたらその瞬間に消える(フェードを待たない)', (tester) async {
    await _pump(tester);
    await enterRemovalMode(tester);

    await tester.tap(find.byKey(removalModeExitKey));
    // **フェードを待たない。** `Overlay` からの取り外しは次の frame で効くので
    // pump を2回回すが、時間は進めない(目には即時である)。
    await tester.pump();
    await tester.pump();

    expect(find.byKey(removalHintKey), findsNothing);
  });

  testWidgets('入り直すとまた出る', (tester) async {
    await _pump(tester);
    await enterRemovalMode(tester);
    await tester.tap(find.byKey(removalHintCloseKey));
    await tester.pump();
    await tester.tap(find.byKey(removalModeExitKey));
    await tester.pumpAndSettle();

    await enterRemovalMode(tester);

    expect(find.byKey(removalHintKey), findsOneWidget);
  });
}
