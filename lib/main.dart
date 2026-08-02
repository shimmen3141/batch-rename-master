import 'package:flutter/material.dart';

import 'core/rename_engine.dart';
import 'ui/file_list/file_list_controller.dart';
import 'ui/rule_builder/rule_builder_workspace.dart';
import 'ui/rule_builder/rule_controller.dart';
import 'ui/theme/app_theme.dart';

/// デモ/プレビュー用のアプリ入口。
///
/// サンプルの [FileEntry] 一覧と初期ルールで 002(ファイルリスト)・003(ルール
/// ビルダー)・リアルタイムプレビューを組み上げ、エミュレータ/実機で UI を目視
/// 確認できるようにする(手動検証の足場)。実ファイルの読み込み(004)・リネーム
/// 実行(005)はまだ配線していないため、扱うのはサンプルデータのみ。
void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一括リネーム（デモ）',
      debugShowCheckedModeBanner: false,
      theme: appDarkTheme(),
      home: const DemoWorkspace(),
    );
  }
}

/// サンプルデータで 002/003 を束ねたデモ画面。
class DemoWorkspace extends StatefulWidget {
  const DemoWorkspace({super.key});

  @override
  State<DemoWorkspace> createState() => _DemoWorkspaceState();
}

class _DemoWorkspaceState extends State<DemoWorkspace> {
  late final FileListController _files = FileListController(
    files: _sampleFiles(),
  );
  late final RuleController _rule = RuleController(
    tokens: const [
      OriginalNameToken(),
      LiteralToken('_'),
      SequenceToken(start: 1, digits: 2),
    ],
  );

  @override
  void dispose() {
    _files.dispose();
    _rule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('一括リネーム（デモ）')),
      body: RuleBuilderWorkspace(fileList: _files, rule: _rule),
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
