import 'package:flutter/foundation.dart';

import '../../core/rename_engine.dart';

/// トークンビルダーの状態層(003 spec: `RuleController`)。
///
/// 編集中の [Token] 列(001)を保持し、追加・削除・並び替え・差し替えの各操作で
/// 001 の [RenameRule] を組み上げ、変更を通知する。組み上げた [rule] を 002 の
/// `FileListController.setRule` に渡すとプレビューへ反映される。
///
/// ウィジェット(`Widget` の構築)には依存せず単体でテスト可能(003 計画)。
/// [Token] は 001 の不変値なので、詳細編集は「新しい [Token] への差し替え」
/// ([replaceAt])で表現する。値の妥当性(自由テキストの空不可など)は詳細エディタ
/// (T4)の責務で、本コントローラは汎用に振る舞う(spec の対象外・未定義)。
class RuleController extends ChangeNotifier {
  /// [tokens] を初期のトークン列として保持する(既定は空。REQ-001)。
  RuleController({List<Token> tokens = const []})
    : _tokens = List<Token>.of(tokens);

  final List<Token> _tokens;

  /// 現在の編集順のトークン列(読み取り専用ビュー)。
  List<Token> get tokens => List<Token>.unmodifiable(_tokens);

  /// 現在のトークン列から組み上げた [RenameRule](REQ-006)。
  ///
  /// スナップショットを返すため、以降の編集は取得済みの [RenameRule] に影響しない。
  RenameRule get rule => RenameRule(List<Token>.of(_tokens));

  /// [token] を末尾に追加する(REQ-002)。
  void addToken(Token token) {
    _tokens.add(token);
    notifyListeners();
  }

  /// [index] の要素を取り除く(REQ-003。他要素の相対順は保つ)。
  void removeAt(int index) {
    _tokens.removeAt(index);
    notifyListeners();
  }

  /// [oldIndex] の要素を取り出し [newIndex] の位置へ挿入する(REQ-004)。
  ///
  /// インデックスは 002 と同じ `ReorderableListView.onReorderItem` 規約
  /// ([newIndex] は削除後の挿入先)。
  void reorder(int oldIndex, int newIndex) {
    final moved = _tokens.removeAt(oldIndex);
    _tokens.insert(newIndex, moved);
    notifyListeners();
  }

  /// [index] の要素を [token] に差し替える(REQ-005。位置と他要素は保つ)。
  void replaceAt(int index, Token token) {
    _tokens[index] = token;
    notifyListeners();
  }
}
