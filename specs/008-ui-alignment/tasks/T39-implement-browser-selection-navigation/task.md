# T39 app内browserの選択・戻る導線を実装する

## 目的

T38で承認されたbrowserの選択・一括解除・戻る導線をAndroid app内browserに実装する。T37の範囲選択とT12の保存場所入口・戻る表示を保ち(**近道は2026-09-22の`T11`で取りやめたので維持対象ではない**)、利用者が「選択を解除する」と「リネーム画面へ戻る」を取り違えない画面にする。

## 依存と境界

- T38: 仕様・状態表・開発者承認。
- T12: 同じbrowser画面の入口(保存場所が1件ならroot・複数なら一覧と切り替え)、**近道の撤去**、戻る矢印、空folderの提示。
- T37: 長押しdragと全選択の基盤。
- Android app内browserだけが対象。desktopのOS pickerとrename判定、権限、ファイル変更は対象外。
- T38が決める前に見た目や選択の意味を確定・実装しない。

## machine検証範囲と引き受け先

- widget test: **`T38`の操作状態表の行をそのまま検査する** — 保存場所の一覧 / root(複数) / root(1件) / 下位folder / 空folderの各行で、header左(`←`の有無と行き先 / 選択中は`×`)・header中央(保存場所名 / 「N件選択中」)・**常に右端にあるケバブ**・パンくず・footer(「リネーム画面に戻る」「確定」の有効条件)が表のとおりであること。あわせて**一括解除**(004 REQ-020。`×`とケバブの両方から実行でき、**選択0件では解除が提示されない**)、**folder移動で選択が解除される**こと、file行のcheckbox配置と選択表示、folderが全選択の対象外であること、T37のdrag回帰。
- semantics widget test: 戻る、一括選択、一括解除の操作名とactionを区別する。
- Android物理端末: 上記の見え方、手での選択・解除、TalkBackの読み上げと操作、狭幅と長い場所名。T39が引き受ける。
- **`T12`から引き受けた残余risk(2026-09-22)**: 保存場所が**1件**の端末で、browserが一覧を挟まずrootから始まること(004 REQ-015)。`T12`はエミュレータにSDカードがあり観測できなかった(widget testとmutation `M109`では固定済み)。**物理端末がSDカードを持たないなら、入口の見え方を1項目足す。** 持つなら観測できないことを記録する。
- desktopはOS picker経路のためmanual対象外。

## 受け入れ証拠

- T38が承認された仕様と状態表に対応するwidget testがPASSし、T12/T37関連testを弱めずPASSする。
- 必要なmutationがKILLED。format/analyze/full test/workspace check PASS。
- Android物理端末のmanual確認PASS。exact rangeの独立review PASS。review modelは開発者指定のluna。
- design土台との差分: T38の状態表で確定した後、適用画面範囲と離れた点・理由をここに追記する。

## T38からの引き渡し(2026-09-23)

**仕様は承認済み** — 004 REQ-020へ一括解除が入った(`specs/004-file-source/spec.md`の「008:T38 由来の更新」節)。
`task.json.covers`へ`004:REQ-020`を記入した。**提示の決定は`T38`の操作状態表が正本で、ここへ複製しない。**

実装で落としてはいけない点だけを挙げる。

- **`×`は画面を閉じない。** 選択中だけ出て、**全解除だけ**を意味する。画面を閉じるのは**footer左下の「リネーム画面に戻る」**で、
  未確定の選択は捨て、rename画面の既存状態は保つ(004 REQ-001/008の`Cancelled`のまま)。
- **選択中は`←`が消える**(同じ位置を`×`と共有する)。**これは`T38`が受け入れた代償**で、不具合ではない。
  選択したまま上へ移動する手段は**`T40`(パンくずのtap移動)**が入ってから成立する。
- **ケバブは常に右端**。「すべて選択」は常設、「**選択をすべて解除**」は**1件でも選択があるときだけ**出す。
- **現在地の帯はパンくずの表示だけ**を作る。**tapによる移動は`T40`**であって、このtaskでは作らない。
- file行のcheckboxは`T29`へ揃える(右端・円・アクセント色)。選択済み行の面色も揃える。

**manual確認の手順は着手前に具体化する** — `T37`のエミュレータ完了の例外を自動適用せず、Android物理端末で
何を見るかを`manual-verification.md`へ書いてから人間へ依頼する。**`T12`から引き受けた残余risk(保存場所が1件の端末の入口)も
同じ手順書へ入れる**(端末がSDカードを持たない場合)。

## Current state / handoff

- Last checkpoint: **未着手だが着手できる。** `T38`が2026-09-23にdone(操作状態表とUIの決定、004 REQ-020への一括解除が承認済み)、`T12`も統合済み。依存はすべて外れた。
- Blocker category: なし。
- Evidence revision: 起点は `dev@7d8a597`(T11・T12・T38が統合済み)。参照する実装は `lib/ui/file_source/storage_browser_view.dart`、`lib/ui/file_list/file_list_view.dart`(T29のcheckboxの形)、`lib/ui/common/drag_selection_controller.dart`(T37)。
- Waiting for: なし。
- Requested action: なし。
- Next Agent action: **次の順で進める。**
  1. 専用のbranch/worktree(`asdd/008-ui-alignment/T39-implement-browser-selection-navigation`)を`dev`から作る。
  2. **`T38`の操作状態表**(`../T38-define-browser-selection-navigation/task.md`の「操作状態表」)を上から実装する。
     **正本はそこで、ここへ複製しない。**
  3. 状態表の各行をwidget testで検査する(上の受け入れ証拠の行)。**一括解除は004 REQ-020が正本。**
  4. `tool/mutations.json`へ、一括解除と`×`が画面を閉じないことを守るmutationを足す。
  5. `flutter test` / `analyze` / `dart format` / `python3 tool/check_normative_terms.py` を通す。
  6. `manual-verification.md`を具体化してから人間へ依頼する。**T37のエミュレータ完了の例外を自動適用しない。**
     **`T12`から引き受けた残余risk(保存場所が1件の端末の入口)も同じ手順書へ入れる**(端末がSDカードを持たない場合)。
  7. 独立review(開発者指定の`gpt-5.6-luna`)→ PR → CI → merge判断。
  **パンくずのtap移動は作らない**(`T40`)。
