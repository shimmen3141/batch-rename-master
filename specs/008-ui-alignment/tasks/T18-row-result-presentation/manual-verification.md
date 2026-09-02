# 手動確認: 行の結果表示

## この文書の状態

**このtaskはまだ実装されていません。人間へ依頼できる手順はまだありません。**

画面文言もbuttonの位置も決まっていないため、いま手順を書くと実際の画面と食い違うものが
残ります。実行できるchecklistは実装時に書きます。

以下は**実装するAgent向けのmemo**です。

## 対象範囲

行の色分け・桁不足の行表示・(変更なし)・サブ情報の位置。

## 実装時にchecklistへ落とす観点

- `task.md`の受け入れ証拠のうち、**自動testで観測できないもの**だけを手順にする。
  widget testで足りるものを人間へ回さない。
- 実機で触らないと分からないこと(tap範囲、実フォントでの切り詰め、狭幅での可読性)に絞る。
- **行の警告のtap範囲を実機で確かめること**(`008:T16`から引き受けた残余risk。emulatorでは弱い)。

## 手順を書くときの規律

- **対象commitと、そのcommit以後にcode・dependency・build設定が変わっていないこと**を
  書く。変わったら証拠は再利用しない(`AGENTS.md`)。
- **受け入れ証拠をAgentが独断で緩めない。**`008:T16`は`task.md`が「Android実機」と
  書いているのに、この文書で「emulatorで構いません」と緩めて独立reviewに指摘された。
  緩めるなら人間へ尋ねる。
- 共通の起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)へlinkし、複製しない。
