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

  /// 取得元を一意に識別する不透明なハンドル(SAF URI / ファイルパス相当)。
  ///
  /// 004 が読み込み時に埋め、005 のリネーム書き戻し先を指す。作業セットの
  /// 重複排除もこの値で行う(同名でも別フォルダなら別物。004 REQ-002)。
  /// 命名エンジンはこの値を評価に用いない(INV-005)。
  final String? sourceHandle;

  /// 表示用の場所(元フォルダを表す人間可読の文字列。004 REQ-009)。
  ///
  /// 002 が各行のサブ情報として表示する。識別には用いない([sourceHandle] が担う)。
  /// 命名エンジンはこの値を評価に用いない(INV-005)。
  final String? sourceLocation;

  const FileEntry({
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.size,
    this.selected = true,
    this.sourceHandle,
    this.sourceLocation,
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
