package com.example.batch_rename_master

import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

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
    private val videoThumbnailChannelName =
        "com.example.batch_rename_master/video_thumbnail"
    private val mediaDatesChannelName = "com.example.batch_rename_master/media_dates"
    private val logTag = "BatchRenameMaster"

    /**
     * 動画の frame 取り出しを main thread から外す(008:T07)。
     *
     * `MediaMetadataRetriever` は decode を伴い数十〜数百 ms かかる。main thread で
     * 走らせると一覧の scroll が引っかかる。同時に走る数は **Dart 側の
     * `CachedFilePreview` が上限を持つ**ので、ここは素直な pool でよい。
     */
    private val thumbnailExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Activity が破棄された後に channel へ返さないための印(008:T07)。
     *
     * `shutdownNow` は**走行中の1件を止めない**ので、破棄後に `result` を触りうる。
     */
    @Volatile
    private var destroyed = false

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            videoThumbnailChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "thumbnail" -> videoThumbnail(call, result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaDatesChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "datesOf" -> mediaDates(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * path ごとに MediaStore の `DATE_TAKEN`(ミリ秒)と `DATE_ADDED`(秒)を返す
     * (004 REQ-010 の②③。010:T03)。どちらも UTC で、端末の時刻帯へ直すのは Dart 側。
     *
     * **MediaStore に載っていない path は結果に含めない。** この app が path で
     * 作った file は載らない(010:T04 の端末観測)。値が無い列は `null`。
     *
     * 照会は main thread から外す(件数が多いと数十 ms を超えうる)。SQLite の
     * 変数の上限(999)を超えないよう、path を分けて照会する。
     */
    private fun mediaDates(call: MethodCall, result: MethodChannel.Result) {
        // `MediaColumns.DATE_TAKEN` は API 29 から。全ファイルアクセス権限は API 30
        // からで、それが無ければ読み込めない(013 REQ-001)ので、通常は到達しない。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(emptyMap<String, Any?>())
            return
        }
        val paths = call.argument<List<String>>("paths") ?: emptyList()
        thumbnailExecutor.execute {
            // Dart は失敗を「②③が無い」として黙って扱う(読み込みを止めない)ので、
            // 引けたか・なぜ引けなかったかは logcat にだけ残す(010:T03 の切り分け)。
            val response = try {
                val dates = queryMediaDates(paths)
                Log.i(logTag, "datesOf: ${paths.size} paths, ${dates.size} found")
                DatesResponse.Success(dates)
            } catch (error: Exception) {
                Log.w(logTag, "datesOf failed", error)
                DatesResponse.Failure(error.message ?: error.toString())
            }
            mainHandler.post {
                if (destroyed) return@post
                when (response) {
                    is DatesResponse.Success -> result.success(response.dates)
                    is DatesResponse.Failure -> result.error("failed", response.message, null)
                }
            }
        }
    }

    private sealed class DatesResponse {
        class Success(val dates: Map<String, Map<String, Long?>>) : DatesResponse()
        class Failure(val message: String) : DatesResponse()
    }

    private fun queryMediaDates(paths: List<String>): Map<String, Map<String, Long?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyMap()
        val dates = mutableMapOf<String, Map<String, Long?>>()
        val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.MediaColumns.DATA,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        for (chunk in paths.distinct().chunked(500)) {
            val selection = MediaStore.MediaColumns.DATA +
                " IN (" + chunk.joinToString(",") { "?" } + ")"
            contentResolver.query(uri, projection, selection, chunk.toTypedArray(), null)
                ?.use { cursor ->
                    val data = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                    val taken = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_TAKEN)
                    val added = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                    while (cursor.moveToNext()) {
                        val path = cursor.getString(data) ?: continue
                        dates[path] = mapOf(
                            "taken" to if (cursor.isNull(taken)) null else cursor.getLong(taken),
                            "added" to if (cursor.isNull(added)) null else cursor.getLong(added),
                        )
                    }
                }
        }
        return dates
    }

    override fun onDestroy() {
        destroyed = true
        thumbnailExecutor.shutdownNow()
        super.onDestroy()
    }

    /**
     * 動画の1frame目を PNG で返す(008:T07)。
     *
     * **`null` を返すのは「frame を取り出せなかった」ときだけ。** Dart 側は
     * `null` を [PreviewFailed] として扱い、「preview の無い file」とは区別する。
     * この channel がそもそも無い platform(Windows)では `MissingPluginException`
     * になり、そちらは対象外として扱われる。
     *
     * **frame は縮めてから取り出す。** 4K の1frameは bitmap で 30MB を超える。
     * `getScaledFrameAtTime` は decode 時に縮めるので、その大きさを確保しない。
     */
    private fun videoThumbnail(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val maxEdge = call.argument<Int>("maxEdge") ?: 128
        if (path.isNullOrEmpty()) {
            result.error("invalid", "path が指定されていません", null)
            return
        }
        thumbnailExecutor.execute {
            val response = try {
                Response.Success(encodeVideoFrame(path, maxEdge))
            } catch (error: Exception) {
                Response.Failure(error.message ?: error.toString())
            }
            // channel の応答は main thread から返す。
            mainHandler.post {
                // 破棄済みなら黙って捨てる。応答先がもう居ない。
                if (destroyed) return@post
                when (response) {
                    is Response.Success -> result.success(response.bytes)
                    is Response.Failure -> result.error("failed", response.message, null)
                }
            }
        }
    }

    private sealed class Response {
        class Success(val bytes: ByteArray?) : Response()
        class Failure(val message: String) : Response()
    }

    /** frame を取り出して PNG へ。取り出せなければ `null`。 */
    private fun encodeVideoFrame(path: String, maxEdge: Int): ByteArray? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val frame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(
                    0,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    maxEdge,
                    maxEdge,
                )
            } else {
                // API 27 未満には縮小付きの取り出しが無い。**この経路は通常
                // 到達しない** — 一覧は全ファイルアクセス権限(API 30 以降)を
                // 前提にしている(013 REQ-001)。到達しても壊れないようにだけ
                // しておく。
                retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?.let { scaleDown(it, maxEdge) }
            } ?: return null
            try {
                return ByteArrayOutputStream().use { stream ->
                    frame.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    stream.toByteArray()
                }
            } finally {
                // **`compress` が投げても解放する。** `use` が閉じるのは stream
                // だけで、bitmap はここで返さないと漏れる。
                frame.recycle()
            }
        } finally {
            retriever.release()
        }
    }

    /** 長辺を [maxEdge] 以下に縮める。元が小さければ拡大しない。 */
    private fun scaleDown(source: Bitmap, maxEdge: Int): Bitmap {
        val longest = maxOf(source.width, source.height)
        if (longest <= maxEdge) return source
        val scale = maxEdge.toDouble() / longest
        val scaled = Bitmap.createScaledBitmap(
            source,
            (source.width * scale).toInt().coerceAtLeast(1),
            (source.height * scale).toInt().coerceAtLeast(1),
            true,
        )
        if (scaled !== source) source.recycle()
        return scaled
    }

    /**
     * 共有ストレージのボリュームを列挙する(004 REQ-015)。
     *
     * **`/storage` を歩いて探さない。** app からは `EACCES` で列挙できず、装着されて
     * いる媒体を1つも見つけられないことが `013:T08` の実機観測で分かった。
     * `StorageManager.getStorageVolumes()` は**プラットフォームが持っている一覧**を
     * そのまま返す。
     *
     * **開ける volume だけ返す。** 取り外し済み・未 mount のものを保存場所として
     * 並べると、開いた時点で失敗する。**読み取り専用で mount されているものは並べる** —
     * 004 REQ-015 の「装着されている」に当たり、開いて辿れるからである。書き込め
     * ないことは 004 REQ-018 の注記と 005 REQ-013 の実行結果が示す。**列挙から
     * 落とすのは「判定で機能を止める」側**で、004 の方針と逆向きである
     * (独立review attempt 1 の P1-1)。
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
                val state = volume.state
                if (state != Environment.MEDIA_MOUNTED &&
                    state != Environment.MEDIA_MOUNTED_READ_ONLY
                ) {
                    return@mapNotNull null
                }
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
