import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../../core/rename_engine.dart';
import 'file_source.dart';

/// デスクトップ(Windows 等)の OS ピッカーを用いる [FileSource] 実装(T4)。
///
/// `file_selector`(flutter.dev 公式)でフォルダ/ファイルを選ばせ、`dart:io` で
/// メタデータを読む。実ファイルパスが得られるため、[FileEntry.sourceHandle] は
/// **絶対パス**とし、005 は `File.rename` で書き戻せる。
///
/// 作成日時は `FileStat` に無い(`changed` は inode 変更時刻であって作成時刻では
/// ない)ため**常に不明**(`null`)とする。NTFS の作成時刻を取るには FFI が要り、
/// それは取得経路の拡張(004 REQ-010)として後続で足せる。
class DesktopFileSource implements FileSource {
  const DesktopFileSource();

  /// [dir] 直下のファイルを [FileEntry] 列にする(ピッカー無しで検証できるよう公開)。
  ///
  /// サブフォルダは辿らない(004 スコープ外)。並び順は OS の列挙順のままで
  /// 未定義(仕様が「単一呼び出しの返り順は未定義」としている)。
  static List<FileEntry> entriesOfDirectory(Directory dir) {
    final location = p.basename(dir.path);
    final folder = folderHandleOf(dir.path);
    return [
      for (final entity in dir.listSync(followLinks: false))
        if (entity is File)
          _entryOf(entity, location: location, folder: folder),
    ];
  }

  /// ディレクトリ path から**所属 folder ハンドル**を作る(004 REQ-013)。
  ///
  /// **同じ場所は必ず同じ値**にならなければならない。`/sdcard/DCIM` と
  /// `/storage/emulated/0/DCIM` のような別名 path が別の値へ割れると、
  /// 占有名がその分だけ分割され、事前検出(005 REQ-026)が効かなくなる。
  /// そこで**シンボリックリンクを解決した絶対 path** を用いる。
  ///
  /// 解決できない場合(消えた・権限が無い)は、正規化した絶対 path へ落とす。
  /// **この場合は別名 path が割れうる**が、割れても占有名が「別 folder のもの」
  /// として扱われるだけで、既存を上書きすることはない — 実在確認(005 REQ-025)と
  /// 実行時の再採番(REQ-023)が最後の砦として残る。
  static String folderHandleOf(String directoryPath) {
    try {
      return Directory(directoryPath).resolveSymbolicLinksSync();
    } catch (_) {
      return p.canonicalize(directoryPath);
    }
  }

  @override
  Future<NameListResult> listNames(String folder) async {
    try {
      final dir = Directory(folder);
      return NamesListed({
        // **サブフォルダも数える。** 名前を占めていることに変わりはなく、
        // その名前へ改名しようとすれば失敗する(004 REQ-014)。
        // 隠しファイルもフィルタしない(決定 D-2)。
        for (final entity in dir.listSync(followLinks: false))
          p.basename(entity.path),
      });
    } catch (error) {
      // **空の [NamesListed] へ落とさない。** 「取得できなかった」を「衝突が無い」と
      // 読ませないための区別である(005 REQ-027)。
      return NameListFailed(errorOf(error));
    }
  }

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async {
    try {
      final files = await openFiles(
        acceptedTypeGroups: mimeTypes.isEmpty
            ? const []
            : [XTypeGroup(label: '対象の種類', mimeTypes: mimeTypes)],
      );
      // 空はキャンセル(`file_selector` はキャンセル時に空リストを返す)。
      if (files.isEmpty) return const Cancelled();
      return Picked([
        for (final file in files)
          _entryOf(
            File(file.path),
            location: p.basename(p.dirname(file.path)),
            folder: folderHandleOf(p.dirname(File(file.path).absolute.path)),
          ),
      ]);
    } catch (error) {
      return Failed(errorOf(error));
    }
  }

  /// 実ファイルを [FileEntry] へ写す。ハンドルは絶対パス。
  static FileEntry _entryOf(
    File file, {
    required String location,
    required String folder,
  }) {
    final stat = file.statSync();
    return FileEntry(
      name: p.basename(file.path),
      // FileStat に作成時刻は無い。取得できないので不明のままにする(REQ-003)。
      createdAt: null,
      modifiedAt: stat.modified,
      size: stat.size,
      sourceHandle: file.absolute.path,
      sourceLocation: location,
      sourceFolder: folder,
    );
  }

  /// 例外を [PickError] へ分類する(REQ-008。ピッカー無しで検証できるよう公開)。
  static PickError errorOf(Object error) {
    if (error is PathAccessException) {
      return PickError(PickErrorKind.permissionDenied, error.message);
    }
    if (error is FileSystemException) {
      return PickError(PickErrorKind.io, error.message);
    }
    return PickError(PickErrorKind.unknown, error.toString());
  }
}
