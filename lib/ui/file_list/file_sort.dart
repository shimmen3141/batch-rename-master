import '../../core/rename_engine.dart';

/// ファイルリストのソート種別(002 spec: sortMode)。
///
/// [name] / [createdAt] / [modifiedAt] / [size] はキーで昇順・安定ソート(REQ-002)。
/// 時系列は**作成日時と更新日時の2種**を提供する。
/// [custom] はユーザーが手動で並べ替えた順で、ソートを適用しない(REQ-003)。
enum FileSortMode { name, createdAt, modifiedAt, size, custom }

/// 作成日時ソートの並べ替えキー(REQ-002)。
///
/// 作成日時が判明していればその値、**不明なら当該ファイルの更新日時で代替**する。
/// 未変更のファイルでは両者が一致することが多く、末尾へ隔離するより有用な順序に
/// なるため。代替は**並べ替えキーの決定にのみ**用い、[FileEntry.createdAt] や
/// 命名結果は書き換えない(001 INV-006)。代替が起きたことは
/// [FileListController.createdAtSortWarning] と行の表示で示す(REQ-011/013)。
DateTime createdAtSortKey(FileEntry file) => file.createdAt ?? file.modifiedAt;

/// [mode] に対応する [FileEntry] の比較関数。[FileSortMode.custom] は比較しない
/// (常に 0 を返す = 現在順を保持)。
///
/// 名前順は自然順・大文字小文字を区別しない(002 決定済み事項)。
int Function(FileEntry, FileEntry) comparatorFor(FileSortMode mode) {
  return switch (mode) {
    FileSortMode.name => (a, b) => compareNatural(a.name, b.name),
    FileSortMode.createdAt => (a, b) => createdAtSortKey(
      a,
    ).compareTo(createdAtSortKey(b)),
    FileSortMode.modifiedAt => (a, b) => a.modifiedAt.compareTo(b.modifiedAt),
    FileSortMode.size => (a, b) => a.size.compareTo(b.size),
    FileSortMode.custom => (_, _) => 0,
  };
}

/// 作成日時ソート時に供給する警告(REQ-011)。
///
/// 「作成日時を取得できなかったファイルが [unknownCount] 件あり、**それらは更新日時
/// で代替して並べている**」ことを表す。判定はファイル種別ではなく取得可否で行う。
/// 0 件のときは供給しない(このインスタンスを作らない)。
class CreatedAtFallbackWarning {
  /// 作成日時が不明で、更新日時で代替して並べたファイルの件数(1 以上)。
  final int unknownCount;

  const CreatedAtFallbackWarning(this.unknownCount);
}

/// [compare] による安定ソートの結果を新しいリストで返す(元リストは変更しない）。
///
/// Dart 標準の [List.sort] は安定性を保証しないため、元の添字をタイブレークに
/// 用いて安定性を保証する(REQ-002: 同値時は元の相対順を保持)。
List<T> stableSorted<T>(List<T> items, int Function(T, T) compare) {
  final indexed = <(int, T)>[
    for (var i = 0; i < items.length; i++) (i, items[i]),
  ];
  indexed.sort((x, y) {
    final c = compare(x.$2, y.$2);
    return c != 0 ? c : x.$1.compareTo(y.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// 自然順比較(大文字小文字を区別しない)。数字の並びは数値として比較するため、
/// `file2` < `file10` となる(002 決定済み事項)。
///
/// 数字以外は小文字化した符号単位で比較し、数字の連なりは先行ゼロを無視した
/// 数値の大小(桁数優先)で比較する。
int compareNatural(String a, String b) {
  final la = a.toLowerCase();
  final lb = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < la.length && j < lb.length) {
    final ca = la.codeUnitAt(i);
    final cb = lb.codeUnitAt(j);
    if (_isDigit(ca) && _isDigit(cb)) {
      final si = i;
      final sj = j;
      while (i < la.length && _isDigit(la.codeUnitAt(i))) {
        i++;
      }
      while (j < lb.length && _isDigit(lb.codeUnitAt(j))) {
        j++;
      }
      final na = _stripLeadingZeros(la.substring(si, i));
      final nb = _stripLeadingZeros(lb.substring(sj, j));
      if (na.length != nb.length) return na.length - nb.length;
      final c = na.compareTo(nb);
      if (c != 0) return c;
      // 数値として等しい(先行ゼロ差など)。続きを比較する。
    } else {
      if (ca != cb) return ca - cb;
      i++;
      j++;
    }
  }
  return (la.length - i) - (lb.length - j);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// 先行ゼロを除いた数字列(全てゼロなら "0")。
String _stripLeadingZeros(String digits) {
  var k = 0;
  while (k < digits.length - 1 && digits.codeUnitAt(k) == 0x30) {
    k++;
  }
  return digits.substring(k);
}
