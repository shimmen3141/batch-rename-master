import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/rename_engine.dart';
import 'data/file_source/file_source.dart';
import 'data/file_source/platform_file_source.dart';
import 'data/permission/storage_permission.dart';
import 'data/rename_exec/platform_rename_executor.dart';
import 'data/rule_store/shared_preferences_rule_store.dart';
import 'ui/file_list/file_list_controller.dart';
import 'ui/file_source/file_source_bar.dart';
import 'ui/rule_builder/persistent_rule_controller.dart';
import 'ui/rule_builder/rule_builder_workspace.dart';
import 'ui/rule_builder/rule_controller.dart';
import 'ui/rename_exec/rename_execution_controller.dart';
import 'ui/theme/app_theme.dart';

/// アプリ入口。
///
/// 002(ファイルリスト)・003(ルールビルダー)・リアルタイムプレビューを束ね、
/// 004 の実 [FileSource](Android=SAF / デスクトップ=OS ピッカー)から実ファイルを
/// 読み込む。ルールは 007 の永続化(`shared_preferences`)と結線し、**前回のルールを
/// 次回起動時に復元**する。起動直後はサンプル一覧を表示し、読み込み操作で実データを
/// 追加できる。005 の platform rename adapter を接続し、成功後の新しいハンドルを
/// 次の操作へ引き継ぐ。
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
    _renameExecution.dispose();
    _files.dispose();
    // widget.rule は永続化セッションの所有物なのでここでは破棄しない。
    super.dispose();
  }

  /// 読み込み入口。実行中のプラットフォームに合う実 [FileSource]
  /// (Android=SAF / デスクトップ=OS ピッカー)を注入する(T4)。
  late final FileSource _source = createPlatformFileSource();

  /// 全ファイルアクセスの判定(013 REQ-001〜004)。**ここが唯一の platform 判定**で、
  /// UI も controller も自分では OS を見ない。
  late final StoragePermissionPort _permission =
      createPlatformStoragePermission();
  late final RenameExecutionController _renameExecution =
      RenameExecutionController(
        files: _files,
        executor: createPlatformRenameExecutor(),
        permission: _permission,
        // 占有名の材料は 004 が供給する(004 REQ-014 / 005 REQ-026)。
        listNames: _source.listNames,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('一括リネーム')),
      body: Column(
        children: [
          FileSourceBar(
            source: _source,
            controller: _files,
            permission: _permission,
          ),
          Expanded(
            child: RuleBuilderWorkspace(
              fileList: _files,
              rule: widget.rule,
              renameExecution: _renameExecution,
            ),
          ),
        ],
      ),
    );
  }
}

/// UI 確認用のサンプルファイル（名前・作成日時・サイズを散らしてソート/連番が
/// 分かるようにしている）。
///
/// `createdAt` が `null` の件を1つ混ぜてある（スクリーンショットは画像でも EXIF
/// 撮影日時を持たないことが多く、作成日時を取得できない代表例）。作成日時順ソート
/// を選ぶと、この行が「作成日時: 不明」と警告色で表示され、更新日時で代替して
/// 並べた旨の警告帯が出る（002 REQ-011/013 の目視確認用）。
List<FileEntry> _sampleFiles() {
  final base = DateTime(2026, 3, 1, 9);
  // (名前, サイズ, 作成日時を取得できたか)
  final names = <(String, int, bool)>[
    ('IMG_0009.jpg', 2_400_000, true),
    ('IMG_0010.jpg', 3_100_000, true),
    ('IMG_0002.jpg', 1_800_000, true),
    ('scan document.pdf', 540_000, true),
    ('memo.txt', 1_200, true),
    ('旅行 写真.png', 4_800_000, true),
    ('Screenshot_20260304.png', 760_000, false),
    ('report_final.docx', 88_000, true),
    ('archive.tar.gz', 9_900_000, true),
  ];
  return [
    for (var i = 0; i < names.length; i++)
      FileEntry(
        name: names[i].$1,
        createdAt: names[i].$3 ? base.add(Duration(hours: i * 7)) : null,
        modifiedAt: base.add(Duration(hours: i * 7, minutes: 30)),
        size: names[i].$2,
      ),
  ];
}
