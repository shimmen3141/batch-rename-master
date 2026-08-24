import 'dart:io';

import 'android_storage_permission.dart';

/// 全ファイルアクセス権限(`MANAGE_EXTERNAL_STORAGE`)の状態(013 REQ-001〜004)。
enum StoragePermissionState {
  /// 付与されている。読み込みも改名もできる。
  granted,

  /// 付与されていない。**読み込ませない**(013 REQ-001)。
  ///
  /// 「一度も要求していない」と「拒否された」を区別しない。設定画面で与える
  /// 種類の権限で、`requestPermissions` のような1回きりのdialogが無く、
  /// **区別しても利用者へ見せる導線が同じ**だからである(013 REQ-003 は
  /// 拒否後も同じ説明と導線を出し続けることを求めている)。
  denied,

  /// この platform では概念が無い(desktop)。制限しない。
  notApplicable,
}

/// 権限の状態を答え、設定画面を開くport(013 REQ-001〜004)。
///
/// **状態を保持しない。** 013 REQ-004 は「読み込みの直前と改名の実行直前に確認する。
/// 設定から取り消されうるため、一度確認した結果を持ち回らない」と定めている。
/// 実装も呼び出し側も、**毎回 [check] を呼ぶ**。
abstract interface class StoragePermissionPort {
  /// 現在の状態を**その場で**調べる。
  Future<StoragePermissionState> check();

  /// 設定画面を開く。**利用者の操作でのみ呼ぶ**(013 REQ-003)。
  ///
  /// 開けたかどうかを返す。開けなかった場合、呼び出し側は説明を出したまま留まる。
  Future<bool> openSettings();
}

/// 権限の概念が無い platform 用(013 spec 範囲外「desktopの振る舞い。何も変えない」)。
class UnrestrictedStoragePermission implements StoragePermissionPort {
  const UnrestrictedStoragePermission();

  @override
  Future<StoragePermissionState> check() async =>
      StoragePermissionState.notApplicable;

  /// **開かない。** desktop に対応する設定画面が無い。
  @override
  Future<bool> openSettings() async => false;
}

/// 現在の platform に合う port を選ぶ composition root。
///
/// **Android だけが制限を持つ。** desktop は [UnrestrictedStoragePermission] で
/// 素通しする — 013 は desktop の振る舞いを変えない。
StoragePermissionPort createPlatformStoragePermission() {
  if (Platform.isAndroid) return const AndroidStoragePermission();
  return const UnrestrictedStoragePermission();
}
