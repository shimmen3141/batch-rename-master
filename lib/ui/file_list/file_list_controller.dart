import 'package:flutter/foundation.dart';

import '../../core/rename_engine.dart';
import 'file_sort.dart';

/// メイン画面のプレゼンテーション状態層(002 spec: `FileListController`)。
///
/// ファイル一覧の保持・選択・ソート種別・カスタム順・注入ルールを持つ。
/// ウィジェット(`Widget` の構築)には依存せず、単体でテスト可能(002 計画)。
/// 各行の「現在名／変更後名」を 001 の [generatePreview] から供給する処理は
/// T3 で載せる。ここでは状態と操作のみを提供する。
///
/// 選択は [FileEntry] のオブジェクト同一性で管理する(identity Set)。
/// [FileEntry] は不変値(001)で、[FileEntry.selected] は 002 では参照せず、
/// 選択の正本はこのコントローラが持つ。
class FileListController extends ChangeNotifier {
  /// [files] を入力順で保持し、既定で全選択する(002 決定済み事項)。
  /// [rule] はプレビューに用いる注入ルール(既定は空 = 元名のみ相当)。
  /// 初期 [sortMode] は入力順を表す [FileSortMode.custom](002 決定済み事項)。
  FileListController({
    required List<FileEntry> files,
    RenameRule rule = RenameRule.empty,
  }) : _items = List<FileEntry>.of(files),
       _selected = Set<FileEntry>.identity()..addAll(files) {
    _rule = rule;
  }

  List<FileEntry> _items;
  final Set<FileEntry> _selected;
  FileSortMode _sortMode = FileSortMode.custom;
  RenameRule _rule = RenameRule.empty;

  /// 現在の表示順のファイル列(読み取り専用ビュー)。
  List<FileEntry> get items => List<FileEntry>.unmodifiable(_items);

  /// 現在のソート種別。
  FileSortMode get sortMode => _sortMode;

  /// プレビューに用いる現在のルール。
  RenameRule get rule => _rule;

  /// 選択中の件数。
  int get selectedCount => _selected.length;

  /// [item] が選択されているか。
  bool selectedOf(FileEntry item) => _selected.contains(item);

  /// [item] の選択を反転する(REQ-004)。
  void toggleSelection(FileEntry item) {
    if (!_selected.remove(item)) {
      _selected.add(item);
    }
    notifyListeners();
  }

  /// 全 item を選択する(REQ-004)。
  void selectAll() {
    _selected
      ..clear()
      ..addAll(_items);
    notifyListeners();
  }

  /// 全 item を選択解除する(REQ-004)。
  void clearAll() {
    _selected.clear();
    notifyListeners();
  }

  /// ソート種別を [mode] に更新する(REQ-002 / REQ-003)。
  ///
  /// [FileSortMode.name] / [FileSortMode.createdAt] / [FileSortMode.size] は
  /// 対応キーで昇順・安定ソートする。[FileSortMode.custom] は現在順を保持する。
  void setSortMode(FileSortMode mode) {
    _sortMode = mode;
    if (mode != FileSortMode.custom) {
      _items = stableSorted(_items, comparatorFor(mode));
    }
    notifyListeners();
  }

  /// [oldIndex] の item を [newIndex] の位置へ移動し、ソート種別を
  /// [FileSortMode.custom] へ自動切替する(REQ-003)。
  ///
  /// インデックスは Flutter の `ReorderableListView.onReorder` 規約に従う
  /// (下方向へ移動する場合、[newIndex] は削除前の位置を指すため 1 減じる)。
  void reorder(int oldIndex, int newIndex) {
    final next = List<FileEntry>.of(_items);
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final moved = next.removeAt(oldIndex);
    next.insert(target, moved);
    _items = next;
    _sortMode = FileSortMode.custom;
    notifyListeners();
  }

  /// プレビューに用いるルールを差し替える(REQ-005)。
  void setRule(RenameRule rule) {
    _rule = rule;
    notifyListeners();
  }
}
