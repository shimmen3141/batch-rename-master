import 'package:flutter/foundation.dart';

import '../file_list/file_list_controller.dart';

/// 一覧の読み込み元の種類(004 REQ-024。`010:T09`)。
enum ListOrigin {
  /// Android の app 内 file browser(「すべて」と、REQ-021 の開き直し)。
  browser,

  /// Android の写真・動画の選択画面(REQ-022)。
  mediaPicker,

  /// desktop の OS のファイル選択画面。
  systemPicker,
}

/// 一覧の読み込み元(004 REQ-024)。**覚えるのは種類だけ**で、選択の初期値は
/// 一覧から導く。
///
/// 読み込み帯が一覧を置き換えるたびに [record] する。**一覧が空の間は読み込み元が
/// 無い**([current] が `null`)。空になった一覧を除去の取り消し(002 REQ-017)で
/// 戻したときは、最後に一覧を置き換えた読み込みが読み込み元のままである — 取り消しは
/// 読み込みではなく、戻った一覧はその読み込みのファイルだからである。
class ListOriginState extends ChangeNotifier {
  ListOriginState(this._files) {
    _files.addListener(notifyListeners);
  }

  final FileListController _files;
  ListOrigin? _last;

  /// 今の一覧の読み込み元。一覧が空、または一度も読み込んでいない(デモの初期値)
  /// なら `null`。
  ListOrigin? get current => _files.items.isEmpty ? null : _last;

  /// 一覧を置き換える読み込みの**直前**に呼ぶ。置き換えた結果が空なら [current] は
  /// `null` のままである。
  void record(ListOrigin origin) {
    if (_last == origin) return;
    _last = origin;
    notifyListeners();
  }

  @override
  void dispose() {
    _files.removeListener(notifyListeners);
    super.dispose();
  }
}

/// 読み込み元が写真・動画の選択画面のときに、帯と一覧の先頭の行が示す名前(REQ-024)。
const String mediaPickerOriginLabel = '写真・動画';
