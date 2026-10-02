import '../../data/file_source/file_source.dart';
import '../../data/rename_exec/occupied_names.dart';
import 'file_list_controller.dart';

/// 読み込んだ folder の実在名を取り、一覧の警告へ渡す(005 REQ-026 / REQ-028。`008:T54`)。
///
/// 以前は実在名を**実行を要求した時点**(`RenameExecutionController.prepare`)にだけ
/// 取っていたので、読み込んでいない同名との重複は実行buttonを押すまで一覧に出なかった。
/// REQ-028 は「一覧の警告はより前に取得した占有名で評価してよい」としている。
///
/// **問い合わせるのは、folder の実在名が古くなりうるときだけ**である。
///
/// - その folder の実在名をまだ持っていない(読み込んだ・読み込み直した)。
/// - その folder の読み込んだファイルに、**前に問い合わせたときに無かった名前**が
///   現れた(改名の実行・元に戻した)。実在名が変わったのはこの app 自身の改名による。
///
/// 選択・並び順・ルールの変更、一覧からの除去では問い合わせない — 実在名は変わらない。
/// 問い合わせは非同期で、一覧の表示と操作を止めない。取れなかった folder は、
/// 読み込んだファイルの名前が変わるまで問い合わせ直さない(列挙できない経路、たとえば
/// SAF で毎回失敗を繰り返さないため)。取れないあいだの一覧は今までどおり占有名なしで
/// 評価する(REQ-028 が許す)。**実行の可否と自動解決は、これとは別に実行の要求時に
/// 取り直す**(REQ-028。`prepare` はそのまま)。
class FolderNamesSync {
  FolderNamesSync({required this.files, required this.listNames}) {
    files.addListener(_onFilesChanged);
    _onFilesChanged();
  }

  final FileListController files;

  /// 実在名の供給元(004 REQ-014 の `FileSource.listNames`)。
  final FolderNameLister listNames;

  /// folder → 最後に問い合わせたときの、その folder の読み込んだファイル名。
  final Map<String, Set<String>> _askedWith = {};

  /// 最後の問い合わせが失敗した folder。
  final Set<String> _failed = {};

  final Set<String> _inFlight = {};
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    files.removeListener(_onFilesChanged);
  }

  /// 読み込んだファイルの folder → 名前(実体ハンドルを持つものだけ)。
  Map<String, Set<String>> _loadedNames() {
    final byFolder = <String, Set<String>>{};
    for (final item in files.items) {
      final folder = item.sourceFolder;
      if (item.sourceHandle == null || folder == null) continue;
      (byFolder[folder] ??= <String>{}).add(item.name);
    }
    return byFolder;
  }

  void _onFilesChanged() {
    if (_disposed) return;
    final loaded = _loadedNames();
    _askedWith.removeWhere((folder, _) => !loaded.containsKey(folder));
    _failed.removeWhere((folder) => !loaded.containsKey(folder));
    for (final MapEntry(key: folder, value: names) in loaded.entries) {
      if (_inFlight.contains(folder)) continue;
      final asked = _askedWith[folder];
      final renamed = asked == null || !asked.containsAll(names);
      // 読み込み直しで実在名が捨てられた(`FileListController` は一覧を置き換えると
      // 捨てる)。同じファイルを読み込み直しても問い合わせ直す。
      final dropped =
          !_failed.contains(folder) && !files.folderNames.containsKey(folder);
      if (renamed || dropped) _ask(folder, names);
    }
  }

  Future<void> _ask(String folder, Set<String> names) async {
    _inFlight.add(folder);
    _askedWith[folder] = names;
    NameListResult result;
    try {
      result = await listNames(folder);
    } catch (error) {
      // 供給元は例外を投げない約束だが、投げても一覧を壊さない(取れなかった扱い)。
      result = NameListFailed(PickError(PickErrorKind.unknown, '$error'));
    }
    _inFlight.remove(folder);
    if (_disposed) return;
    switch (result) {
      case NamesListed(names: final listed):
        _failed.remove(folder);
        // 問い合わせている間に、その folder のファイルが一覧から無くなっていれば
        // 入れない(置き換え後の一覧とは無関係な folder の名前になる)。
        if (_loadedNames().containsKey(folder)) {
          files.updateFolderNames({folder: listed});
        }
      case NameListFailed():
        _failed.add(folder);
    }
    // 問い合わせている間に改名などが起きていれば、もう一度問い合わせる。
    _onFilesChanged();
  }
}
