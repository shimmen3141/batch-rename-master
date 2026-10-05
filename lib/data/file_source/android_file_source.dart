import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/rename_engine.dart';
import 'content_created_at.dart';
import 'file_source.dart';
import 'media_dates.dart';

/// app 内 browser が確定した選択(004 REQ-015 / REQ-016)。
///
/// **親フォルダは常に1つ**である — browser の選択は同一フォルダ内に限られる。
class BrowserSelection {
  const BrowserSelection({required this.folder, required this.paths});

  /// 選んだファイルが属するフォルダの絶対 path。
  final String folder;

  /// 選んだファイルの絶対 path。
  final List<String> paths;
}

/// browser を開いて選択を待つ。`null` は「決定していない」(004 REQ-001)。
typedef BrowserPicker = Future<BrowserSelection?> Function();

/// browser を [folder] で開き、[selected] を選択済みにして選択を待つ(004 REQ-021)。
/// `null` は「決定していない」。
typedef BrowserReopener =
    Future<BrowserSelection?> Function(String folder, Set<String> selected);

/// 写真・動画の選択画面を開いて選択を待つ(004 REQ-022 / REQ-023)。
///
/// 確定した写真・動画の絶対 path を返す。`null` は「決定していない」(004 REQ-001)。
typedef MediaPicker = Future<List<String>?> Function();

/// Android の [FileSource]。**元場所ハンドルは絶対 path** である(004 REQ-002)。
///
/// SAF の document URI は使わない。全ファイルアクセスがあれば共有ストレージは
/// 通常の path として見えるので、`dart:io` でそのまま `stat` も列挙もできる
/// (013 ADR-002)。**これにより `listNames`(004 REQ-014)が Android でも成功し、
/// 読み込んでいないファイルとの衝突を実行前に検出できる**(005 REQ-026)。
///
/// 選択 UI 自体はここに持たない。[BrowserPicker] を受け取るだけで、画面は UI 層が
/// 供給する — port が `Navigator` を知ると test が widget を要るようになる。
class AndroidFileSource
    implements FileSource, FolderReopenSource, MediaPickSource {
  const AndroidFileSource({
    required this.pick,
    this.pickMediaPaths,
    this.reopen,
    this.locationNameOf,
    this.mediaDates,
  });

  final BrowserPicker pick;

  /// 写真・動画の選択画面(004 REQ-022)。`null` なら開けない([pickMedia] は
  /// [Failed] を返す)。
  final MediaPicker? pickMediaPaths;

  /// 一覧の所属 folder を開き直す browser(004 REQ-021)。`null` なら開き直せない
  /// ([reopenFolder] は [Failed] を返す)。
  final BrowserReopener? reopen;

  /// 表示用の場所の名前(004 REQ-009: **人間可読の文字列**)。
  ///
  /// `folder` の basename をそのまま使うと、内部共有ストレージの root
  /// (`/storage/emulated/0`)が `0` になって意味を持たない
  /// (独立review attempt 1 の P2-8)。browser は保存場所の名前を知っているので、
  /// composition root がそれを渡す。渡されなければ basename を使う。
  final String Function(String folder)? locationNameOf;

  /// MediaStore の日時(004 REQ-010 の②`DATE_TAKEN`・③`DATE_ADDED`)。`null` なら
  /// 中身の日時(①)だけを使う。
  final MediaDatesPort? mediaDates;

  /// **`mimeTypes` は使わない。** Android の browser には MIME filter の手段が
  /// 無く、拡張子で絞る判定も新設しない(004 REQ-011 / REQ-017)。
  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async {
    return _resultOf(pick);
  }

  /// 写真・動画の選択画面から読み込む(004 REQ-022 / REQ-023)。
  ///
  /// **所属 folder はファイルごとに親 folder である** — folder をまたいで選べる
  /// (REQ-023)。作成日時の補い方(REQ-010)は browser と同じ。
  @override
  Future<PickResult> pickMedia() async {
    final pickMediaPaths = this.pickMediaPaths;
    if (pickMediaPaths == null) {
      return const Failed(PickError(PickErrorKind.unknown, '写真・動画の選択画面を開けません'));
    }
    final List<String>? paths;
    try {
      paths = await pickMediaPaths();
    } catch (error) {
      return Failed(PickError(PickErrorKind.unknown, error.toString()));
    }
    if (paths == null) return const Cancelled();
    return _picked([for (final path in paths) (path, p.dirname(path))]);
  }

  /// 一覧の所属 [folder] を、[selected] を選択済みにして開き直す(004 REQ-021)。
  ///
  /// **folder が無ければ browser を開かない。** SD カードを抜いた・folder が消えた
  /// ときに、空の browser や保存場所の一覧へ落とすと、何が起きたか分からない。
  @override
  Future<PickResult> reopenFolder(
    String folder, {
    required Set<String> selected,
  }) async {
    final reopen = this.reopen;
    if (reopen == null) {
      return const Failed(PickError(PickErrorKind.unknown, 'このフォルダは開き直せません'));
    }
    try {
      if (!await Directory(folder).exists()) {
        return const Failed(PickError(PickErrorKind.io, 'フォルダが見つかりません'));
      }
    } catch (error) {
      return Failed(PickError(PickErrorKind.unknown, error.toString()));
    }
    return _resultOf(() => reopen(folder, selected));
  }

  /// browser の確定を [PickResult] にする。
  Future<PickResult> _resultOf(
    Future<BrowserSelection?> Function() open,
  ) async {
    final BrowserSelection? selection;
    try {
      selection = await open();
    } catch (error) {
      return Failed(PickError(PickErrorKind.unknown, error.toString()));
    }
    if (selection == null) return const Cancelled();
    return _picked([
      for (final path in selection.paths) (path, selection.folder),
    ]);
  }

  /// 選んだ (path, 所属 folder) を [Picked] にする。
  Future<PickResult> _picked(List<(String, String)> selection) async {
    final entries = <FileEntry>[];
    for (final (path, folder) in selection) {
      final entry = await _entryOf(path, folder: folder);
      // 選んだ直後に消えている場合がある。**空リストで「決定した」と混同しない**
      // よう、読めたものだけを Picked にする(004 REQ-001)。
      if (entry != null) entries.add(entry);
    }
    return Picked(await _withMediaDates(entries));
  }

  /// ①(中身の日時)が無いファイルを、MediaStore の ②`DATE_TAKEN` → ③`DATE_ADDED`
  /// の順で補う(004 REQ-010)。どれも無ければ不明のまま。
  ///
  /// ③ `DATE_ADDED` は、この app の改名(`renameat2`)で変わらないことを端末で
  /// 確かめてある(`010:T04`)。改名した後に読み込み直しても作成日時は変わらない
  /// (代表例 50)。
  Future<List<FileEntry>> _withMediaDates(List<FileEntry> entries) async {
    final port = mediaDates;
    if (port == null) return entries;
    final missing = [
      for (final entry in entries)
        if (entry.createdAt == null) entry.sourceHandle!,
    ];
    if (missing.isEmpty) return entries;
    final Map<String, MediaDates> dates;
    try {
      dates = await port.datesOf(missing);
    } catch (_) {
      // 引けなくても読み込みは止めない。不明のままにする(REQ-003)。
      return entries;
    }
    return [
      for (final entry in entries)
        if (entry.createdAt != null) entry else _withCreatedAt(entry, dates),
    ];
  }

  static FileEntry _withCreatedAt(
    FileEntry entry,
    Map<String, MediaDates> dates,
  ) {
    final media = dates[entry.sourceHandle];
    final createdAt = media?.taken ?? media?.added;
    if (createdAt == null) return entry;
    return FileEntry(
      name: entry.name,
      createdAt: createdAt,
      modifiedAt: entry.modifiedAt,
      size: entry.size,
      selected: entry.selected,
      sourceHandle: entry.sourceHandle,
      sourceLocation: entry.sourceLocation,
      sourceFolder: entry.sourceFolder,
    );
  }

  /// [folder] の**実在 entry 名**(004 REQ-014)。
  ///
  /// **ファイル・サブフォルダを問わない。** 読み込んでいないファイルの名前も含む。
  /// 隠しファイルも除かない — 名前を占めていることに変わりはない。
  /// 列挙できなければ [NameListFailed] を返し、**例外を投げない**。
  /// **空の [NamesListed] と混同しない**(005 REQ-027 がこの区別に依存する)。
  @override
  Future<NameListResult> listNames(String folder) async {
    try {
      final names = <String>{};
      await for (final entity in Directory(folder).list(followLinks: false)) {
        names.add(p.basename(entity.path));
      }
      return NamesListed(names);
    } on PathAccessException catch (error) {
      return NameListFailed(
        PickError(PickErrorKind.permissionDenied, error.message),
      );
    } on FileSystemException catch (error) {
      return NameListFailed(PickError(PickErrorKind.io, error.message));
    } catch (error) {
      return NameListFailed(PickError(PickErrorKind.unknown, error.toString()));
    }
  }

  /// 実 file から [FileEntry] を作る。読めなければ `null`。
  ///
  /// 作成日時は、ここではファイルの中身に記録された日時(004 REQ-010 の①)だけを
  /// 読む。POSIX の `stat` には作成時刻が無い(004 REQ-003)。MediaStore の②③は
  /// [_withMediaDates] がまとめて補う。
  Future<FileEntry?> _entryOf(String path, {required String folder}) async {
    try {
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return FileEntry(
        name: p.basename(path),
        createdAt: readContentCreatedAt(path),
        modifiedAt: stat.modified,
        size: stat.size,
        sourceHandle: path,
        // 所属 folder ハンドル(004 REQ-013)。**ハンドルから導出しない** —
        // browser が確定した値をそのまま持つ。
        sourceFolder: folder,
        sourceLocation: locationNameOf?.call(folder) ?? p.basename(folder),
      );
    } catch (_) {
      return null;
    }
  }
}
