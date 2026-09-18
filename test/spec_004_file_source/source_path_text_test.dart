// 008:T23 場所の文字列を、幅に入らないときは**先頭を省略して**出す。
//
// 実機で `Internal shared storage/DCIM/t07-fixtures` が `Internal shared st…` と
// なり、**判別に効く末尾が消えた**(2026-09-18 の実機確認)。004 REQ-009 は文字列が
// 人間可読であることしか定めておらず省略の向きを決めていないため、開発者の決定
// (案A = 先頭を省略して末尾を残す)をここで固定する。
//
// **幅は実測で組む。** 期待値を px で書くと font が変わった瞬間に意味を失うので、
// 「この候補がちょうど入る幅」を測ってから境界を当てる。
import 'package:batch_rename_master/ui/file_source/source_path_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 12);
const _path = 'Internal shared storage/DCIM/t07-fixtures';

/// [text] を1行で描いたときの幅。
double _w(
  String text, {
  TextScaler scaler = TextScaler.noScaling,
  TextStyle style = _style,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

String _shown(double maxWidth, {String text = _path, TextScaler? scaler}) =>
    visibleSourcePathOf(
      text,
      maxWidth: maxWidth,
      style: _style,
      textScaler: scaler ?? TextScaler.noScaling,
    );

void main() {
  group('末尾を優先して幅へ収める', () {
    test('ちょうど入る幅なら、丸ごと出す', () {
      // `<` で判定していると、ぴったりの幅で不要な省略が始まる。
      expect(_shown(_w(_path)), _path);
    });

    test('入らなければ、先頭のsegmentを落として `…/` を付ける', () {
      expect(_shown(_w(_path) - 1), '…/DCIM/t07-fixtures');
    });

    test('落としすぎない — 入る中でいちばん長いものを選ぶ', () {
      // `…/DCIM/t07-fixtures` がちょうど入る幅では、`…/t07-fixtures` へ落とさない。
      expect(_shown(_w('…/DCIM/t07-fixtures')), '…/DCIM/t07-fixtures');
      expect(_shown(_w('…/DCIM/t07-fixtures') - 1), '…/t07-fixtures');
    });

    test('最後のsegmentだけでも入らないときは、そのsegmentを返す', () {
      // ここだけ向きが逆になる(`Text` の ellipsis が末尾を削り、folder名の頭が残る)。
      // **`…/` を付けたまま返さない** — 付けると読める文字がさらに減る。
      expect(_shown(_w('…/t07-fixtures') - 1), 't07-fixtures');
    });

    test('文字を大きくすると、同じ幅でも段が落ちる', () {
      // 倍率を無視して測ると、実機の大きい文字設定で予測が外れる。
      final justFits = _w(_path);
      expect(_shown(justFits), _path);
      expect(
        _shown(justFits, scaler: const TextScaler.linear(2.0)),
        isNot(_path),
      );
    });

    test('幅が決まっていないところでは縮めない', () {
      expect(_shown(double.infinity), _path);
    });
  });

  group('path として扱えない文言は形を変えない', () {
    test('`/` を含まない文言はそのまま', () {
      for (final label in ['未選択', '複数のフォルダ', 'DCIM']) {
        expect(_shown(1, text: label), label);
      }
    });

    test('末尾の `/` で `…/` だけにならない', () {
      expect(_shown(1, text: 'DCIM/'), 'DCIM/');
    });

    test('空のsegmentは段として数えない', () {
      expect(_shown(1, text: 'a//b'), 'b');
    });
  });

  group('SourcePathText', () {
    Future<String> pumpInBox(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const SourcePathText(
                  text: _path,
                  style: _style,
                  textKey: Key('probe'),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.byKey(const Key('probe'))).data!;
    }

    testWidgets('箱の幅に合わせて先頭を落とす', (tester) async {
      // **実際に描かれる体裁で測る。** `Text` は `DefaultTextStyle` と混ぜてから
      // 描くので、`_style` だけで測ると境界が数px ずれる(widget自身も混ぜた結果で
      // 測っている)。
      await pumpInBox(tester, 400);
      final effective = tester
          .widget<Text>(find.byKey(const Key('probe')))
          .style!;
      double w(String text) => _w(text, style: effective);

      expect(await pumpInBox(tester, w(_path)), _path);
      expect(
        await pumpInBox(tester, w('…/DCIM/t07-fixtures')),
        '…/DCIM/t07-fixtures',
      );
      expect(await pumpInBox(tester, w('…/t07-fixtures')), '…/t07-fixtures');
      // 1段ぶん狭いと、次の候補へ落ちる(落としすぎないことの対)。
      expect(
        await pumpInBox(tester, w('…/DCIM/t07-fixtures') - 1),
        '…/t07-fixtures',
      );
    });

    testWidgets('`textKey` は実際に描く段落に付く', (tester) async {
      // 省略の有無を `RenderParagraph` で確かめる検査があるので、鍵が
      // wrapper に付いていると掴めない。
      await pumpInBox(tester, _w('…/t07-fixtures'));
      expect(
        tester
            .renderObject<RenderParagraph>(find.byKey(const Key('probe')))
            .didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('入らないときも、はみ出さずに末尾を省略する', (tester) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exception.toString());
      final shown = await pumpInBox(tester, _w('t07-fix'));
      FlutterError.onError = previous;

      expect(shown, 't07-fixtures');
      expect(errors.where((e) => e.contains('overflow')), isEmpty);
      expect(
        tester
            .renderObject<RenderParagraph>(find.byKey(const Key('probe')))
            .didExceedMaxLines,
        isTrue,
      );
    });
  });
}
