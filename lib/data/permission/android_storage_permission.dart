import 'package:flutter/services.dart';

import 'storage_permission.dart';

/// Android の全ファイルアクセス権限を platform channel 越しに扱う
/// (013 REQ-001〜004)。
///
/// Kotlin 側は `Environment.isExternalStorageManager()` で状態を答え、
/// `Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION` で設定画面を開く。
///
/// **この class は Linux 上の test で実行できない**(channel の相手が居ない)。
/// `TestDefaultBinaryMessenger` で channel を差し替えれば Dart 側の写像は
/// 検査できるが、**Kotlin 側が本当に動くかは `013:T08` の実機確認**が引き受ける
/// (`task.md` の宣言表)。
class AndroidStoragePermission implements StoragePermissionPort {
  const AndroidStoragePermission();

  /// channel 名。Kotlin 側(`MainActivity.kt`)と一致させる。
  static const channel = MethodChannel(
    'com.example.batch_rename_master/storage_permission',
  );

  /// **失敗したら `denied` に倒す。**
  ///
  /// channel が無い、Kotlin 側が例外を投げた、想定外の値が返った —
  /// いずれも「権限がある」とは言えない。013 INV-002 は「権限が無い状態で
  /// filesystem へ書き込みを試みない」であり、**分からないときに通す実装は
  /// この不変条件を破りうる**。
  @override
  Future<StoragePermissionState> check() async {
    try {
      final granted = await channel.invokeMethod<bool>('isGranted');
      return granted == true
          ? StoragePermissionState.granted
          : StoragePermissionState.denied;
    } catch (_) {
      return StoragePermissionState.denied;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await channel.invokeMethod<bool>('openSettings') == true;
    } catch (_) {
      return false;
    }
  }
}
