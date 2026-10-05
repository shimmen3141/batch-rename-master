// platform channel の名前が Kotlin 側と一致していることを見る。
//
// **ずれると機能が丸ごと死ぬ**(`MissingPluginException`)。Dart の test は channel を
// mock 相手に差し替えるので、**自分自身とは常に一致してしまい、ずれを検出できない**
// (`013:T12` の独立review attempt 1 の P2-5)。**Kotlin の source を読んで突き合わせる。**
//
// **これは文字列の一致だけを見る。** Kotlin が本当に handler を登録しているか、
// method 名が合っているかまでは分からない — それは実機確認が引き受ける。

import 'dart:io';

import 'package:batch_rename_master/data/file_source/media_dates.dart';
import 'package:batch_rename_master/data/file_source/media_library.dart';
import 'package:batch_rename_master/data/file_source/storage_volumes.dart';
import 'package:batch_rename_master/data/permission/android_storage_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'android/app/src/main/kotlin/com/example/batch_rename_master/MainActivity.kt',
  );

  test('MainActivity.kt が読める(このtestの前提)', () {
    expect(source.existsSync(), isTrue, reason: '${source.path} が無い');
  });

  test('保存場所の channel 名が Kotlin 側にある(004 REQ-015)', () {
    expect(
      source.readAsStringSync(),
      contains('"${MethodChannelStorageVolumes.channel.name}"'),
    );
  });

  test('MediaStore の日時の channel 名が Kotlin 側にある(004 REQ-010。010:T03)', () {
    expect(
      source.readAsStringSync(),
      contains('"${MethodChannelMediaDates.channel.name}"'),
    );
  });

  test('写真・動画の一覧の channel 名が Kotlin 側にある(004 REQ-022。010:T06)', () {
    expect(
      source.readAsStringSync(),
      contains('"${MethodChannelMediaLibrary.channel.name}"'),
    );
  });

  // **種類は文字列で渡る。** Dart の enum 名を変えると Kotlin 側の行を落とす
  // (一覧が空になる)。絞り込みは `010:T11` から Dart の側で行う。
  test('種類の文字列が Kotlin 側と一致する(004 REQ-022。010:T06)', () {
    final kotlin = source.readAsStringSync();
    for (final kind in MediaKind.values) {
      expect(kotlin, contains('-> "${kind.name}"'), reason: '行の種類 $kind');
    }
  });

  test('権限の channel 名が Kotlin 側にある(013 REQ-001)', () {
    expect(
      source.readAsStringSync(),
      contains('"${AndroidStoragePermission.channel.name}"'),
    );
  });
}
