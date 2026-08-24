import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_source.dart';
import 'storage_browser.dart';

/// 実 filesystem を辿る [StorageBrowserPort](004 REQ-015 / REQ-017)。
///
/// **Android の共有ストレージは通常の path として見える** — 全ファイルアクセスが
/// あれば `dart:io` でそのまま列挙できる(013 ADR-002)。SAF の document URI は
/// 使わない。
///
/// **実機の mount 構成はこの環境で確かめられない**(`013:T08` が引き受ける)。
/// ここで閉じているのは「与えられた root をどう辿るか」であって、
/// 「root が実際に何か」ではない。
class AndroidStorageBrowser implements StorageBrowserPort {
  const AndroidStorageBrowser({
    this.primaryRoot = '/storage/emulated/0',
    this.volumesDirectory = '/storage',
  });

  /// 内部共有ストレージの root。利用者から「内部ストレージ」と見える場所。
  final String primaryRoot;

  /// 取り外し可能なボリュームが現れる directory。
  final String volumesDirectory;

  /// **`/storage` の中身を列挙して保存場所を作る。**
  ///
  /// `emulated` と `self` は内部共有ストレージの実体・別名なので除く。
  /// 残りが SD カード・USB である(volume id が名前になる)。
  @override
  Future<List<StorageLocation>> locations() async {
    final found = <StorageLocation>[
      if (await Directory(primaryRoot).exists())
        StorageLocation(name: '内部ストレージ', root: primaryRoot),
    ];
    try {
      final volumes = Directory(volumesDirectory).listSync();
      for (final volume in volumes) {
        final name = p.basename(volume.path);
        if (name == 'emulated' || name == 'self') continue;
        if (volume is! Directory) continue;
        found.add(StorageLocation(name: name, root: volume.path));
      }
    } on FileSystemException {
      // 列挙できなくても内部ストレージだけは返す。**空にして「保存場所が無い」と
      // 見せない** — 取り外し可能なボリュームが読めないだけである。
    }
    return found;
  }

  /// **実在するものだけ**返す(004 REQ-015)。
  @override
  Future<List<BrowserEntry>> shortcuts(StorageLocation location) async {
    final found = <BrowserEntry>[];
    for (final name in knownShortcutNames) {
      final path = p.join(location.root, name);
      if (await Directory(path).exists()) {
        found.add(BrowserEntry(name: name, path: path, isDirectory: true));
      }
    }
    return found;
  }

  /// **絞り込まない**(004 REQ-017)。隠しファイルもサブフォルダもそのまま返す。
  ///
  /// 並びは「フォルダが先、その中で名前順」。判定を新設しているのではなく、
  /// 辿るための並べ替えである。
  @override
  Future<DirectoryListing> list(String folder) async {
    try {
      final entries = <BrowserEntry>[];
      await for (final entity in Directory(folder).list(followLinks: false)) {
        entries.add(
          BrowserEntry(
            name: p.basename(entity.path),
            path: entity.path,
            isDirectory: entity is Directory,
          ),
        );
      }
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return DirectoryListed(entries);
    } on PathAccessException catch (error) {
      return DirectoryListingFailed(
        PickError(PickErrorKind.permissionDenied, error.message),
      );
    } on FileSystemException catch (error) {
      return DirectoryListingFailed(PickError(PickErrorKind.io, error.message));
    } catch (error) {
      // **例外を投げない。** 呼び出し側は結果型だけを受け取る(004 REQ-001)。
      return DirectoryListingFailed(
        PickError(PickErrorKind.unknown, error.toString()),
      );
    }
  }
}
