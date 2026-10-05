package com.example.batch_rename_master

import android.annotation.TargetApi
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.util.Size
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
    private val mediaLibraryChannelName = "com.example.batch_rename_master/media_library"
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaLibraryChannelName)
            .setMethodCallHandler { call, result ->
                // 一覧は全ファイルアクセス権限(API 30 以降)を前提にする(004 REQ-022 は
                // 付与されていない間は開かない)。query args の `LIMIT`・`OFFSET` も
                // API 30 から MediaStore が受け付ける。**通常は到達しない。**
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                    result.error("unsupported", "この Android では写真・動画を一覧できません", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "list" -> onBackground(result, "list") { mediaList() }
                    "albums" -> onBackground(result, "albums") { mediaAlbums() }
                    "thumbnail" -> onBackground(result, "thumbnail") { mediaThumbnail(call) }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * [work] を main thread の外で走らせ、結果を main thread から返す(010:T06)。
     *
     * **失敗は `error` で返す。** Dart 側は一覧・アルバムの失敗を「無い」と区別して
     * 画面に理由を出す(004 REQ-022)。理由は logcat にも残す。
     */
    private fun onBackground(
        result: MethodChannel.Result,
        name: String,
        work: () -> Any?,
    ) {
        thumbnailExecutor.execute {
            val response = try {
                Answer.Success(work())
            } catch (error: Exception) {
                Log.w(logTag, "media_library: $name failed", error)
                Answer.Failure(error.message ?: error.toString())
            }
            mainHandler.post {
                if (destroyed) return@post
                when (response) {
                    is Answer.Success -> result.success(response.value)
                    is Answer.Failure -> result.error("failed", response.message, null)
                }
            }
        }
    }

    private sealed class Answer {
        class Success(val value: Any?) : Answer()
        class Failure(val message: String) : Answer()
    }

    /** 写真・動画の列(010:T06)。日時はどれも UTC で、端末の時刻帯へ直すのは Dart 側。 */
    private val mediaProjection = arrayOf(
        MediaStore.MediaColumns._ID,
        MediaStore.MediaColumns.DATA,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.MediaColumns.DATE_TAKEN,
        MediaStore.MediaColumns.DATE_ADDED,
        MediaStore.MediaColumns.DATE_MODIFIED,
        MediaStore.MediaColumns.DURATION,
        MediaStore.MediaColumns.BUCKET_ID,
        MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
    )

    /**
     * アルバムの代表(いちばん新しい item)を選ぶための順(010:T06)。`DATE_TAKEN` は
     * ミリ秒、`DATE_ADDED` は秒なので揃えてから比べる。**選択画面の並び順ではない** —
     * それは中身の日時も使うので Dart の側で決める(004 REQ-022。010:T11)。代表が
     * 選択画面の先頭と違うことはありうる(代表は見分けるための絵で、並びの約束ではない)。
     */
    private val mediaSortOrder = "COALESCE(" + MediaStore.MediaColumns.DATE_TAKEN + ", " +
        MediaStore.MediaColumns.DATE_ADDED + " * 1000) DESC, " +
        MediaStore.MediaColumns._ID + " DESC"

    /**
     * 写真・動画の全件を返す(004 REQ-022。010:T11)。**並べない・絞らない** —
     * 並び順に中身の日時が要る(`DATE_TAKEN` が無い item)ので、Dart の側で並べ、
     * 種類とアルバムでも Dart の側で絞る。
     *
     * **すべての保存場所を含む。** `VOLUME_EXTERNAL` は内部共有ストレージと SD カード等を
     * まとめて指す。**ゴミ箱・保存途中は含めない** — API 30 以降の MediaStore は既定で
     * 除くが、明示しておく。**この app から見えない行は返らない**(`adb push` で置いた
     * file など。010:T03)ので、それ以上の判定は作らない。
     */
    @TargetApi(Build.VERSION_CODES.R)
    private fun mediaList(): List<Map<String, Any?>> {
        val (selection, selectionArgs) = mediaSelection()
        val args = mediaQueryArgs(selection, selectionArgs)
        val items = mutableListOf<Map<String, Any?>>()
        contentResolver.query(mediaUri(), mediaProjection, args, null)?.use { cursor ->
            val columns = MediaColumns(cursor)
            while (cursor.moveToNext()) {
                columns.itemOf(cursor)?.let(items::add)
            }
        } ?: throw IllegalStateException("MediaStore が応答しませんでした")
        return items
    }

    /**
     * アルバム(写真・動画のある folder。MediaStore のバケット)の一覧を、いちばん新しい
     * item が新しい順に返す(004 REQ-022。010:T06)。
     *
     * MediaStore の `GROUP BY` には頼らない(selection へ書き込む抜け道は API 29 で
     * 塞がれ、それ以降の扱いも版で揃っていない)。新しい順に全件を歩いて集める。
     */
    @TargetApi(Build.VERSION_CODES.R)
    private fun mediaAlbums(): List<Map<String, Any?>> {
        val (selection, selectionArgs) = mediaSelection()
        val args = mediaQueryArgs(selection, selectionArgs).apply {
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, mediaSortOrder)
        }
        val albums = linkedMapOf<Long, MutableMap<String, Any?>>()
        contentResolver.query(mediaUri(), mediaProjection, args, null)?.use { cursor ->
            val columns = MediaColumns(cursor)
            while (cursor.moveToNext()) {
                if (cursor.isNull(columns.bucket)) continue
                val bucket = cursor.getLong(columns.bucket)
                val album = albums[bucket]
                if (album != null) {
                    album["count"] = (album["count"] as Int) + 1
                    continue
                }
                // 最初に出会う行がいちばん新しい。代表の item と場所はそこから取る。
                val cover = columns.itemOf(cursor) ?: continue
                val path = cover["path"] as String
                albums[bucket] = mutableMapOf(
                    "id" to bucket,
                    "name" to cursor.getString(columns.bucketName),
                    "folder" to (java.io.File(path).parent ?: path),
                    "count" to 1,
                    "cover" to cover,
                )
            }
        } ?: throw IllegalStateException("MediaStore が応答しませんでした")
        return albums.values.toList()
    }

    /**
     * MediaStore のサムネイルを JPEG で返す(010:T06)。作れなければ `null`。
     *
     * `loadThumbnail` は写真も動画も扱え、system が作ったものを使い回す。
     */
    @TargetApi(Build.VERSION_CODES.R)
    private fun mediaThumbnail(call: MethodCall): ByteArray? {
        val id = call.argument<Number>("id")?.toLong()
            ?: throw IllegalArgumentException("id が指定されていません")
        val maxEdge = call.argument<Int>("maxEdge") ?: 256
        val base = when (call.argument<String>("kind")) {
            "video" -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            else -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        }
        val uri = ContentUris.withAppendedId(base, id)
        val bitmap = try {
            contentResolver.loadThumbnail(uri, Size(maxEdge, maxEdge), null)
        } catch (error: java.io.IOException) {
            // 壊れた file・消えた行。選ぶことはできるので、サムネイルが無いだけにする。
            Log.w(logTag, "media_library: no thumbnail for $uri", error)
            return null
        }
        try {
            return ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                stream.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun mediaUri(): Uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    /** 写真・動画だけを選ぶ条件。 */
    private fun mediaSelection(): Pair<String, Array<String>> {
        val types = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )
        return MediaStore.Files.FileColumns.MEDIA_TYPE + " IN (?,?)" to types
    }

    @TargetApi(Build.VERSION_CODES.R)
    private fun mediaQueryArgs(selection: String, selectionArgs: Array<String>): Bundle =
        Bundle().apply {
            putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
            putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, selectionArgs)
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
            putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_EXCLUDE)
        }

    /** cursor の列番号と、1行を Dart へ渡す形にする写像。 */
    private class MediaColumns(cursor: android.database.Cursor) {
        val id = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
        val data = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
        val type = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
        val taken = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_TAKEN)
        val added = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
        val modified = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
        val duration = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DURATION)
        val bucket = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_ID)
        val bucketName =
            cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)

        /** path か種類が無い行は `null`(並べても読み込めない)。 */
        fun itemOf(cursor: android.database.Cursor): Map<String, Any?>? {
            val path = cursor.getString(data) ?: return null
            val kind = when (cursor.getInt(type)) {
                MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE -> "photo"
                MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO -> "video"
                else -> return null
            }
            return mapOf(
                "id" to cursor.getLong(id),
                "path" to path,
                "kind" to kind,
                "taken" to longOrNull(cursor, taken),
                "added" to longOrNull(cursor, added),
                "modified" to longOrNull(cursor, modified),
                "duration" to longOrNull(cursor, duration),
                "albumId" to longOrNull(cursor, bucket),
            )
        }

        private fun longOrNull(cursor: android.database.Cursor, column: Int): Long? =
            if (cursor.isNull(column)) null else cursor.getLong(column)
    }

    /**
     * path ごとに MediaStore の `DATE_TAKEN`(ミリ秒)と `DATE_ADDED`(秒)を返す
     * (004 REQ-010 の②③。010:T03)。どちらも UTC で、端末の時刻帯へ直すのは Dart 側。
     *
     * **MediaStore に載っていない・この app から見えない path は結果に含めない。**
     * この app が path で作った file は載らない(010:T04)。`adb push` など shell が
     * 置いた file は、載っていても全ファイルアクセス権限の app から見えない
     * (010:T03 の端末観測。カメラ・スクリーンショットは見える)。値が無い列は `null`。
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
            // なぜ引けなかったかは logcat にだけ残す。
            val response = try {
                DatesResponse.Success(queryMediaDates(paths))
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
