# T37 Android物理端末確認: app内file browserの範囲選択

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
4. TalkBackを有効にし、全選択controlへfocusを移してactivateする。
   - 「すべて選択」という操作名とbuttonであることを認識できる。
   - activateすると現在folderのfileが選択される。
5. 選択をいったん解除し、file Aをtapで選択する。別のfile Bを長押しし、B→C→A→Bの順に指を往復させて離す。
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
