/// フォルダ内の1ファイルを表す入力値(FEAT-001 / REQ-001 の用語)。
///
/// エンジンはファイルシステムへアクセスせず、この値として受け取る(INV-004)。
/// ベース名・拡張子は [name] から導出する(REQ-001)。
class FileEntry {
  /// 拡張子込みのフルネーム(例: `photo.jpg`)。
  final String name;

  /// 作成日時。**取得できない場合は `null`(=不明)**。
  ///
  /// SAF には作成日時の列が無く、EXIF・コンテナメタデータ・MediaStore・NTFS 等の
  /// 経路で取得できたときだけ値が入る(004 REQ-003/010)。不明を更新日時などの
  /// 別の値で代替してはならない(INV-006)。日時トークンの基準が作成日時で、この値が
  /// `null` のとき、そのトークンは空文字列を出力する(REQ-004)。
  final DateTime? createdAt;

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

  /// 所属 folder を一意に識別する不透明な値(004 REQ-013)。
  ///
  /// **同じ場所にあるファイルは必ず等しい値**になり、別表記(別名 path・
  /// シンボリックリンク経由など)で割れない。**正規化の責務は 004 が持ち**、
  /// 001 と 005 は**等値だけ**で同一性を判定する — 文字列を path として解釈しない
  /// (005 contract の用語 `folder` / OQ-004)。
  ///
  /// [sourceHandle] とは別物である。ハンドルは1ファイルを指し、この値は場所を指す。
  /// [sourceLocation] とも別物である(あちらは人間可読の表示用で、同名の別 folder を
  /// 区別できない)。
  ///
  /// `null` は**「不明」という単一の folder**を表す(個別の folder に分けない)。
  /// 分けると、読み込み元を持たない入力で重複判定が一切働かなくなる。
  ///
  /// 生成後名の構成には用いない。用いるのは [validate] と [autoResolve] だけで、
  /// 最終名集合の範囲を区切り占有名を引き当てるためである(INV-005)。
  final String? sourceFolder;

  const FileEntry({
    required this.name,
    this.createdAt,
    required this.modifiedAt,
    required this.size,
    this.selected = true,
    this.sourceHandle,
    this.sourceLocation,
    this.sourceFolder,
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
