// VER-001/002(004 T9): 手動並び替えとカスタム順の提示条件(002 REQ-014)。
// 並び順が生成後名に影響するのは連番トークンがあるときだけなので、
// 無いときはドラッグハンドルと「カスタム順」の選択肢を出さない。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 1, 1), size: 0);

const _withSequence = RenameRule([
  LiteralToken('IMG_'),
  SequenceToken(start: 1, digits: 2, increment: 1),
]);
const _withoutSequence = RenameRule([OriginalNameToken(), LiteralToken('_v2')]);

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

void main() {
  group('REQ-014: manualOrderMatters(状態層)', () {
    test('例16: 連番が無いルールでは false', () {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: _withoutSequence,
      );
      expect(c.manualOrderMatters, isFalse);
    });

    test('連番があるルールでは true', () {
      final c = FileListController(files: [_f('a.txt')], rule: _withSequence);
      expect(c.manualOrderMatters, isTrue);
    });

    test('例17: ルールの変更に追随する', () {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: _withoutSequence,
      );
      expect(c.manualOrderMatters, isFalse);

      c.setRule(_withSequence);
      expect(c.manualOrderMatters, isTrue);

      c.setRule(_withoutSequence);
      expect(c.manualOrderMatters, isFalse);
    });

    test('空ルールでは false', () {
      final c = FileListController(files: [_f('a.txt')]);
      expect(c.manualOrderMatters, isFalse);
    });
  });

  group('REQ-014: 提示(ウィジェット)', () {
    testWidgets('例16: 連番が無いとドラッグハンドルとカスタム順を出さない', (tester) async {
      await _pump(
        tester,
        FileListController(files: [_f('a.txt')], rule: _withoutSequence),
      );

      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.text('カスタム順'), findsNothing);
    });

    testWidgets('連番があると両方出る', (tester) async {
      await _pump(
        tester,
        FileListController(files: [_f('a.txt')], rule: _withSequence),
      );

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      expect(find.text('カスタム順'), findsOneWidget);
    });

    testWidgets('例17: ルールに連番を足すと現れ、外すと消える', (tester) async {
      final c = FileListController(
        files: [_f('a.txt')],
        rule: _withoutSequence,
      );
      await _pump(tester, c);
      expect(find.byIcon(Icons.drag_handle), findsNothing);

      c.setRule(_withSequence);
      await tester.pump();
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      expect(find.text('カスタム順'), findsOneWidget);

      c.setRule(_withoutSequence);
      await tester.pump();
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.text('カスタム順'), findsNothing);
    });

    testWidgets('ソート(名前順・日時順・サイズ順)は連番の有無に関わらず常に出る', (tester) async {
      await _pump(
        tester,
        FileListController(files: [_f('a.txt')], rule: _withoutSequence),
      );

      for (final label in ['元の名前順', '作成日時順', '更新日時順', 'サイズ順']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });
}
