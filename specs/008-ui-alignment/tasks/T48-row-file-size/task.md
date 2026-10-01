# T48 行の補足情報へファイルサイズを足す

## 目的

一覧の各行で、**ファイルの大きさが読める**ようにする。

## 出所

開発者の相談(2026-10-01、`008:T10` の実機確認の後、原文): 「ファイルのサイズの情報も入れたいのですが、現状のUIにどのように入れるのがよさそうですか。」

Agent が3案を示した: A 補足情報(小さい灰色の「作成日時・更新日時」)の日時の後ろへラベル無しで足す / B 変更前の名前と同じ行の右端 / C サイズ順のときだけ出す。**開発者は A を選んだ**(「Aでやります。」)。

## 範囲

- 行の補足情報の `Wrap` に、日時の後ろへ `2.4 MB` の形でサイズを足す(ラベル無し)。002 REQ-010 は場所を「作成/更新日時・サイズと同格の副題」としており、仕様の想定内である。
- 単位は参考design(`docs/design/Bulk Renamer.html` の `fmtSize`)に合わせる: 1024 未満は `B`、KB は整数、MB は小数1桁。**GB を足す**(参考design に無い。動画で届く)。
- 見え方は既存の補足情報と同じ(`textMuted`・`AppFontSize.caption`)。

## 確かめること

- スマホ幅(320 / 360 / 411dp)と文字倍率 1.0 / 1.3 / 2.0 で、overflow せず、作成日時が削られない(`Wrap` で落ちる)。
- **行の高さが増えるか**を測って記録する。見積もりでは、スマホ幅では日時が既に2行に分かれ、サイズは2行目の更新日時の横に収まる(未測定)。増えるなら開発者へ報告する。
- 単位の境界(1023 B / 1 KB / 1 MB / 1 GB)の単体 test。

## 対象外

- 並び順(サイズ順は既にある)。サイズの取得(001 の `FileEntry.size` を使う)。

## 受け入れ証拠

- widget test(サイズが出る・狭幅と文字倍率で overflow しない・行の高さの記録)と単位の単体 test。mutation。
- `flutter test`・`flutter analyze`・`dart format`。
- 独立review。
- `manual-verification.md` で Android 実機と Windows desktop の見え方を確認する。

## Current state / handoff

- Last checkpoint: 登録しただけ(2026-10-01)
- Blocker category: none
- Evidence revision: none
- Next Agent action: branch と worktree を作り、in_progress にして、単位の整形と行への表示を test から足す
