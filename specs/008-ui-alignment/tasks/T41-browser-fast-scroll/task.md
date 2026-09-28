# T41 browserの一覧が素早いscrollに反応しない原因を調べる

## 目的

app内browserで件数の多いfolder(200件)を**素早くscrollすると引っかかる・反応しない**。ややゆっくりなら動く。原因を特定し、直すかどうか・どう直すかを開発者へ選択肢として返す。

## 観測(2026-09-27、Androidエミュレータ、release build)

- `008:T13`のmanual 2回目(`lib/`・`hook/`・`src/`が`025aa18`): 「ややゆっくりスクロールしないと引っかかる」。
- **比較: previewの無い`dev`@`795ae65`のrelease build**でも「素早いスクロールだと反応しなさそう」。**`T13`(preview)が原因ではない。**
- `008:T07`(一覧のpreview)の確認でも、scrollの引っかかりを開発者が「previewより前からのもの」と判断していた(N-5)。
- 操作はエミュレータ上の**マウス**である(`T39`で、マウスのdragはFlutterの既定ではscrollしないことが分かっている。一覧の縦scrollはマウスのdragやホイールで行っている)。

## 調べる候補(未検証)

- `T37`の長押しdrag選択: 一覧を包む`Listener`と、行の`GestureDetector(onLongPressStart)`が、scrollのdrag・flingと取り合っていないか。
- エミュレータのマウス入力に固有か(実際のtouchのflingでは起きないか)。widget testで`fling`を`PointerDeviceKind.touch` / `mouse`の両方で再現できるか。
- リネーム画面の一覧(`file_list_view.dart`)でも起きるか。
- 行の数(`ListView(children:)`で全行のwidgetを毎回作る)が効いているか。

## 依存

- `008:T13`(同じ画面の行を変える。**後に着手する**)。

## 受け入れ証拠

- 原因の特定(widget testでの再現、または再現しないことの確認と、エミュレータ固有と判断した根拠)。
- 直す場合は、再現testが修正前に落ちて修正後にPASSすること、`T37`の範囲選択とscrollのtestを弱めないこと。
- エミュレータのrelease buildでの確認。
- 独立review PASS。

## 調査の記録(2026-09-28)

**widget testでの再現**(200件のbrowser、400x800、`dev`@`16aa7f4`。調査用の一時testで、残していない):

| 操作 | 結果 |
|---|---|
| touchで素早くfling(velocity 3000) | **scrollする**(約1,585px)。続けてゆっくりdragしても動く |
| mouseでdrag(flingも、ゆっくりも) | **まったく動かない**(0px)。Flutterの既定の`ScrollBehavior.dragDevices`はmouseを含まない(`T39`のパンくずで見つけたものと同じ) |
| mouseのwheel(20回) | scrollする(2,400px) |

- **appはtouchの素早いflingに正しく反応する。** `T37`の`Listener`はpointerの位置を記録するだけで、scrollのdragを取り合っていない(`drag_selection_controller.dart`)。
- したがってエミュレータの観測は**入力の種類に依る**と見ている。エミュレータがマウスをmouseとして渡すならdragではscrollせず、wheelでだけ動く。**開発者がどう操作したか(wheel / click-drag)を確かめる。**

**開発者の操作(2026-09-28に確認)**: **トラックパッド**(2本指scroll)。エミュレータではこれがtouchのflingではなく**scroll量のイベント**(wheelと同じ種類)として届くので、widget testで正常だった**touchの素早いfling**とは別の経路である。

**切り分けの手順(開発者へ依頼)**: エミュレータへ`adb shell input swipe`で**touch相当の素早いswipe**を送る(トラックパッドを通さない)。これで素早くscrollするならappは正常で、観測はエミュレータのトラックパッド入力に固有と結論する。

## 結論(2026-09-28)

**このエミュレータでは、トラックパッドの操作でだけ起き、touch相当の入力では起きなかった。appのscrollの欠陥とは判断しない。**

- 開発者がエミュレータで`many`(200件)を開き、`adb shell input swipe`で**ADBから注入したtouch相当の素早いswipe**(画面高の80%→30%、100ms)を送ったところ、**「勢いよく流れた」**。
- widget testでもtouchの素早いflingは正常(上の調査の記録)。
- 観測(素早いと反応しない)は、**今回のエミュレータでのトラックパッドの2本指scroll**でだけ起きた。**実機の指での操作やほかの入力でも起きないことまでは、この証拠では確かめていない**(残余risk。実機での確認は`008:T39`の決定で受け入れ証拠から外している)。
- **コードは変えない。** 同じ誤解を避けるため、共通の手順書`docs/development/emulator-verification.md`の「注意」へ、scrollの速さはreleaseと`adb shell input swipe`で見ること、エミュレータのマウスdrag・トラックパッドの扱いを足した。
- `008:T13`から引き受けた残余risk(素早いscrollの引っかかり)と、`008:T07`のN-5(previewより前からのscrollの引っかかり)は、この結論で説明される。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。調査はClaude Opus 5.5)。

- attempt 1: `16aa7f4..24214fc`(全範囲) — **PASS**(P2が1件)。証拠から入力経路の違いという切り分けが導けること、`Listener`と長押しの認識がscrollを取り合っていないこと、一覧にはmouseのdragが効かずパンくずだけ全種へ広げていること、コードを変えない判断、記録の一致を確認された。
  - **P2(成果物の欠陥)**: ADBの`input swipe`を「本物のtouch」と書き、「利用者は実機を指で操作するので製品の経路には現れない」と観測を越えて断定していた(task.mdと手順書)。→ 「ADBから注入したtouch相当」「今回のエミュレータのトラックパッドでだけ起きた。実機の指やほかの入力で起きないことは確かめていない」へ限定した。
  - **SELF-CHECK**(AGENTS.mdの差分review): P2を閉じる差分は`specs/`と`docs/`だけで、code・依存・build設定に差分が無い。再reviewは起動しない。

## Current state / handoff

- Last checkpoint: 結論を出した(2026-09-28)。このエミュレータではトラックパッドでだけ起き、touch相当の入力では起きない。コード変更なし。
- Blocker category: なし。
- Evidence revision: 観測は`008:T13`の`025aa18`と`dev`@`795ae65`のrelease build。
- Waiting for: 独立review。
- Requested action: なし。
- Next Agent action: 独立review → PR → merge → done。
