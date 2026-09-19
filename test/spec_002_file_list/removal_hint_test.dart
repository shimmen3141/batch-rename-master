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

Future<FileListController> _pump(WidgetTester tester) async {
  final controller = FileListController(files: [_entry('a.jpg')]);
  final shared = RemovalSelection();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
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
