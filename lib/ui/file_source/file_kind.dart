/// 読み込みの最初に選ぶ「リネームしたいファイルの種類」(004 REQ-011)。
///
/// 種類ごとに適した選択 UI へ分岐する。2026-10-05 `010:T05` で「画像」「動画」を
/// 「写真・動画」の1つにまとめた。
enum FileKind {
  /// 写真・動画。Android は写真・動画の選択画面(004 REQ-022)を、desktop は
  /// システムのファイル選択画面を写真・動画のファイルに絞り込んで開く(REQ-011。
  /// `010:T10`)。
  media,

  /// 文書。システムのファイル選択画面を文書系の MIME で絞り込んで開く。
  document,

  /// すべて。システムのファイル選択画面をフィルタ無しで開く
  /// (フォルダを辿ってファイルを選ぶ)。
  all,
}

/// このplatformで出す種類(004 REQ-011)。
///
/// **desktop は3つ、Android は2つ**である。**Android に「文書」は出さない** —
/// app 内 browser には MIME filter の手段が無く、拡張子で絞る判定を新設しない
/// (REQ-017)。
///
/// **純関数として切り出してある。** `Platform.isAndroid` を条件式へ直接書くと、
/// この写像を Linux 上の test で固定できない(ADR-003 と同じ理由)。
List<FileKind> fileKindsFor({required bool isAndroid}) => [
  FileKind.media,
  if (!isAndroid) FileKind.document,
  FileKind.all,
];

extension FileKindLabel on FileKind {
  /// 種類の表示名。
  String get label => switch (this) {
    FileKind.media => '写真・動画',
    FileKind.document => '文書',
    FileKind.all => 'すべて',
  };

  /// 補足説明(選択 UI が何を開くか)。
  ///
  /// 「写真・動画」は、写真・動画の選択画面を持つ([mediaPicker]。Android)なら
  /// 撮影日順の選択画面、持たない(desktop)ならシステムのファイル選択画面である。
  String descriptionFor({required bool mediaPicker}) => switch (this) {
    FileKind.media => mediaPicker ? '撮影日の新しい順に写真・動画から選ぶ' : '写真・動画のファイルから選ぶ',
    FileKind.document => '文書ファイルから選ぶ',
    FileKind.all => 'フォルダを辿ってファイルを選ぶ',
  };

  /// システムのファイル選択画面に渡す MIME フィルタ(空なら絞り込まない)。
  ///
  /// Android の「写真・動画」は選択画面(REQ-022)を開くので使わない。desktop の
  /// 選択画面が MIME 型で絞れない OS(Windows)では、`DesktopFileSource` が
  /// 拡張子へ直して渡す。
  List<String> get mimeTypes => switch (this) {
    FileKind.media => const ['image/*', 'video/*'],
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
