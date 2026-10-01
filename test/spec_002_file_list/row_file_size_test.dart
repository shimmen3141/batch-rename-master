// 008:T48 行の補足情報のファイルの大きさ(2026-10-01 の開発者の決定 A)。
//
// 「ファイルのサイズの情報も入れたい」→ 補足情報の日時の後ろへ、ラベル無しで
// `2.4 MB` の形で足す。002 REQ-010 は補足情報を「作成/更新日時・サイズと同格の副題」
// としている。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_size_format.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry({int size = 2516582}) => FileEntry(
  name: 'IMG_20261231_235959.jpg',
  createdAt: DateTime(2026, 12, 31, 23, 59),
  modifiedAt: DateTime(2026, 12, 31, 23, 59),
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
            controller: FileListController(files: [_entry(size: bytes)]),
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
  group('大きさの書き方(参考design の fmtSize + GB)', () {
    test('1024 未満は B', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('KB は整数に丸める', () {
      expect(formatFileSize(1024), '1 KB');
      expect(formatFileSize(1535), '1 KB');
      expect(formatFileSize(1536), '2 KB');
      expect(formatFileSize(1024 * 1023), '1023 KB');
    });

    test('MB は小数1桁。丸めで 1024 KB に届くものは 1.0 MB と書く', () {
      expect(formatFileSize(1024 * 1024 - 1), '1.0 MB');
      expect(formatFileSize(1024 * 1024), '1.0 MB');
      expect(formatFileSize(2516582), '2.4 MB');
      expect(formatFileSize(1024 * 1024 * 1023), '1023.0 MB');
    });

    test('GB は小数1桁。丸めで 1024.0 MB に届くものは 1.0 GB と書く', () {
      expect(formatFileSize(1024 * 1024 * 1024 - 1), '1.0 GB');
      expect(formatFileSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatFileSize((5.3 * 1024 * 1024 * 1024).round()), '5.3 GB');
    });
  });

  group('行の補足情報', () {
    testWidgets('日時の後ろにラベル無しで出て、日時と同じ見え方をする', (tester) async {
      await _pump(tester);

      final size = find.byKey(rowSizeKey);
      expect(size, findsOneWidget);
      expect(tester.widget<Text>(size).data, '2.4 MB');
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
            // いちばん長い書き方(`1023.0 MB`)で測る。
            bytes: 1024 * 1024 * 1023,
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
