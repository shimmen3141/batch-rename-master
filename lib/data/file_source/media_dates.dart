import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// MediaStore が持つ、1つのファイルの日時(004 REQ-010 の②③)。
class MediaDates {
  const MediaDates({this.taken, this.added});

  /// `DATE_TAKEN`(撮影日時)。端末の時刻帯の [DateTime]。無ければ `null`。
  final DateTime? taken;

  /// `DATE_ADDED`(MediaStore に入った時刻 = この端末に作られた時刻)。
  /// 端末の時刻帯の [DateTime]。無ければ `null`。
  final DateTime? added;
}

/// path から MediaStore の日時を引く port(004 REQ-010 の②③)。
///
/// **引けなかった path は結果に含めない。** MediaStore に載っていない
/// (この app が path で作った file は載らない。`010:T04`)・この app から見えない
/// (`adb push` など shell が置いた file。`010:T03`)・照会に失敗した、は
/// どれも「②③が無い」であって、読み込みの失敗ではない。
abstract interface class MediaDatesPort {
  Future<Map<String, MediaDates>> datesOf(List<String> paths);
}

/// Android の MediaStore を platform channel 越しに引く。
///
/// **この class は Linux 上の test で Kotlin 側まで実行できない。** channel を
/// 差し替えて Dart 側の写像を確かめ、Kotlin 側が本当に値を返すかは端末の確認
/// (`010:T03` の manual)が引き受ける。`MethodChannelStorageVolumes` と同じ形である。
class MethodChannelMediaDates implements MediaDatesPort {
  const MethodChannelMediaDates();

  /// channel 名。Kotlin 側(`MainActivity.kt`)と一致させる。
  static const channel = MethodChannel(
    'com.example.batch_rename_master/media_dates',
  );

  /// 値は UTC の時刻(`DATE_TAKEN` はミリ秒、`DATE_ADDED` は秒)で届く。
  /// **端末の時刻帯へ直して**返す(004 REQ-010: UTC しか分からない値は端末の時刻帯)。
  ///
  /// channel が無い・失敗した・想定外の値は、**空の結果**(②③が無い)にする。
  /// 作成日時が不明になるだけで、読み込みは止めない(004 REQ-010)。
  @override
  Future<Map<String, MediaDates>> datesOf(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final Map<Object?, Object?>? raw;
    try {
      raw = await channel.invokeMethod<Map<Object?, Object?>>('datesOf', {
        'paths': paths,
      });
    } catch (error) {
      // 失敗は画面に出さない(作成日時が不明になるだけ)ので、logcat にだけ残す。
      debugPrint('media_dates: datesOf failed: $error');
      return const {};
    }
    if (raw == null) return const {};
    final result = <String, MediaDates>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is! String || value is! Map) continue;
      final taken = _positive(value['taken']);
      final added = _positive(value['added']);
      result[key] = MediaDates(
        taken: taken == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(taken),
        added: added == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(added * 1000),
      );
    }
    return result;
  }

  /// 0 以下は「記録していない」として扱う。
  static int? _positive(Object? value) =>
      value is int && value > 0 ? value : null;
}
