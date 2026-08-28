// 008:T07 preview の cache と同時実行の上限。
//
// `T13` が「先に決めること」として挙げていた**数百件あるときのメモリと速度**を
// ここで閉じる。行が見えるたびに decode し直す・folder の件数だけ同時に走る、の
// どちらも起きないことを固定する。
import 'package:batch_rename_master/core/file_entry.dart';
import 'package:batch_rename_master/data/preview/cached_file_preview.dart';
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {DateTime? modifiedAt}) => FileEntry(
  name: name,
  modifiedAt: modifiedAt ?? DateTime(2026, 8, 4, 16),
  size: 0,
  sourceHandle: '/storage/emulated/0/DCIM/$name',
);

void main() {
  test('同じ file を2度目は読み直さない', () async {
    final inner = FakeFilePreview();
    final port = CachedFilePreview(inner);

    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);

    expect(inner.requested, hasLength(1));
  });

  test('同時に来た同じ要求は1回にまとめる', () async {
    // scroll で同じ行が作り直されると、応答前に同じ鍵が重なる。
    final inner = FakeFilePreview()..hold = true;
    final port = CachedFilePreview(inner);

    final first = port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    final second = port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await Future<void>.delayed(Duration.zero);
    inner.release();
    await Future.wait([first, second]);

    expect(inner.requested, hasLength(1));
  });

  test('長辺が違えば別の絵として作り直す', () async {
    final inner = FakeFilePreview();
    final port = CachedFilePreview(inner);

    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await port.thumbnail(_entry('a.jpg'), maxEdge: 256);

    expect(inner.requested, hasLength(2));
  });

  test('更新日時が変われば作り直す(差し替わった file に古い絵を出さない)', () async {
    final inner = FakeFilePreview();
    final port = CachedFilePreview(inner);

    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await port.thumbnail(
      _entry('a.jpg', modifiedAt: DateTime(2026, 8, 5, 9)),
      maxEdge: 128,
    );

    expect(inner.requested, hasLength(2));
  });

  test('上限を超えたら古いものから捨てる', () async {
    final inner = FakeFilePreview();
    final port = CachedFilePreview(inner, maxEntries: 2);

    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await port.thumbnail(_entry('b.jpg'), maxEdge: 128);
    await port.thumbnail(_entry('c.jpg'), maxEdge: 128);

    // 保持量が件数で頭打ちになる。数千件の folder でも増え続けない。
    expect(port.entryCount, 2);

    // a は捨てられているので読み直しになる。
    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    expect(
      inner.requested,
      [
        'a.jpg',
        'b.jpg',
        'c.jpg',
        'a.jpg',
      ].map((n) => '/storage/emulated/0/DCIM/$n'),
    );
  });

  test('参照した鍵は捨てられにくくなる(LRU であって FIFO ではない)', () async {
    final inner = FakeFilePreview();
    final port = CachedFilePreview(inner, maxEntries: 2);

    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await port.thumbnail(_entry('b.jpg'), maxEdge: 128);
    // a を触り直す。FIFO ならこの後 a が落ちるが、LRU なら b が落ちる。
    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    await port.thumbnail(_entry('c.jpg'), maxEdge: 128);

    await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    expect(
      inner.requested.where((h) => h.endsWith('a.jpg')),
      hasLength(1),
      reason: 'a は触り直したので残っているはず',
    );
  });

  test('同時に走る数を上限で抑える', () async {
    final inner = FakeFilePreview()..hold = true;
    final port = CachedFilePreview(inner, maxConcurrent: 3);

    // 速く scroll したときのように、一度に多くの行が要求する。
    final all = [
      for (var i = 0; i < 20; i++)
        port.thumbnail(_entry('f$i.jpg'), maxEdge: 128),
    ];
    await Future<void>.delayed(Duration.zero);

    expect(inner.requested, hasLength(3), reason: '上限を超えて同時に file を開かない');

    inner.release();
    await Future.wait(all);
    // 残りは順番に走り、取りこぼさない。
    expect(inner.requested, hasLength(20));
  });

  test('一巡した後もまた走る(席を返している)', () async {
    // **1回の burst だけでは席の返し忘れが見えない。** 返し忘れると、走っている
    // 数が上限のまま固定され、**2回目以降の要求が永久に待つ**(scroll しても
    // preview が二度と出ない)。上限の検査は1回目で通ってしまう。
    final inner = FakeFilePreview()..hold = true;
    final port = CachedFilePreview(inner, maxConcurrent: 2);

    final first = [
      for (var i = 0; i < 4; i++)
        port.thumbnail(_entry('a$i.jpg'), maxEdge: 128),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(inner.requested, hasLength(2));
    inner.release();
    await Future.wait(first);
    expect(inner.requested, hasLength(4));

    inner.hold = true;
    final second = [
      for (var i = 0; i < 4; i++)
        port.thumbnail(_entry('b$i.jpg'), maxEdge: 128),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(
      inner.requested,
      hasLength(6),
      reason: '席が返っていないので2回目の burst が始まらない',
    );

    inner.release();
    await Future.wait(second);
    expect(inner.requested, hasLength(8));
  });

  test('失敗も覚える(読めない file を毎回叩き直さない)', () async {
    final inner = FakeFilePreview(fallback: const PreviewFailed('壊れている'));
    final port = CachedFilePreview(inner);

    final first = await port.thumbnail(_entry('a.jpg'), maxEdge: 128);
    final second = await port.thumbnail(_entry('a.jpg'), maxEdge: 128);

    expect(first, isA<PreviewFailed>());
    expect(second, isA<PreviewFailed>());
    expect(inner.requested, hasLength(1));
  });
}
