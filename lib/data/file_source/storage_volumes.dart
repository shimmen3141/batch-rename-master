import 'package:flutter/services.dart';

/// プラットフォームが共有ストレージのボリュームとして列挙する1件(004 REQ-015)。
///
/// **path と、利用者へ見せる名前だけを持つ。** 取り外し可能かどうかを持たないのは、
/// **004 REQ-015 が保存場所として区別していない**からである(内部共有ストレージも
/// SD カードも「保存場所」で、遡行の上限が root であることは同じ)。
class StorageVolume {
  const StorageVolume({required this.path, required this.name});

  /// この volume の root の絶対 path。
  final String path;

  /// 利用者へ見せる名前(「内部ストレージ」「SD カード」など)。
  final String name;
}

/// [StorageVolumesPort.list] の結果。
///
/// **「取得できなかった」と「1件も無い」を型で区別する。** 004 REQ-014 が
/// `listNames` に課しているのと同じ規律である。
///
/// **この区別を持たなかったことが、実際に問題を隠した** — `013:T08` の実機観測まで、
/// 「取り外し可能な媒体が無い端末」と「列挙できていない」を誰も区別できなかった
/// (`013:T12` の task.md)。
sealed class StorageVolumesResult {
  const StorageVolumesResult();
}

/// 取得できた。**空でも「取得できた」である。**
class VolumesListed extends StorageVolumesResult {
  const VolumesListed(this.volumes);

  final List<StorageVolume> volumes;
}

/// 取得できなかった。**空の [VolumesListed] と混同しない。**
class VolumesUnavailable extends StorageVolumesResult {
  const VolumesUnavailable(this.reason);

  /// 利用者と開発者の両方が読める理由。
  final String reason;
}

/// 保存場所のボリュームを供給する port。
///
/// **filesystem を歩いて探さない。** `/storage` の列挙は app から `EACCES` になり、
/// **装着されている媒体を1つも見つけられない**ことが `013:T08` の実機観測で分かった。
abstract interface class StorageVolumesPort {
  Future<StorageVolumesResult> list();
}

/// Android の `StorageManager.getStorageVolumes()` を platform channel 越しに読む。
///
/// **この class は Linux 上の test で実行できない**(channel の相手が居ない)。
/// `TestDefaultBinaryMessenger` で channel を差し替えれば **Dart 側の写像**は検査
/// できるが、**Kotlin 側が本当に volume を返すかは実機確認**が引き受ける
/// (`013:T12` の task.md の宣言表)。`AndroidStoragePermission` と同じ形である。
class MethodChannelStorageVolumes implements StorageVolumesPort {
  const MethodChannelStorageVolumes();

  /// channel 名。Kotlin 側(`MainActivity.kt`)と一致させる。
  static const channel = MethodChannel(
    'com.example.batch_rename_master/storage_volumes',
  );

  /// **失敗を握りつぶさない。**
  ///
  /// channel が無い、Kotlin 側が例外を投げた、想定外の値が返った — いずれも
  /// [VolumesUnavailable] である。**空の一覧へ落とすと、装着されている媒体を
  /// 「無い」と見せてしまう。**
  @override
  Future<StorageVolumesResult> list() async {
    final List<Object?>? raw;
    try {
      raw = await channel.invokeMethod<List<Object?>>('list');
    } catch (error) {
      return VolumesUnavailable('保存場所を取得できませんでした: $error');
    }
    if (raw == null) {
      return const VolumesUnavailable('保存場所を取得できませんでした: 応答がありません');
    }
    final volumes = <StorageVolume>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final path = entry['path'];
      final name = entry['name'];
      // **path が無い行は落とす。** 名前だけあっても辿れない。
      if (path is! String || path.isEmpty) continue;
      volumes.add(
        StorageVolume(
          path: path,
          name: name is String && name.isNotEmpty ? name : path,
        ),
      );
    }
    return VolumesListed(volumes);
  }
}
