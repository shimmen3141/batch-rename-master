// VER-005 / VER-008(008:T54 分): 読み込んだ時点で folder の実在名を取り、実行buttonを
// 押す前から一覧の警告に読み込んでいない同名との重複を出す。
// 対象: 005 REQ-026(占有名との衝突は警告になる)/ REQ-028(一覧の警告は前に取った
//       実在名で評価してよい)/ OP-005(占有名 = 実在名 − 改名で空く名前)。
import 'dart:async';

import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/rename_exec/occupied_names.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/folder_names_sync.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {String folder = 'F'}) => FileEntry(
  name: name,
  createdAt: DateTime(2024, 3, 4),
  modifiedAt: DateTime(2026, 8, 4),
  size: 0,
  sourceHandle: '$folder/$name',
  sourceFolder: folder,
);

/// 問い合わせを記録する実在名の供給元。[pending] に folder を入れると、
/// その folder の問い合わせは [complete] を呼ぶまで返らない。
class _Lister {
  _Lister(this.names);

  /// folder → 実在名。無い folder は取得失敗を返す。
  Map<String, Set<String>> names;
  final List<String> calls = [];
  final Set<String> pending = {};
  final Map<String, Completer<NameListResult>> _waiting = {};

  Future<NameListResult> call(String folder) {
    calls.add(folder);
    if (pending.contains(folder)) {
      return (_waiting[folder] = Completer<NameListResult>()).future;
    }
    return Future.value(_result(folder));
  }

  NameListResult _result(String folder) {
    final listed = names[folder];
    return listed == null
        ? const NameListFailed(PickError(PickErrorKind.io, '読めない'))
        : NamesListed(listed);
  }

  void complete(String folder) {
    pending.remove(folder);
    _waiting.remove(folder)!.complete(_result(folder));
  }
}

List<DuplicateWarning> _duplicates(FileListController c) =>
    c.warnings.whereType<DuplicateWarning>().toList();

void main() {
  test('読み込んだ時点で問い合わせ、実行を要求する前から占有名との重複が警告になる(例25)', () async {
    final c = FileListController(
      files: [_f('alpha.txt')],
      rule: const RenameRule([LiteralToken('keep')]),
    );
    final lister = _Lister({
      'F': {'alpha.txt', 'keep.txt'},
    });
    expect(_duplicates(c), isEmpty, reason: '問い合わせる前は占有名を持たない');

    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();

    expect(lister.calls, ['F']);
    expect(c.folderNames, {
      'F': {'alpha.txt', 'keep.txt'},
    });
    expect(_duplicates(c).single.resultName, 'keep.txt');
  });

  test('選択・ルール・並び順・一覧からの除去では問い合わせない', () async {
    final a = _f('a.txt');
    final c = FileListController(
      files: [a, _f('b.txt')],
      rule: const RenameRule([LiteralToken('x')]),
    );
    final lister = _Lister({
      'F': {'a.txt', 'b.txt'},
    });
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();
    expect(lister.calls, hasLength(1));

    c.toggleSelection(a);
    c.setRule(const RenameRule([LiteralToken('y')]));
    c.setSortMode(FileSortMode.name, direction: SortDirection.descending);
    c.removeFile('F/b.txt');
    await pumpEventQueue();

    expect(lister.calls, hasLength(1));
  });

  test('取ったあとに選択を変えても、空く名前を占有名として扱わない(偽の重複が出ない)', () async {
    // img1 → img2.jpg、img2 → img3.jpg。img2 が選ばれていなければ img2.jpg は空かない
    // (本当の重複)。img2 を選ぶと img2.jpg は空くので重複ではない。
    // **以前は引いた後の占有名を持っていたので、取ったときに img2 が未選択だと
    // img2.jpg が占有名に残り、選んだ後も偽の重複が出続けた。**
    final img2 = _f('img2.jpg');
    final c = FileListController(
      files: [_f('img1.jpg'), img2],
      rule: const RenameRule([
        LiteralToken('img'),
        SequenceToken(start: 2, digits: 1),
      ]),
    );
    c.toggleSelection(img2);
    final lister = _Lister({
      'F': {'img1.jpg', 'img2.jpg'},
    });
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();
    expect(_duplicates(c).single.resultName, 'img2.jpg');

    c.toggleSelection(img2);

    expect(_duplicates(c), isEmpty);
  });

  test('改名(実行・元に戻す)で読み込んだファイルの名前が変わると問い合わせ直す', () async {
    final a = _f('a.txt');
    final c = FileListController(files: [a]);
    final lister = _Lister({
      'F': {'a.txt'},
    });
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();

    lister.names = {
      'F': {'b.txt'},
    };
    c.replaceItems({a: _f('b.txt')});
    await pumpEventQueue();

    expect(lister.calls, ['F', 'F']);
    expect(c.folderNames, {
      'F': {'b.txt'},
    });
  });

  test('同じファイルを読み込み直しても問い合わせ直す(読み込みは実在名を捨てる)', () async {
    final c = FileListController(files: [_f('a.txt')]);
    final lister = _Lister({
      'F': {'a.txt', 'keep.txt'},
    });
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();

    c.setFiles([_f('a.txt')]);
    expect(c.folderNames, isEmpty);
    await pumpEventQueue();

    expect(lister.calls, ['F', 'F']);
    expect(c.folderNames, {
      'F': {'a.txt', 'keep.txt'},
    });
  });

  test('取れなかった folder は、名前が変わるまで問い合わせ直さない(繰り返さない)', () async {
    final a = _f('a.txt');
    final c = FileListController(
      files: [a],
      rule: const RenameRule([LiteralToken('x')]),
    );
    final lister = _Lister({});
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();
    expect(lister.calls, ['F']);
    expect(c.folderNames, isEmpty, reason: '取れなかった結果を実在名として採らない');

    c.toggleSelection(a);
    c.setFiles([_f('a.txt')]);
    await pumpEventQueue();
    expect(lister.calls, ['F']);

    // 名前が変われば(改名)もう一度試す。
    c.replaceItems({c.items.single: _f('b.txt')});
    await pumpEventQueue();
    expect(lister.calls, ['F', 'F']);
  });

  test('供給元が例外を投げても取れなかった扱いにする', () async {
    final c = FileListController(files: [_f('a.txt')]);
    var calls = 0;
    final sync = FolderNamesSync(
      files: c,
      listNames: (folder) async {
        calls++;
        throw StateError('壊れた供給元');
      },
    );
    addTearDown(sync.dispose);
    await pumpEventQueue();

    expect(calls, 1);
    expect(c.folderNames, isEmpty);
  });

  test('問い合わせ中に一覧から folder が無くなったら、その結果は入れない', () async {
    final c = FileListController(files: [_f('a.txt')]);
    final lister = _Lister({
      'F': {'a.txt', 'keep.txt'},
      'G': {'g.txt'},
    })..pending.add('F');
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();

    c.setFiles([_f('g.txt', folder: 'G')]);
    await pumpEventQueue();
    lister.complete('F');
    await pumpEventQueue();

    expect(c.folderNames.keys, ['G']);
  });

  test('問い合わせ中に改名が起きたら、終わってからもう一度問い合わせる', () async {
    final a = _f('a.txt');
    final c = FileListController(files: [a]);
    final lister = _Lister({
      'F': {'a.txt'},
    })..pending.add('F');
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    addTearDown(sync.dispose);
    await pumpEventQueue();

    c.replaceItems({a: _f('b.txt')});
    await pumpEventQueue();
    expect(lister.calls, ['F'], reason: '同じ folder を同時に二重に問い合わせない');

    lister.names = {
      'F': {'b.txt'},
    };
    lister.complete('F');
    await pumpEventQueue();

    expect(lister.calls, ['F', 'F']);
    expect(c.folderNames, {
      'F': {'b.txt'},
    });
  });

  test('dispose 後は問い合わせも書き込みもしない', () async {
    final c = FileListController(files: [_f('a.txt')]);
    final lister = _Lister({
      'F': {'a.txt', 'keep.txt'},
    })..pending.add('F');
    final sync = FolderNamesSync(files: c, listNames: lister.call);
    await pumpEventQueue();
    sync.dispose();
    lister.complete('F');
    await pumpEventQueue();
    c.setFiles([_f('b.txt')]);
    await pumpEventQueue();

    expect(c.folderNames, isEmpty);
    expect(lister.calls, ['F']);
  });

  group('displayOccupiedNames(OP-005 と同じ引き方)', () {
    test('改名で空く名前は引き、REQ-022 で除外されるファイルの名前は引かない(例25c)', () {
      // a.jpg は空名(除外)で改名されない → `a.jpg` は空かない。
      // b.jpg は `a.jpg` へ改名される → 占有名 `a.jpg` とぶつかる。
      final a = _f('a.jpg');
      final b = _f('b.jpg');
      final preview = [
        PreviewEntry(source: a, resultName: '.jpg'),
        PreviewEntry(source: b, resultName: 'a.jpg'),
      ];
      final occupied = displayOccupiedNames({
        'F': {'a.jpg', 'b.jpg', 'c.jpg'},
      }, preview);
      expect(occupied, {
        'F': {'a.jpg'},
      });
    });

    test('別の folder の実在名とはぶつからない(例25d)', () {
      final a = _f('a.jpg', folder: 'A');
      final occupied = displayOccupiedNames(
        {
          'B': {'keep.jpg'},
        },
        [PreviewEntry(source: a, resultName: 'keep.jpg')],
      );
      expect(occupied, isEmpty);
    });

    test('生成後名と一致しない実在名は返さない(数千件でも評価を軽く保つ)', () {
      final a = _f('a.jpg');
      final occupied = displayOccupiedNames(
        {
          'F': {for (var i = 0; i < 5000; i++) 'IMG_$i.jpg', 'a.jpg'},
        },
        [PreviewEntry(source: a, resultName: 'IMG_7.jpg')],
      );
      expect(occupied, {
        'F': {'IMG_7.jpg'},
      });
    });
  });
}
