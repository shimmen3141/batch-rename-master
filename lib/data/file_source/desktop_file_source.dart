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

  @override
  Future<PickResult> pickFolder() async {
    try {
      final path = await getDirectoryPath();
      // ダイアログを閉じただけ = 未選択(REQ-001)。
      if (path == null) return const Cancelled();
      return Picked(entriesOfDirectory(Directory(path)));
    } catch (error) {
      return Failed(errorOf(error));
    }
  }

  /// [dir] 直下のファイルを [FileEntry] 列にする(ピッカー無しで検証できるよう公開)。
  ///
  /// サブフォルダは辿らない(004 スコープ外)。並び順は OS の列挙順のままで
  /// 未定義(仕様が「単一呼び出しの返り順は未定義」としている)。
  static List<FileEntry> entriesOfDirectory(Directory dir) {
    final location = p.basename(dir.path);
    return [
      for (final entity in dir.listSync(followLinks: false))
        if (entity is File) _entryOf(entity, location: location),
    ];
  }

  @override
  Future<PickResult> pickFiles() async {
    try {
      final files = await openFiles();
      // 空はキャンセル(`file_selector` はキャンセル時に空リストを返す)。
      if (files.isEmpty) return const Cancelled();
      return Picked([
        for (final file in files)
          _entryOf(File(file.path), location: p.basename(p.dirname(file.path))),
      ]);
    } catch (error) {
      return Failed(errorOf(error));
    }
  }

  /// 実ファイルを [FileEntry] へ写す。ハンドルは絶対パス。
  static FileEntry _entryOf(File file, {required String location}) {
    final stat = file.statSync();
    return FileEntry(
      name: p.basename(file.path),
      // FileStat に作成時刻は無い。取得できないので不明のままにする(REQ-003)。
      createdAt: null,
      modifiedAt: stat.modified,
      size: stat.size,
      sourceHandle: file.absolute.path,
      sourceLocation: location,
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
