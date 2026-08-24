package com.example.batch_rename_master

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 全ファイルアクセス権限(`MANAGE_EXTERNAL_STORAGE`)を Dart へ橋渡しする
 * (013 REQ-001〜004)。
 *
 * **状態を保持しない。** 013 REQ-004 は「読み込みの直前と改名の実行直前に確認する。
 * 設定から取り消されうるため、一度確認した結果を持ち回らない」と定めている。
 * `isGranted` は毎回 `Environment.isExternalStorageManager()` を呼ぶ。
 *
 * **設定画面は Dart から明示的に呼ばれたときだけ開く**(013 REQ-003)。
 * ここから自動で開かない。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.example.batch_rename_master/storage_permission"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(isGranted())
                    "openSettings" -> result.success(openSettings())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * API 30 未満には `MANAGE_EXTERNAL_STORAGE` が無い。
     *
     * `minSdk` は 24 のままである(013 spec D-1)。この権限を取得できない端末では
     * **付与されていない**として扱い、読み込ませない(013 REQ-001)。
     * 013 spec D-1 が「API level を対応可否の代理指標にしない」と言っているのは
     * `renameat2` の話で、こちらは**権限そのものが存在しない**ので事情が違う。
     */
    private fun isGranted(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            Environment.isExternalStorageManager()

    /** 開けたら true。開けなければ false を返し、Dart 側が説明を出したまま留まる。 */
    private fun openSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
            true
        } catch (_: Exception) {
            // 端末によってはこの Intent を解決できない。全体の設定画面へ落とす。
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
