import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_source.dart';
import 'storage_browser.dart';
import 'storage_volumes.dart';

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
    this.volumes = const MethodChannelStorageVolumes(),
  });

  /// 内部共有ストレージの root。利用者から「内部ストレージ」と見える場所。
  ///
  /// **保存場所が1件も返らなかったときの拠り所**である。ここが読めるなら、
  /// 少なくとも内部ストレージは辿れる。
  final String primaryRoot;

  /// 保存場所のボリュームを供給する port。
  final StorageVolumesPort volumes;

  /// **プラットフォームに列挙させる**(004 REQ-015)。
  ///
  /// **`/storage` を歩いて探さない。** それは `013:T07` が採った手段だが、
  /// **app からは `EACCES` で列挙できず、装着されている媒体を1つも見つけられない**
  /// ことが `013:T08` の実機観測で分かった(2026-08-26、API 37 emulator。端末の
  /// `mount` には vfat の volume があるのに、保存場所は内部ストレージだけだった)。
  ///
  /// **列挙の手段は 004 spec が「自由とする点」に挙げている。** 自由なのは手段で
  /// あって、結果ではない。
  ///
  /// **この関数は投げない。** 投げると browser の画面が読み込み中のまま止まる
  /// (`_loadLocations` は結果を待って `setState` する)。port は投げない約束だが、
  /// **約束に頼らず、ここで閉じる**(`013:T08` で「例外が保護の外にあり報告が
  /// 丸ごと消える」型を2回踏んだ)。
  @override
  Future<StorageLocations> locations() async {
    final StorageVolumesResult result;
    try {
      result = await volumes.list();
    } catch (error) {
      return StorageLocations(
        await _primaryOnly(),
        failure: '保存場所を取得できませんでした: $error',
      );
    }
    switch (result) {
      case VolumesListed(:final volumes):
        final found = [
          for (final volume in volumes)
            StorageLocation(name: volume.name, root: volume.path),
        ];
        if (found.isNotEmpty) return StorageLocations(found);
        // **1件も返らないのは異常である。** 内部共有ストレージは常にあるので、
        // 拠り所へ落としたうえで**欠落を隠さない**。
        return StorageLocations(
          await _primaryOnly(),
          failure: '保存場所を1件も取得できませんでした',
        );
      case VolumesUnavailable(:final reason):
        return StorageLocations(await _primaryOnly(), failure: reason);
    }
  }

  /// 拠り所の内部共有ストレージだけ。**読めなければ空**である。
  ///
  /// `exists()` は親を辿れないと `false` ではなく**投げる**ので、ここでも閉じる。
  Future<List<StorageLocation>> _primaryOnly() async {
    try {
      if (await Directory(primaryRoot).exists()) {
        return [StorageLocation(name: '内部ストレージ', root: primaryRoot)];
      }
    } catch (_) {
      // 拠り所も読めない。**空で返す** — 呼び出し側は `failure` で理由を出す。
    }
    return const [];
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
