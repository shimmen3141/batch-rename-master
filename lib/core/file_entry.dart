/// フォルダ内の1ファイルを表す入力値(FEAT-001 / REQ-001 の用語)。
///
/// エンジンはファイルシステムへアクセスせず、この値として受け取る(INV-004)。
/// ベース名・拡張子は [name] から導出する(REQ-001)。
class FileEntry {
  /// 拡張子込みのフルネーム(例: `photo.jpg`)。
  final String name;

  /// 作成日時(日時トークンの基準の一つ。T3 で使用)。
  final DateTime createdAt;

  /// 更新日時(日時トークンの基準の一つ。T3 で使用)。
  final DateTime modifiedAt;

  /// バイトサイズ(サイズ順ソートで使用。UI 層 002 で参照)。
  final int size;

  /// リネーム対象として選択されているか(REQ-006 のプレビュー対象判定に使用)。
  final bool selected;

  const FileEntry({
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.size,
    this.selected = true,
  });

  /// 拡張子境界となるドットの位置。
  ///
  /// [name] 内で最後に出現するドット。ただし先頭文字のドットは境界としない
  /// (REQ-001)。境界が無い場合は `-1`。
  int get _dotIndex {
    final i = name.lastIndexOf('.');
    return i <= 0 ? -1 : i;
  }

  /// ベース名 = 拡張子境界より前の部分。境界が無ければ [name] 全体(REQ-001)。
  ///
  /// 例: `photo.jpg` -> `photo`、`.gitignore` -> `.gitignore`、
  /// `archive.tar.gz` -> `archive.tar`、`noext` -> `noext`。
  String get baseName {
    final i = _dotIndex;
    return i < 0 ? name : name.substring(0, i);
  }

  /// 拡張子 = 拡張子境界のドットより後ろ(ドットを含まない)。境界が無ければ空(REQ-001)。
  String get extension {
    final i = _dotIndex;
    return i < 0 ? '' : name.substring(i + 1);
  }
}
