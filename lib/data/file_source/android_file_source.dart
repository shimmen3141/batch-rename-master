import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/rename_engine.dart';
import 'file_source.dart';

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

/// Android の [FileSource]。**元場所ハンドルは絶対 path** である(004 REQ-002)。
///
/// SAF の document URI は使わない。全ファイルアクセスがあれば共有ストレージは
/// 通常の path として見えるので、`dart:io` でそのまま `stat` も列挙もできる
/// (013 ADR-002)。**これにより `listNames`(004 REQ-014)が Android でも成功し、
/// 読み込んでいないファイルとの衝突を実行前に検出できる**(005 REQ-026)。
///
/// 選択 UI 自体はここに持たない。[BrowserPicker] を受け取るだけで、画面は UI 層が
/// 供給する — port が `Navigator` を知ると test が widget を要るようになる。
class AndroidFileSource implements FileSource {
  const AndroidFileSource({required this.pick, this.locationNameOf});

  final BrowserPicker pick;

  /// 表示用の場所の名前(004 REQ-009: **人間可読の文字列**)。
  ///
  /// `folder` の basename をそのまま使うと、内部共有ストレージの root
  /// (`/storage/emulated/0`)が `0` になって意味を持たない
  /// (独立review attempt 1 の P2-8)。browser は保存場所の名前を知っているので、
  /// composition root がそれを渡す。渡されなければ basename を使う。
  final String Function(String folder)? locationNameOf;

  /// **`mimeTypes` は使わない。** Android の browser には MIME filter の手段が
  /// 無く、拡張子で絞る判定も新設しない(004 REQ-011 / REQ-017)。
  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async {
    final BrowserSelection? selection;
    try {
      selection = await pick();
    } catch (error) {
      return Failed(PickError(PickErrorKind.unknown, error.toString()));
    }
    if (selection == null) return const Cancelled();

    final entries = <FileEntry>[];
    for (final path in selection.paths) {
      final entry = await _entryOf(path, folder: selection.folder);
      // 選んだ直後に消えている場合がある。**空リストで「決定した」と混同しない**
      // よう、読めたものだけを Picked にする(004 REQ-001)。
      if (entry != null) entries.add(entry);
    }
    return Picked(entries);
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
  /// **作成日時は取得できない。** POSIX の `stat` に作成時刻が無いためで、
  /// SAF に列が無かったのと**結論は同じだが理由が違う**(004 REQ-003)。
  Future<FileEntry?> _entryOf(String path, {required String folder}) async {
    try {
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return FileEntry(
        name: p.basename(path),
        createdAt: null,
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
