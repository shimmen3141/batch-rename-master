// 電話では縦に固定していることを見る(`008:T35`)。
//
// 横向きの電話 × 大きな文字では一覧とルールの固定部分が溢れる(縞模様)。直さずに
// 縦へ固定すると決めたので、**固定が外れると縞模様が戻る**。manifest は Dart の test から
// 観測できないので、source を読んで確かめる。回転しないこと自体は実機確認が引き受ける。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('AndroidManifest.xml が読める(このtestの前提)', () {
    expect(manifest.existsSync(), isTrue, reason: '${manifest.path} が無い');
  });

  test('MainActivity を縦に固定している(008:T35)', () {
    final source = manifest.readAsStringSync();
    final activity = RegExp(
      r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>',
    ).firstMatch(source);
    expect(activity, isNotNull, reason: 'MainActivity の activity 要素が無い');
    expect(
      activity!.group(0),
      contains('android:screenOrientation="portrait"'),
    );
  });
}
