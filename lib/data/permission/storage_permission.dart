import 'dart:io';

import 'package:flutter/foundation.dart';

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
///
/// **production から直接構築しないこと。** 配るのは
/// [createPlatformStoragePermission] だけである。どこかで直接構築できると、
/// **Android でも制限しない port が配られて門が静かに消える**(独立review
/// attempt 1 の P1-3 / attempt 2 の F2)。`tool/check_platform_boundary.py` が
/// `lib/` の他 file での構築を禁じ、`@visibleForTesting` が analyzer 側でも止める。
@visibleForTesting
class UnrestrictedStoragePermission implements StoragePermissionPort {
  const UnrestrictedStoragePermission();

  @override
  Future<StoragePermissionState> check() async =>
      StoragePermissionState.notApplicable;

  /// **開かない。** desktop に対応する設定画面が無い。
  @override
  Future<bool> openSettings() async => false;
}

/// どの platform がどの port を使うかの写像。
///
/// **Android だけが制限を持つ。** desktop は [UnrestrictedStoragePermission] で
/// 素通しする — 013 は desktop の振る舞いを変えない。
///
/// **純関数として切り出してある。** `Platform.isAndroid` を条件式へ直接書くと、
/// 「Androidならどの port か」を Linux 上の test で固定できず、**分岐が消えても
/// 誰も気づかない**(独立review attempt 1 / 2 / 3 が3回続けてこの型を指摘した)。
/// ここを引数にすれば、写像そのものは**振る舞いで**固定できる。
///
/// **残るのは [createPlatformStoragePermission] の実引数1箇所だけ**である。
/// そこは Linux 上では観測できない — 兄弟の composition root
/// (`createPlatformFileSource` / `createPlatformRenameExecutor`)が元から
/// 抱えているのと**同じ露出**であり、`013:T08` の実機確認が引き受ける。
StoragePermissionPort storagePermissionFor({required bool isAndroid}) =>
    isAndroid
    ? const AndroidStoragePermission()
    : const UnrestrictedStoragePermission();

/// 現在の platform に合う port を選ぶ composition root。
StoragePermissionPort createPlatformStoragePermission() =>
    storagePermissionFor(isAndroid: Platform.isAndroid);
