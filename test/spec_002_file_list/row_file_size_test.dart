// 008:T48 行の補足情報のファイルの大きさ(2026-10-01 の開発者の決定 A)。
//
// 「ファイルのサイズの情報も入れたい」→ 補足情報の日時の後ろへ、ラベル無しで
// `2.4 MB` の形で足す。002 REQ-010 は補足情報を「作成/更新日時・サイズと同格の副題」
// としている。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_size_format.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry({int size = 2516582}) => FileEntry(
  name: 'IMG_20261231_235959.jpg',
  createdAt: DateTime(2026, 12, 31, 23, 59),
  // 作成日時と違う値(同じだと「作成・更新:」の1つにまとまる。`008:T61`)。
  modifiedAt: DateTime(2026, 12, 30, 23, 59),
  size: size,
  sourceHandle: '/storage/emulated/0/DCIM/Camera/IMG_20261231_235959.jpg',
);

/// 一覧を描き、その間の layout error(overflow を含む)を返す。
Future<List<String>> _pump(
  WidgetTester tester, {
  Size size = const Size(411, 800),
  double textScale = 1.0,
  int bytes = 2516582,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception.toString());
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: FileListView(
            // **いちばん長い補足情報**(作成日時・更新日時・大きさ)で測る。`008:T61`
            // 以降、行が出すのは並び順またはルールが使っている日時だけなので、
            // 並び順を作成日時にし、ルールに更新日時のトークンを入れる。
            controller: FileListController(
              files: [_entry(size: bytes)],
              rule: const RenameRule([
                DateTimeToken(source: DateTimeSource.modified, format: 'YYYY'),
              ]),
            )..setSortMode(FileSortMode.createdAt),
          ),
        ),
      ),
    ),
  );
  FlutterError.onError = previous;
  return errors;
}

bool _isTruncated(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  return paragraph.didExceedMaxLines;
}

void main() {
  group('大きさの書き方(有効数字3桁、1024 刻み、1000 に届いたら次の単位。008:T62)', () {
    test('1000 未満は B(丸めない)', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(999), '999 B');
    });

    test('1000 B からは KB。1未満・10未満は小数2桁、100未満は1桁、それ以上は整数', () {
      expect(formatFileSize(1000), '0.98 KB');
      expect(formatFileSize(1024), '1.00 KB');
      expect(formatFileSize(1536), '1.50 KB');
      expect(formatFileSize(10230), '9.99 KB');
      expect(formatFileSize(102350), '100 KB');
      expect(formatFileSize(1023487), '999 KB');
    });

    test('丸めで桁が上がったら小数を1桁減らす(4桁にしない)', () {
      // 9.995 KB → `10.00` ではなく `10.0`。
      expect(formatFileSize(10235), '10.0 KB');
      // 99.96 KB → `100.0` ではなく `100`。
      expect(formatFileSize(102359), '100 KB');
    });

    test('値が 1000 に届いたら(丸めで届いたものも)次の単位で書く', () {
      // 1023 KB は 0.999 MB。`1023 KB` とは書かない。
      expect(formatFileSize(1024 * 1023), '1.00 MB');
      // 999.6 KB は丸めると 1000 KB に届くので MB。
      expect(formatFileSize(1023590), '0.98 MB');
      expect(formatFileSize(1024 * 1024), '1.00 MB');
      expect(formatFileSize(2516582), '2.40 MB');
      // 以前は `1023.0 MB`(9文字)だった。
      expect(formatFileSize(1024 * 1024 * 1023), '1.00 GB');
      expect(formatFileSize(1024 * 1024 * 1000), '0.98 GB');
      expect(formatFileSize(1288490189), '1.20 GB');
    });

    test('GB より大きい単位は持たない(1000 GB 以上は整数の GB)', () {
      expect(formatFileSize(1024 * 1024 * 1024 * 1500), '1500 GB');
    });

    test('1500 GB までのどの大きさでも、7文字以下', () {
      var longest = '';
      for (var b = 0; b < 1024 * 1024 * 1024 * 1500; b = b * 1.01 ~/ 1 + 1) {
        final text = formatFileSize(b);
        if (text.length > longest.length) longest = text;
      }
      expect(longest.length, lessThanOrEqualTo(7), reason: longest);
    });
  });

  group('行の補足情報', () {
    testWidgets('日時の後ろにラベル無しで出て、日時と同じ見え方をする', (tester) async {
      await _pump(tester);

      final size = find.byKey(rowSizeKey);
      expect(size, findsOneWidget);
      expect(tester.widget<Text>(size).data, '2.40 MB');
      // 補足情報の中で、更新日時より後ろ(右か下)にある。
      final sizeRect = tester.getRect(size);
      final modified = tester.getRect(find.byKey(rowModifiedAtKey));
      expect(
        sizeRect.top > modified.top ||
            (sizeRect.top == modified.top && sizeRect.left > modified.left),
        isTrue,
      );
      // 同じ色・大きさ(補足情報の一部であって強調しない)。
      final sizeStyle = tester.widget<Text>(size).style!;
      final modifiedStyle = tester
          .widget<Text>(find.byKey(rowModifiedAtKey))
          .style!;
      expect(sizeStyle.color, modifiedStyle.color);
      expect(sizeStyle.fontSize, modifiedStyle.fontSize);
    });

    for (final width in [320.0, 360.0, 411.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('幅 $width・文字 ×$scale: はみ出さず、大きさが削られず、作成日時の行へ割り込まない', (
          tester,
        ) async {
          final errors = await _pump(
            tester,
            size: Size(width, 800),
            textScale: scale,
            // いちばん長い書き方(7文字。`0.98 GB`)で測る。
            bytes: 1024 * 1024 * 1000,
          );
          expect(errors, isEmpty);
          // 作成日時の省略は**この変更の前から字体と幅で決まる**(test の Ahem は
          // 1文字 = 1em と実際の字体より広い)。ここで見るのは、大きさを足したことで
          // 作成日時が**これ以上**削られないこと = 作成日時と同じ行へ割り込まないこと。
          final created = tester.getRect(find.byKey(rowCreatedAtKey));
          final size = tester.getRect(find.byKey(rowSizeKey));
          expect(size.top, greaterThan(created.top));
          expect(_isTruncated(tester, find.byKey(rowSizeKey)), isFalse);
        });
      }
    }
  });
}
