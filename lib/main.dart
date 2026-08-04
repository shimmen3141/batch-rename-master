import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/rename_engine.dart';
import 'data/file_source/file_source.dart';
import 'data/rule_store/shared_preferences_rule_store.dart';
import 'ui/file_list/file_list_controller.dart';
import 'ui/file_source/file_source_bar.dart';
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

  /// 読み込み入口のデモ用ソース。**T4 で実 `FileSource`(SAF / ピッカー)に
  /// 差し替える**箇所。ここでは押すたびに別フォルダのファイルが増える様子を
  /// 再現し、キャンセル・失敗の見え方も確認できるようにしている。
  late final FileSource _demoSource = FakeFileSource(
    folderResults: [
      Picked(_demoFolder('ダウンロード', 'dl', 3)),
      Picked(_demoFolder('スクリーンショット', 'ss', 2)),
      const Failed(PickError(PickErrorKind.permissionDenied)),
    ],
    fileResults: [Picked(_demoFolder('書類', 'doc', 2))],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('一括リネーム（デモ）')),
      body: Column(
        children: [
          FileSourceBar(source: _demoSource, controller: _files),
          Expanded(
            child: RuleBuilderWorkspace(fileList: _files, rule: widget.rule),
          ),
        ],
      ),
    );
  }
}

/// デモ用に、あるフォルダから読み込んだ体の [FileEntry] を作る。
List<FileEntry> _demoFolder(String location, String prefix, int count) {
  final base = DateTime(2026, 5, 2, 13);
  return [
    for (var i = 0; i < count; i++)
      FileEntry(
        name: '$prefix-${i + 1}.jpg',
        // スクリーンショット相当のフォルダは作成日時が取得できない体にする。
        createdAt: prefix == 'ss' ? null : base.add(Duration(hours: i)),
        modifiedAt: base.add(Duration(hours: i, minutes: 20)),
        size: 1_000_000 + i * 1000,
        sourceHandle: 'demo://$prefix/${i + 1}',
        sourceLocation: location,
      ),
  ];
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
