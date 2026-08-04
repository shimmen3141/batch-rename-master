// VER-005: 決定性・時計非参照・非依存の検証(FEAT-001)。
// 対象: REQ-013(決定性), INV-004(現在日時は入力 now を用い時計を参照しない),
//       INV-005(命名出力は sourceHandle / sourceLocation に依存しない),
//       CON-001(lib/core は package:flutter / dart:io に依存しない)。
import 'dart:io';

import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name, {bool selected = true}) => FileEntry(
  name: name,
  createdAt: DateTime(2020, 3, 4, 5, 6, 7),
  modifiedAt: DateTime(2021, 8, 9, 10, 11, 12),
  size: 0,
  selected: selected,
);

final DateTime _now = DateTime(2026, 7, 26, 9, 8, 7);

const RenameRule _rule = RenameRule([
  DateTimeToken(source: DateTimeSource.current, format: 'YYYYMMDD_'),
  SequenceToken(start: 1, digits: 1),
  LiteralToken('_'),
  OriginalNameToken(),
]);

void main() {
  group('REQ-013: 決定性(同一入力で同一出力)', () {
    final files = [
      _file('a.jpg'),
      _file('b.jpg', selected: false),
      _file('dup.txt'),
      _file('dup.txt'),
    ];

    test('generatePreview は2回呼んでも同一', () {
      final first = generatePreview(
        _rule,
        files,
        _now,
      ).map((e) => e.resultName).toList();
      final second = generatePreview(
        _rule,
        files,
        _now,
      ).map((e) => e.resultName).toList();
      expect(first, second);
    });

    test('validate は2回呼んでも同一(種別列)', () {
      List<String> kinds() => validate(
        _rule,
        files,
        _now,
      ).map((w) => w.runtimeType.toString()).toList();
      expect(kinds(), kinds());
    });

    test('autoResolve は2回呼んでも同一', () {
      List<String> names() =>
          autoResolve(_rule, files, _now).map((e) => e.resultName).toList();
      expect(names(), names());
    });
  });

  group('INV-004: 現在日時は入力 now を用いる(時計を参照しない)', () {
    test('過去の now を渡すとその値が反映される(実時刻ではない)', () {
      final past = DateTime(1999, 12, 31, 23, 59, 58);
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.current, format: 'YYYYMMDDHHmmss'),
      ]);
      expect(buildName(rule, _file('x'), 1, past), '19991231235958');
    });

    test('未来の now を渡すとその値が反映される', () {
      final future = DateTime(2099, 1, 2, 3, 4, 5);
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.current, format: 'YYYYMMDDHHmmss'),
      ]);
      expect(buildName(rule, _file('x'), 1, future), '20990102030405');
    });
  });

  group('INV-005: 命名出力は sourceHandle / sourceLocation に依存しない', () {
    /// 値は同じで、識別・表示用のメタデータだけが異なる複製。
    FileEntry withMeta(FileEntry file, {String? handle, String? location}) =>
        FileEntry(
          name: file.name,
          createdAt: file.createdAt,
          modifiedAt: file.modifiedAt,
          size: file.size,
          selected: file.selected,
          sourceHandle: handle,
          sourceLocation: location,
        );

    final plain = [
      _file('a.jpg'),
      _file('b.jpg', selected: false),
      _file('dup.txt'),
      _file('dup.txt'),
    ];
    final tagged = [
      withMeta(plain[0], handle: 'content://tree/photos/a.jpg', location: '写真'),
      withMeta(plain[1], handle: 'content://tree/dl/b.jpg', location: 'ダウンロード'),
      withMeta(plain[2], handle: 'file:///c/dup.txt', location: 'C:\\docs'),
      withMeta(plain[3], handle: 'file:///d/dup.txt', location: 'D:\\backup'),
    ];

    test('buildName はメタデータの有無で変わらない', () {
      expect(
        buildName(_rule, tagged.first, 1, _now),
        buildName(_rule, plain.first, 1, _now),
      );
    });

    test('generatePreview はメタデータの有無で変わらない', () {
      expect(
        generatePreview(_rule, tagged, _now).map((e) => e.resultName),
        generatePreview(_rule, plain, _now).map((e) => e.resultName),
      );
    });

    test('validate はメタデータの有無で変わらない(種別列)', () {
      expect(
        validate(_rule, tagged, _now).map((w) => w.runtimeType.toString()),
        validate(_rule, plain, _now).map((w) => w.runtimeType.toString()),
      );
    });

    test('autoResolve はメタデータの有無で変わらない', () {
      expect(
        autoResolve(_rule, tagged, _now).map((e) => e.resultName),
        autoResolve(_rule, plain, _now).map((e) => e.resultName),
      );
    });

    test('同名・別ハンドルでも重複解決は名前だけで決まる', () {
      // dup.txt が2件(別ハンドル)。ハンドルが違っても名前が同じなら衝突扱い。
      final resolved = autoResolve(
        _rule,
        tagged,
        _now,
      ).map((e) => e.resultName).toList();
      expect(resolved.toSet(), hasLength(resolved.length));
    });
  });

  group('CON-001: lib/core は package:flutter / dart:io に依存しない', () {
    test('lib/core の Dart ファイルの import/export に禁止依存が無い', () {
      final dartFiles = Directory('lib/core')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(dartFiles, isNotEmpty);
      for (final file in dartFiles) {
        final directives = file.readAsLinesSync().where((line) {
          final trimmed = line.trimLeft();
          return trimmed.startsWith('import ') || trimmed.startsWith('export ');
        });
        for (final directive in directives) {
          expect(
            directive.contains('package:flutter'),
            isFalse,
            reason: '${file.path}: $directive',
          );
          expect(
            directive.contains('dart:io'),
            isFalse,
            reason: '${file.path}: $directive',
          );
          expect(
            directive.contains('dart:ui'),
            isFalse,
            reason: '${file.path}: $directive',
          );
        }
      }
    });
  });
}
