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

## Current state / handoff

- Last checkpoint: 着手(2026-09-28)。widget testではtouchの素早いflingは正常、mouseのdragはscrollしない、wheelは正常。
- Blocker category: なし(`008:T13`は2026-09-27にdone)。
- Evidence revision: 観測は`008:T13`の`025aa18`と`dev`@`795ae65`のrelease build。
- Waiting for: 開発者がエミュレータでどう操作してscrollしたか(wheel / click-drag)。
- Requested action: なし。
- Next Agent action: 操作方法に応じて、エミュレータ固有と結論するか、mouseのdragでも一覧をscrollできるようにするかを開発者へ選択肢として返す。
