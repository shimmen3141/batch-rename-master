import 'package:flutter/foundation.dart';

/// 除去のための一時的な選択モードの状態(002 REQ-018)。
///
/// **`FileListController` とは別物である。** controller の選択
/// (`toggleSelection` / `selectedCount`)は **rename 対象の選択**で、製品 UI では常に
/// 全件である(REQ-004 / REQ-016)。ここで選ぶのは**これから外す候補**で、モードを
/// 抜ければ消える。同じ状態へ混ぜると「外す候補にしただけで rename から外れる」
/// 振る舞いになりうる。
///
/// **widget の `State` ではなく独立した notifier に置いてある**(`008:T29`)。
/// モード中は一覧の外側(読み込み帯の `別フォルダへ`、下部のルール設定と実行)も
/// 隠れるので、**一覧の外の widget も同じ状態を読む**必要がある。
///
/// **覚えるのはハンドル**である。項目は改名や読み込み直しで別の値へ入れ替わるが
/// (005 REQ-018 / 004 REQ-004)、ハンドルは同じファイルを指す識別子である。
class RemovalSelection extends ChangeNotifier {
  bool _selecting = false;
  final Set<String> _marked = <String>{};

  /// 除去のための選択モードに入っているか。
  bool get selecting => _selecting;

  /// 外す候補のハンドル。**一覧から消えたものが残りうる**ので、数えるときは
  /// いま一覧にあるハンドルと交差させる([markedAmong])。
  Set<String> get marked => Set<String>.unmodifiable(_marked);

  /// [available] のうち外す候補になっているもの。
  Set<String> markedAmong(Set<String> available) =>
      _marked.intersection(available);

  /// モードへ入る。[handle] を渡すと**その行が選ばれた状態**で始まる(代表例 6f)。
  void enter({String? handle}) {
    _selecting = true;
    _marked
      ..clear()
      ..addAll({?handle});
    notifyListeners();
  }

  /// モードをやめる。**選択は破棄する**(代表例 6i)。一覧には触れない。
  void exit() {
    if (!_selecting && _marked.isEmpty) return;
    _selecting = false;
    _marked.clear();
    notifyListeners();
  }

  /// [handles] を全て選んだ状態でモードへ入る(ケバブの「すべて選択」)。
  void selectAll(Iterable<String> handles) {
    _selecting = true;
    _marked
      ..clear()
      ..addAll(handles);
    notifyListeners();
  }

  /// 一覧から消えたハンドルを候補から落とす(`008:T29`)。
  ///
  /// **見えている0件と内部の0件を揃えるために要る。** 改名の取り消し(005 REQ-018 で
  /// 項目のハンドルが入れ替わる)や読み込み直しで候補が一覧から消えると、
  /// 画面は「0件選択中」なのに [marked] には残ったままになり、
  /// [toggle] の「0件で抜ける」が効かない(独立review attempt 1 の P3)。
  ///
  /// **落とした結果0件になったらモードも抜ける。** 選ぶものが残っていないためである。
  void retain(Set<String> available) {
    final before = _marked.length;
    _marked.retainWhere(available.contains);
    if (_marked.length == before) return;
    if (_marked.isEmpty) _selecting = false;
    notifyListeners();
  }

  /// [handle] を外す候補へ加える。既存の候補は保つ。
  ///
  /// 1回のドラッグで新しく通った行だけを戻り操作で外せるよう、
  /// [enter] のように既存の候補を初期化しない。
  void mark(String handle) {
    if (_marked.add(handle)) notifyListeners();
  }

  /// [handle] を外す候補から外す。
  ///
  /// tap と同じく、候補が 0 件ならモードを閉じる。ドラッグ側は開始時に
  /// 持っていた候補を呼ばないことで、それらを保護する。
  void unmark(String handle) {
    if (!_marked.remove(handle)) return;
    if (_marked.isEmpty) _selecting = false;
    notifyListeners();
  }

  /// 1件を選ぶ / 選ぶのをやめる。
  ///
  /// **選択が0件へ戻ったらモードを抜ける**(2026-09-19 の決定)。ただし
  /// **入った直後の0件では抜けない** — ヘッダの入口(REQ-018 (b))は0件で始まるので、
  /// そこで抜けると入口が機能しなくなる。ここを通るのは**利用者が選択を外したとき**だけである。
  void toggle(String handle) {
    if (_marked.remove(handle)) {
      if (_marked.isEmpty) _selecting = false;
    } else {
      _marked.add(handle);
    }
    notifyListeners();
  }
}
