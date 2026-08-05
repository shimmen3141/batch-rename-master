import 'package:flutter/foundation.dart';

import '../../core/rename_engine.dart';
import 'file_sort.dart';
import 'row_view.dart';

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
  /// [clock] は日時トークンの「現在日時」に用いる時計(既定は [DateTime.now])。
  /// 初期 [sortMode] は入力順を表す [FileSortMode.custom](002 決定済み事項)。
  FileListController({
    required List<FileEntry> files,
    RenameRule rule = RenameRule.empty,
    DateTime Function() clock = DateTime.now,
  }) : _items = List<FileEntry>.of(files),
       _selected = Set<FileEntry>.identity()..addAll(files) {
    _rule = rule;
    _clock = clock;
  }

  List<FileEntry> _items;
  final Set<FileEntry> _selected;
  DateTime Function() _clock = DateTime.now;
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

  /// 手動並び替え(`reorder`)と [FileSortMode.custom] を提示してよいか(REQ-014)。
  ///
  /// 並び順が生成後名に影響するのは**連番トークンがあるときだけ**で、無いときは
  /// 並べ替えても出力が変わらない。動かしても何も起きない操作を見せないため、
  /// 現在の [rule] に連番トークンが含まれるかで判定する(ルールの変更に追随する)。
  /// ソート(名前順・作成日時順・更新日時順・サイズ順)は閲覧・確認の用途で
  /// 常に提示してよいので、この判定の対象外。
  bool get manualOrderMatters =>
      _rule.tokens.any((token) => token is SequenceToken);

  /// 作成日時が不明な item の件数(REQ-011)。
  ///
  /// 判定はファイル種別ではなく**取得可否**([FileEntry.createdAt] が `null` か)
  /// で行う。画像でも EXIF 撮影日時を持たない場合があるため。
  int get unknownCreatedAtCount =>
      _items.where((item) => item.createdAt == null).length;

  /// 作成日時ソート時に供給する警告。該当しなければ `null`(REQ-011)。
  ///
  /// 現在のソートが [FileSortMode.createdAt] で、作成日時が不明な item が
  /// 1 件以上あるときだけ供給する(0 件・他のソートでは `null`)。
  CreatedAtFallbackWarning? get createdAtSortWarning {
    if (_sortMode != FileSortMode.createdAt) return null;
    final count = unknownCreatedAtCount;
    return count == 0 ? null : CreatedAtFallbackWarning(count);
  }

  /// ソート種別を [mode] に更新する(REQ-002 / REQ-003)。
  ///
  /// [FileSortMode.name] / [FileSortMode.createdAt] / [FileSortMode.modifiedAt]
  /// / [FileSortMode.size] は対応キーで昇順・安定ソートする。作成日時ソートで
  /// 作成日時が不明な item は、その item の更新日時をキーに代替する
  /// ([createdAtSortKey]。REQ-002)。[FileSortMode.custom] は現在順を保持する。
  void setSortMode(FileSortMode mode) {
    _sortMode = mode;
    if (mode != FileSortMode.custom) {
      _items = stableSorted(_items, comparatorFor(mode));
    }
    notifyListeners();
  }

  /// [oldIndex] の item を取り出し [newIndex] の位置へ挿入して、ソート種別を
  /// [FileSortMode.custom] へ自動切替する(REQ-003)。
  ///
  /// インデックスは Flutter の `ReorderableListView.onReorderItem` 規約に従う。
  /// [newIndex] は「[oldIndex] の要素を取り除いた後の挿入先」を指す(調整済み)
  /// ため、そのまま `removeAt(oldIndex)` → `insert(newIndex)` に用いる。
  void reorder(int oldIndex, int newIndex) {
    final next = List<FileEntry>.of(_items);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    _items = next;
    _sortMode = FileSortMode.custom;
    notifyListeners();
  }

  /// プレビューに用いるルールを差し替える(REQ-005)。
  void setRule(RenameRule rule) {
    _rule = rule;
    notifyListeners();
  }

  /// 現在のリストと選択を捨てて [entries] で**置き換える**(REQ-008 / 004 REQ-004・005)。
  ///
  /// 供給された順を表示順とし、**全件を選択状態**にする。**蓄積しない**
  /// (前回の読み込み結果は残らない)。空リストで置き換えるとリストは空になる。
  /// [entries] に**同一ハンドルが複数含まれていた場合は1件にまとめる**
  /// (ハンドルは同一ファイルの識別子であるため。004 REQ-002/004)。
  ///
  /// ハンドルを持たない要素([FileEntry.sourceHandle] が `null`)は同一性を
  /// 判定できないため、まとめずにそのまま並べる。
  void setFiles(List<FileEntry> entries) {
    final seen = <String>{};
    final next = <FileEntry>[];
    for (final entry in entries) {
      final handle = entry.sourceHandle;
      if (handle != null && !seen.add(handle)) continue;
      next.add(entry);
    }
    _items = next;
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// 元場所ハンドルが [handle] に一致する item を除去する(REQ-009)。
  ///
  /// 一致が無ければ無変化(通知もしない)。
  void removeFile(String handle) {
    final remaining = <FileEntry>[];
    final removed = <FileEntry>[];
    for (final item in _items) {
      (item.sourceHandle == handle ? removed : remaining).add(item);
    }
    if (removed.isEmpty) return;
    _items = remaining;
    _selected.removeAll(removed);
    notifyListeners();
  }

  /// 作業セットと選択を空にする(REQ-009)。
  void clearFiles() {
    if (_items.isEmpty && _selected.isEmpty) return;
    _items = <FileEntry>[];
    _selected.clear();
    notifyListeners();
  }

  /// 各行の表示データを現在の表示順で供給する(REQ-006 / REQ-007)。
  ///
  /// 選択行の変更後名は 001 の [generatePreview] に一致する(選択行を表示順で
  /// 連番割り当て)。未選択行の [RowView.newName] は `null`(プレビュー対象外)。
  /// 選択・並び順・ルールの変更は次回の取得に反映される。
  ///
  /// 選択の正本はこのコントローラが持つため、`generatePreview` へは各 item の
  /// 選択状態を [FileEntry.selected] に写した複製を表示順で渡す。「現在日時」の
  /// 日時トークン用に [_clock] を一度だけ評価する。
  List<RowView> get rows {
    final now = _clock();
    final ordered = <FileEntry>[
      for (final item in _items) _withSelection(item, _selected.contains(item)),
    ];
    final preview = generatePreview(_rule, ordered, now);
    final newNameOf = Map<FileEntry, String>.identity();
    for (final entry in preview) {
      newNameOf[entry.source] = entry.resultName;
    }
    return <RowView>[
      for (var i = 0; i < _items.length; i++)
        RowView(
          source: _items[i],
          currentName: _items[i].name,
          newName: newNameOf[ordered[i]],
          selected: _selected.contains(_items[i]),
        ),
    ];
  }

  /// [item] の値を保ちつつ選択状態だけを [selected] にした複製。
  static FileEntry _withSelection(FileEntry item, bool selected) => FileEntry(
    name: item.name,
    createdAt: item.createdAt,
    modifiedAt: item.modifiedAt,
    size: item.size,
    selected: selected,
    sourceHandle: item.sourceHandle,
    sourceLocation: item.sourceLocation,
  );
}
