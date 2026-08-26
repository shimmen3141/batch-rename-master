package com.example.batch_rename_master

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 全ファイルアクセス権限(`MANAGE_EXTERNAL_STORAGE`)と**保存場所の列挙**を
 * Dart へ橋渡しする(013 REQ-001〜004、004 REQ-015)。
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
    private val volumesChannelName = "com.example.batch_rename_master/storage_volumes"

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, volumesChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "list" -> storageVolumes(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 共有ストレージのボリュームを列挙する(004 REQ-015)。
     *
     * **`/storage` を歩いて探さない。** app からは `EACCES` で列挙できず、装着されて
     * いる媒体を1つも見つけられないことが `013:T08` の実機観測で分かった。
     * `StorageManager.getStorageVolumes()` は**プラットフォームが持っている一覧**を
     * そのまま返す。
     *
     * **mount されているものだけ返す。** 取り外し済みの volume を保存場所として
     * 並べると、開いた時点で失敗する。
     *
     * **失敗を空の一覧にしない。** `error` を返して Dart 側へ理由を渡す — 空の成功と
     * 区別できないと、「媒体が無い」と「取得できていない」が混ざる(013:T12)。
     */
    private fun storageVolumes(result: MethodChannel.Result) {
        // `StorageVolume.getDirectory()` は API 30 から。全ファイルアクセス権限
        // (`MANAGE_EXTERNAL_STORAGE`)も API 30 からで、それが無ければ browser は
        // 開かない(013 REQ-001)。**この経路は API 30 未満では到達しない。**
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error(
                "unsupported",
                "この Android では保存場所を列挙できません",
                null,
            )
            return
        }
        try {
            val manager = getSystemService(StorageManager::class.java)
            if (manager == null) {
                result.error("unavailable", "StorageManager を取得できませんでした", null)
                return
            }
            val volumes = manager.storageVolumes.mapNotNull { volume ->
                if (volume.state != Environment.MEDIA_MOUNTED) return@mapNotNull null
                val directory = volume.directory ?: return@mapNotNull null
                mapOf(
                    "path" to directory.absolutePath,
                    "name" to volume.getDescription(this),
                )
            }
            result.success(volumes)
        } catch (error: Exception) {
            result.error("failed", error.message ?: error.toString(), null)
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
