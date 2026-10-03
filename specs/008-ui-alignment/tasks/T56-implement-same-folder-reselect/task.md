# T56 一覧の先頭のfolder行から同じfolderを開き直す導線を実装する

## 目的

`T26` で承認された 004 REQ-021(同じ folder を一覧の状態を初期値にして開き直す)と 002 REQ-021(確定したときの並び)を
実装する。入口は一覧の先頭の folder 行に置く(`T26` の人間の決定)。

## 仕様の正本

- [`specs/004-file-source/spec.md`](../../../004-file-source/spec.md) の REQ-015 / REQ-021、代表例 36〜43、「008:T26 由来の更新」節。
- [`specs/002-file-list/spec.md`](../../../002-file-list/spec.md) の `reselectFiles`、REQ-021、代表例 28〜31、「008 T26 由来の更新」節。
- 提示の決定と経緯: [`T26`](../T26-define-picker-state-restore/task.md) の「開発者の決定」。ここへ複製しない。

## 範囲

- 002: `FileListController.reselectFiles`(置き換え・全件選択・同一ハンドルの集約は `setFiles` と同じ。並びだけ REQ-021)。
- 004: browser を「所属 folder を表示し、指定したハンドルを選択済み」で開ける入口。確定は `reselectFiles` へ結線する。
  folder が無い・列挙できないときは browser に入らず一覧無変化で理由を示す。
- 一覧: **所属 folder が1つ**のとき、一覧の先頭に細い folder 行(folder 名と右端の `＋ 追加`)を出す。スクロールしても先頭に残す。
  行全体のタップでは開かない(`T24` の折りたたみのために空ける)。除去の選択モード中・場所を持たない一覧(demo data)・desktop では出さない。
- 読み込み時と同じく、確定後に占有名を取り直す(`T54`。`setFiles` と同じ経路に載せる)。
- 対象外: 複数 folder を束ねる表示(`T24`)、上部の帯の変更(帯との名前の重複は manual で見て判断する)。

## design 土台との照合

`docs/design/Bulk Renamer.html` には folder 行が無い。**離れる点**: 一覧の先頭に folder 行を足す。理由: `T26` の人間の決定
(004 REQ-021 の入口)。帯・行・下部の帯の配置は変えない。

## machine検証範囲と引き受け先

- unit: `reselectFiles` の代表例 28〜31、`setFiles` の REQ-008(custom → 名前の昇順)が変わらないこと。
- widget: 代表例 36〜43(初期の選択、足す・外す・Cancelled・別 folder へ移る・改名後のハンドル・folder 消失・「別フォルダへ」は保存場所から)。
  folder 行の出る条件(1 folder / 選択モード中 / demo data)と、行全体のタップで開かないこと。
- mutation で上の判定が KILLED になることを確かめる。
- **Android エミュレータ**: folder 行の見え方、sticky、帯との重複の見え方、実ファイルでの開き直しと確定。この task が引き受ける。

## 受け入れ証拠

- 上の test が PASS し、既存の test を弱めない。format / analyze / full test / workspace check PASS。
- mutation の生出力。
- エミュレータでの manual 確認 PASS(`manual-verification.md` は着手時に作り、`task.json` へ書く)。
- exact range の独立 review PASS。

## Current state / handoff

- Last checkpoint: `T26` が仕様を定義し、開発者が承認した(2026-10-03)。起票
- Blocker category: none
- Waiting for: なし
- Requested action: なし
- Evidence revision: 未着手
- Next Agent action: `T26` の merge 後に着手する。`storage_browser_view.dart` の起点と初期選択の受け口を足すところから始める
