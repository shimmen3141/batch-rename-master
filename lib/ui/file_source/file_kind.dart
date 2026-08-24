/// 読み込みの最初に選ぶ「リネームしたいファイルの種類」(004 REQ-011)。
///
/// 種類ごとに適した選択 UI へ分岐する。`image` / `video` は**枠のみ**で、
/// 中身(MediaStore のギャラリー)は写真機能で実装する — 権限モデルが SAF と
/// 別で、返る URI が読み取り専用のため(004 spec 境界)。
enum FileKind {
  /// 画像。ギャラリー(すべて/アルバム)を開く想定。**未実装**。
  image,

  /// 動画。同上。**未実装**。
  video,

  /// 文書。システムのファイル選択画面を文書系の MIME で絞り込んで開く。
  document,

  /// すべて。システムのファイル選択画面をフィルタ無しで開く
  /// (フォルダを辿ってファイルを選ぶ)。
  all,
}

/// このplatformで出す種類(004 REQ-011)。
///
/// **desktop は4つ、Android は3つ**である。**Android に「文書」は出さない** —
/// app 内 browser には MIME filter の手段が無く、拡張子で絞る判定を新設しない
/// (REQ-017)。
///
/// **純関数として切り出してある。** `Platform.isAndroid` を条件式へ直接書くと、
/// この写像を Linux 上の test で固定できない(ADR-003 と同じ理由)。
List<FileKind> fileKindsFor({required bool isAndroid}) => [
  FileKind.image,
  FileKind.video,
  if (!isAndroid) FileKind.document,
  FileKind.all,
];

extension FileKindLabel on FileKind {
  /// 種類の表示名。
  String get label => switch (this) {
    FileKind.image => '画像',
    FileKind.video => '動画',
    FileKind.document => '文書',
    FileKind.all => 'すべて',
  };

  /// 補足説明(選択 UI が何を開くか)。
  String get description => switch (this) {
    FileKind.image => 'アルバムから写真を選ぶ',
    FileKind.video => 'アルバムから動画を選ぶ',
    FileKind.document => '文書ファイルから選ぶ',
    FileKind.all => 'フォルダを辿ってファイルを選ぶ',
  };

  /// この種類の読み込みが実装済みか(REQ-011)。
  ///
  /// `image` / `video` は枠のみで、選んでも読み込みは行わない。
  bool get isImplemented => switch (this) {
    FileKind.image || FileKind.video => false,
    FileKind.document || FileKind.all => true,
  };

  /// 選択 UI に渡す MIME フィルタ(空なら絞り込まない)。
  List<String> get mimeTypes => switch (this) {
    FileKind.document => const [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/plain',
    ],
    _ => const [],
  };
}
