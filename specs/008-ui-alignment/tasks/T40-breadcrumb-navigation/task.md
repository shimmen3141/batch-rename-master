# T40 パンくずからfolderへ移動できるようにする

## 目的

`T38`が決めたパンくず(`内部ストレージ › Pictures › Screenshots`)の**folder名をtapすると、そのfolderへ移動できる**
ようにする。**`T38`の決定で、表示だけを`T39`に残し、tapによる移動はこのtaskへ分けた**(2026-09-23、開発者の判断)。

## なぜ分けたか、そして何が塞がっているか

`T38`は**選択中のheaderを`×`(全解除)へ入れ替える**と決めた。その結果、**選択中は`←`(上へ)が画面から消える**。

- **いまは2手**: `×`で解除してから`←`で上へ移動する。
- **このtaskが入ると**、選択したまま上位folderへ直接移動できる(移動した時点で004 REQ-016により選択は解除される。
  **選択が保たれるようになるわけではない** — 減るのは手数だけである)。

**この「選択中は上へ行けない」状態は、`T38`が受け入れた既知の代償である。** 直すのはこのtaskだが、**不具合ではない。**

## 入力と依存

- `T38`の操作状態表(`specs/008-ui-alignment/tasks/T38-define-browser-selection-navigation/task.md`)。
- `T39`が実装するパンくずの表示。**表示が入ってからでないと着手できない。**
- 004 REQ-015(辿れる上限は保存場所のroot) / REQ-016(folder移動で選択を解除)。**どちらも変えない。**

## 決めること

- **どこまでtapできるか。** 先頭の保存場所名もtap対象にするか(= rootへ移動)。**保存場所の一覧へ戻す操作とは別物**である。
- **パンくずが画面幅に収まらないとき**の扱い(省略、横scroll、末尾優先など)。tapできる範囲が幅で変わってよいか。
- **いま居るfolder自身**(パンくずの末尾)を押したときに何も起きないことを、要求にするか実装裁量にするか。

## 決定(2026-09-23)

| 論点 | 決定 | 決定者 |
|---|---|---|
| どこまでtapできるか | **先頭の保存場所名もtap対象にし、その保存場所のrootへ移動する。** 保存場所の一覧へ戻す操作(root(複数)の`←`)とは別物のまま | 開発者 |
| 幅に収まらないとき | **`T39`の形(末尾を見せ、横へ送れば先頭まで見える)を保ち、送った先の区切りもtapできる。** 省略表示は入れない。tapできる範囲は幅で変わらない | Agent(`T39`の結果に沿う既定。開発者へ報告済み) |
| いま居るfolder(末尾) | **tapしても何も起きない**(buttonにしない)。実装裁量として扱い、widget testで固定する — 押すと同じfolderへ入り直して選択が消えるため | Agent(同上) |

## machine検証範囲

widget testとmutationで閉じる(上の受け入れ証拠)。**manual確認は受け入れ証拠に含めない**(`task.json`の`manualVerification`は`null`のまま)。
tapの押しやすさ(当たり判定の広さ)のエミュレータ上の感触は機械で閉じられないので、残余riskとして受容する。**引き受け先は`008:T13`**(同じbrowser画面のfile行を触り、エミュレータのmanual確認を持つ。その手順へ「パンくずの途中の区切りを1回押す」を1項目足す)。

## 変更範囲の見込み

- `lib/ui/file_source/storage_browser_view.dart` のパンくず。
- **004 specの変更は要らない見込み** — 現在地の提示方法は「自由とする点」にあり、移動しても REQ-015 の上限と
  REQ-016 の解除は変わらない。着手時に確かめ、変えるなら仕様更新を先に行う。

## 受け入れ証拠

- widget test: 途中のfolder名をtapするとそのfolderの中身になり、**選択が解除される**(REQ-016)。
  **rootより上へは行けない**(REQ-015)。
- 幅が狭いときの見え方を機械で固定する。
- `flutter test` / `flutter analyze` / `dart format` がPASS。
- exact rangeの独立review PASS。

## 実装の記録(2026-09-23)

実装は Claude Opus 5.5。起点は`dev`@`6e3cc95`、branch `asdd/008-ui-alignment/T40-breadcrumb-navigation`。

- `lib/ui/file_source/storage_browser_view.dart`: 末尾以外の区切りを`Semantics(button)` + `InkWell`にし、押すと`_enter(location, folder: segment.path)`で移る。**既存の`_enter`を通すので、選択の解除(REQ-016)とdrag選択の終了は既存の処理がそのまま担う。** 行き先は`breadcrumbOf`が作るroot以下のpathだけ(REQ-015)。当たり判定の余白(左右4・上下6)を足した分だけ帯の余白を減らし、文字の位置は`T39`のまま(左寄せのtestが変わらずPASS)。
- 004 specは変えていない(現在地の提示方法は「自由とする点」。移動してもREQ-015の上限とREQ-016の解除は変わらない)。

### 自動検証

- `flutter test test/spec_004_file_source/storage_browser_view_test.dart`: 63件PASS(T40で6件追加: 途中のfolderへ移動し選択解除 / 先頭でrootへ(`/storage`を列挙しない) / 保存場所が複数でも一覧へは戻らない / 末尾は押せず選択が残る / semanticsでbuttonとして名前で押せる / 幅に収まらないとき横へ送った先の先頭を押せる)。
- `flutter test`: 989件PASS。`flutter analyze`: No issues。`dart format`: 0 changed。

### mutation

AGENTS.mdの方針どおり、`command`を`flutter test test/spec_004_file_source/storage_browser_view_test.dart`へ絞り、T40で足した4件とパンくず・移動を守る既存5件を回した(2分):

```text
M108 | KILLED | lib/ui/file_source/storage_browser_view.dart | folderを移動しても選択を残す | exit 1
M412 | KILLED | lib/data/file_source/storage_browser.dart | パンくずがrootより上を名指しする | exit 1
M420 | KILLED | lib/ui/file_source/storage_browser_view.dart | パンくずを右寄せに戻す | exit 1
M421 | KILLED | lib/ui/file_source/storage_browser_view.dart | パンくずの`›`を薄い`textMuted`に戻す | exit 1
M425 | KILLED | lib/ui/file_source/storage_browser_view.dart | 深い階層でパンくずを先頭側に寄せる | exit 1
M427 | KILLED | lib/ui/file_source/storage_browser_view.dart | 区切りを押しても移動しない | exit 1
M428 | KILLED | lib/ui/file_source/storage_browser_view.dart | どの区切りを押してもrootへ移る | exit 1
M429 | KILLED | lib/ui/file_source/storage_browser_view.dart | いま居るfolder(末尾)も押せる | exit 1
M430 | KILLED | lib/ui/file_source/storage_browser_view.dart | 区切りをbuttonとして支援技術へ示さない | exit 1
9 mutations: 9 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。browser関連の全mutationの`find`が現行コードに1回ずつ一致することも確かめた。)

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。AGENTS.mdの差分review(連鎖)に従う。

- attempt 1: `6e3cc95..8098562`(全範囲) — **PASS**(P2が1件)。P0/P1なし、安全網の穴なし。決定とREQ-015/016・T38/T39との整合、追加testが本物であること、M427〜M430の妥当性、full test 989件PASSを確認された。reviewerの範囲付きmutation 6件(M108・M412・M427〜M430)はKILLED。
  - **P2(成果物の欠陥)**: tapの押しやすさの残余riskに引き受け先のtaskが無かった。→ `008:T13`を引き受け先にし、T13のhandoffへ1項目を足した。
  - **SELF-CHECK**(AGENTS.mdの差分review): P2を閉じる差分は`specs/`だけ(T40とT13のtask.md)で、`lib/`・`test/`・`tool/`・依存・build設定に差分が無いことを`git diff --stat 8098562..HEAD`で確かめた。再reviewは起動しない。

## Current state / handoff

- Last checkpoint: **完了**(2026-09-23)。PR #189をAgentがmergeした(AGENTS.mdのauto-merge条件1〜7を満たした: review連鎖 = attempt 1 PASS + SELF-CHECK、CI SUCCESS、未解決threadなし、`dev`と競合なし、manual必須なし)。統合後の`dev`@`a965484`で`flutter analyze` PASS、`flutter test` 989件PASS、workspace check PASS。
- Blocker category: なし。
- Evidence revision: code `3dd417d`、merge commit `a965484`。
- Waiting for: なし。
- Requested action: なし。
- Next Agent action: なし。残余risk(tapの押しやすさ)は`008:T13`のmanualが引き受ける。
