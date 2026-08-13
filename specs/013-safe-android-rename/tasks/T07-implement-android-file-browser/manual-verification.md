# 手動確認: app内file browser

## この文書の状態

**このtaskはまだ実装されていません。人間へ依頼できる手順はまだありません。**

画面文言もbuttonの位置も決まっていないため、いま手順を書くと実際の画面と食い違うものが残ります。実行できるchecklistは実装時に書きます。

以下は**実装するAgent向けのmemo**です。

## 実装時にchecklistへ落とす観点

- `task.md`の受け入れ証拠のうち、**自動testで観測できないもの**だけを手順にする。widget testで足りるものを人間へ回さない。
- 実機で触らないと分からないこと(tap範囲、SafeArea、swipeの誤爆、狭幅での可読性、操作の分かりやすさ)に絞る。
- AndroidとWindows desktopで挙動が違う項目は、両方の節を分けて書く。

## 手順を書くときの規律

このprojectで実際に踏んだ失敗を繰り返さないこと。

- **PowerShellの変数を使わない。** pathは毎回literalで書く。手順を上から実行するとappを起動したterminalが埋まり、確認は別terminalになるため、前のblockの変数は残らない。
- **各stepの先頭でfixtureを作り直す。** 改名を重ねると名前が伸びるなど、step間の状態依存で後半が成立しなくなる。
- **依頼前にdry-runする。** 記載する画面文言・path・commandを`git grep`でcurrent revisionと突き合わせる。設定画面のアプリ名は`AndroidManifest.xml`の`android:label`、Recentsは`MaterialApp.title`、アプリ内見出しはAppBarで、3つとも別物。
- **返信templateやstatus欄を作らない。** 結果は会話で自由形式で受け取り、Agentが`task.md`へ要約する。
- **独立reviewを先に通してから依頼する。** reviewの指摘でcodeが変わるとmanual証拠が失効する。

## 事前準備(実装時に具体化する)

起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)に従う。
