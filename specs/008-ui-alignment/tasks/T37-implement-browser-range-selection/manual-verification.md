# T37 Android物理端末確認: app内file browserの範囲選択

> **注記(2026-09-22追加。結果は書き換えていない)**: この手順書は**当時のbuildに対する記録**である。
> `008:T11`がapp内browserの入口を変え(**保存場所が1つだけなら一覧を挟まない**)、**既知の場所への近道を取りやめた**ため、
> **入口と近道に関する期待値はこの手順書では現行でない**。現行の正本は[004 spec](../../../004-file-source/spec.md)のREQ-015である。
> **再実行するときは、その2点だけを現行仕様へ読み替える。**

## 対象

- plan / task: `008 / T37 app内file browserへ範囲選択を実装する`
- 対象platform: Android物理端末。emulatorだけを受け入れ証拠にしない。
- 対象workspace: Agentが案内する`.worktrees/008-T37-implement-browser-range-selection`。人間によるbranch移動は不要。
- 共通起動手順: [`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)
- 対象commit/build: Agentが確認依頼時に固定して示す。同じcommitから`flutter run -d <device-id>`で起動する。

## fixture

同じfolderに次を用意する。

- fileを30件以上。画面外まで十分にscrollできる件数にする。
- subfolderを1件以上。
- app内browserのrootで既知の場所への近道（例: Download）が表示される状態にする。

file名は順序を追いやすい連番（例: `range-01.txt`〜`range-30.txt`）が望ましい。

## 確認項目

1. Androidの「すべてのファイル」からapp内browserを開き、fixtureのfolderへ移動する。
2. 選択0件の状態で通常どおり縦へscrollする。
   - fileは選択されず、件数は0件のままである。
3. 「すべて選択」をtapする。
   - 現在folderのfileだけがすべて選択される。
   - subfolderと近道は選択対象に入らない。
   - すでに全fileが選択済みなら操作は無効になる。
4. いったん一つ上のフォルダへ戻り、fixtureのフォルダを開き直して選択を0件へ戻す。端末の設定でTalkBackをオンにし、画面を右へ1本指でなぞって「すべて選択」と読み上げられるボタンを探す。そのボタンに枠が付いたら画面を2回素早くタップする。
   - 読み上げで「すべて選択」がボタンとして分かる。2回タップ後、現在のフォルダにあるfileの件数が選択中の件数として表示される。
5. TalkBackをオフにする。一つ上のフォルダへ戻ってfixtureのフォルダを開き直し、選択を0件へ戻す。file Aを1回タップして選び、別のfile Bを長押しし、B→C→A→Bの順に指を往復させて離す。
   - 長押し開始時にBが選択される。
   - 往路でCが選択され、復路では今回のdragで追加したCだけが解除される。
   - drag開始前から選択済みだったAは解除されない。
6. 連番fileの中央付近を長押しし、指を画面上端からheader付近まで動かして保持する。
   - 指が一覧内を出てheader付近へ達しても上方向のscrollが続く。
   - 端から深く動かすほどscrollが速くなり、開始fileが画面外になっても選択が続く。
7. 指を離さず画面中央へ戻す。
   - auto-scrollが止まり、同じ方向へ勝手にscrollし続けない。
8. 続けて反対側の画面下端へ動かして保持する。
   - scroll方向が下向きへ反転する。
   - 往路で追加したfileを戻ると、そのdragで追加したfileだけが選択解除される。
   - 先頭または末尾まで達した後でも反転と解除ができる。
9. 指を離す。
   - auto-scrollがただちに止まり、その後に選択が変わらない。
10. もう一度長押しdrag中にHomeへ移動するなど、Androidにpointer cancelさせてからappへ戻る。
    - auto-scrollが止まり、その後に選択が変わらない。
11. fileを複数選択したままsubfolderへ移動する。
    - 選択件数が0件へ戻る。

## 結果の返し方

各項目について「問題なし」、または項目番号と実際の挙動を知らせる。Agentは結果を対象commitとともに`task.md`へ記録し、独立review後のcode/dependency/build差分が無いことを確認してから完了判定する。
