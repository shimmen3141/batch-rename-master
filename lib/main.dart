import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/rename_engine.dart';
import 'data/rule_store/shared_preferences_rule_store.dart';
import 'ui/file_list/file_list_controller.dart';
import 'ui/rule_builder/persistent_rule_controller.dart';
import 'ui/rule_builder/rule_builder_workspace.dart';
import 'ui/rule_builder/rule_controller.dart';
import 'ui/theme/app_theme.dart';

/// デモ/プレビュー用のアプリ入口。
///
/// サンプルの [FileEntry] 一覧で 002(ファイルリスト)・003(ルールビルダー)・
/// リアルタイムプレビューを組み上げる。ルールは 007 の永続化(`shared_preferences`)
/// と結線し、**前回のルールを次回起動時に復元**する。実ファイルの読み込み(004)・
/// リネーム実行(005)は未配線のため、扱うのはサンプルデータのみ。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // 前回ルールを復元し、以降の変更を自動保存するセッションを起動する。
  final session = await PersistentRuleController.restore(
    SharedPreferencesRuleStore(prefs),
  );
  runApp(DemoApp(ruleController: session.controller));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.ruleController});

  /// 永続化から復元済みのルールコントローラ(変更は自動保存される)。
  final RuleController ruleController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一括リネーム（デモ）',
      debugShowCheckedModeBanner: false,
      theme: appDarkTheme(),
      home: DemoWorkspace(rule: ruleController),
    );
  }
}

/// サンプルデータで 002/003 を束ねたデモ画面。ルールは外部注入(永続化と結線)。
class DemoWorkspace extends StatefulWidget {
  const DemoWorkspace({super.key, required this.rule});

  final RuleController rule;

  @override
  State<DemoWorkspace> createState() => _DemoWorkspaceState();
}

class _DemoWorkspaceState extends State<DemoWorkspace> {
  late final FileListController _files = FileListController(
    files: _sampleFiles(),
  );

  @override
  void dispose() {
    _files.dispose();
    // widget.rule は永続化セッションの所有物なのでここでは破棄しない。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('一括リネーム（デモ）')),
      body: RuleBuilderWorkspace(fileList: _files, rule: widget.rule),
    );
  }
}

/// UI 確認用のサンプルファイル（名前・作成日時・サイズを散らしてソート/連番が
/// 分かるようにしている）。
List<FileEntry> _sampleFiles() {
  final base = DateTime(2026, 3, 1, 9);
  final names = <(String, int)>[
    ('IMG_0009.jpg', 2_400_000),
    ('IMG_0010.jpg', 3_100_000),
    ('IMG_0002.jpg', 1_800_000),
    ('scan document.pdf', 540_000),
    ('memo.txt', 1_200),
    ('旅行 写真.png', 4_800_000),
    ('report_final.docx', 88_000),
    ('archive.tar.gz', 9_900_000),
  ];
  return [
    for (var i = 0; i < names.length; i++)
      FileEntry(
        name: names[i].$1,
        createdAt: base.add(Duration(hours: i * 7)),
        modifiedAt: base.add(Duration(hours: i * 7, minutes: 30)),
        size: names[i].$2,
      ),
  ];
}
