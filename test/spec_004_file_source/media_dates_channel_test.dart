// 004 REQ-010 の②③: MediaStore の日時を platform から受け取る側の写像(`010:T03`)。
//
// **Kotlin 側が本当に値を返すかは、ここでは分からない。** channel の相手を差し替えて、
// 返ってきた値をどう読むかだけを閉じる。端末は `010:T03` の manual が引き受ける。

import 'package:batch_rename_master/data/file_source/media_dates.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const port = MethodChannelMediaDates();

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      MethodChannelMediaDates.channel,
      handler,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        MethodChannelMediaDates.channel,
        null,
      ),
    );
  }

  test('path の一覧を渡し、DATE_TAKEN(ミリ秒)と DATE_ADDED(秒)を端末の時刻帯で返す', () async {
    MethodCall? received;
    final taken = DateTime.utc(2026, 7, 1, 1);
    final added = DateTime.utc(2026, 9, 1, 3);
    answerWith((call) async {
      received = call;
      return {
        '/a.jpg': {'taken': taken.millisecondsSinceEpoch, 'added': null},
        '/b.pdf': {
          'taken': null,
          'added': added.millisecondsSinceEpoch ~/ 1000,
        },
      };
    });

    final result = await port.datesOf(['/a.jpg', '/b.pdf', '/c.txt']);

    expect(received!.method, 'datesOf');
    expect(received!.arguments, {
      'paths': ['/a.jpg', '/b.pdf', '/c.txt'],
    });
    expect(result['/a.jpg']!.taken, taken.toLocal());
    expect(result['/a.jpg']!.added, isNull);
    expect(result['/b.pdf']!.taken, isNull);
    expect(result['/b.pdf']!.added, added.toLocal());
    // MediaStore に載っていない path は結果に無い。
    expect(result.containsKey('/c.txt'), isFalse);
  });

  test('0 は「記録していない」として null', () async {
    answerWith(
      (call) async => {
        '/a.jpg': {'taken': 0, 'added': 0},
      },
    );

    final dates = (await port.datesOf(['/a.jpg']))['/a.jpg']!;

    expect(dates.taken, isNull);
    expect(dates.added, isNull);
  });

  test('失敗・channel が無い・想定外の値は空の結果(読み込みを止めない)', () async {
    answerWith((call) async => throw PlatformException(code: 'failed'));
    expect(await port.datesOf(['/a.jpg']), isEmpty);

    answerWith((call) async => ['not', 'a', 'map']);
    expect(await port.datesOf(['/a.jpg']), isEmpty);

    answerWith(
      (call) async => {
        '/a.jpg': 'not a map',
        3: {'taken': 1},
      },
    );
    expect(await port.datesOf(['/a.jpg']), isEmpty);
  });

  test('path が無ければ照会しない', () async {
    var called = false;
    answerWith((call) async {
      called = true;
      return {};
    });

    expect(await port.datesOf(const []), isEmpty);
    expect(called, isFalse);
  });
}
