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

## 作業記録

- 2026-10-01 / 着手(開発者の決定「Aでやります。」)。branch `asdd/008-ui-alignment/T48-row-file-size`、worktree `/workspace/.worktrees/008-T48-row-file-size`、起点 `dev`@`c3cf6d2`。

### checkpoint 1: 大きさの表示(`5b93d9f`)

- `lib/ui/file_list/file_size_format.dart` の `formatFileSize`: 1024 未満は `B`、KB は整数に丸め、MB・GB は小数1桁。**丸めで次の単位へ届いたら次の単位で書く**(`1048575` → `1.0 MB`。参考design の `fmtSize` をそのまま使うと `1024 KB` になる)。単位は参考designと同じ 1024 刻み。
- 行の補足情報の `Wrap` の末尾へ、ラベル無し・日時と同じ見え方(`textMuted`・`caption`)で置いた(`rowSizeKey`)。
- test: `test/spec_002_file_list/row_file_size_test.dart`(単位の境界、日時の後ろ・同じ見え方、320/360/411dp × 1.0/1.3/2.0 で overflow せず大きさが削られず作成日時の行へ割り込まない)。
- **行の高さ(測定)**: test の字体 Ahem(1文字 = 1em)では、320・360・411dp で大きさが3行目に落ち、行が 15px(補足情報1行ぶん)高くなる。800dp では3つが1行に並ぶ。測り方: 一時 test(commit していない)で `FileListView` に1行(`createdAt`・`modifiedAt` あり、`size: 2516582`)を描き、`tester.getRect` で `rowCreatedAtKey`・`rowModifiedAtKey`・`rowSizeKey` を出力した。生出力:

```text
w=320.0 created=Rect.fromLTRB(74.0, 144.0, 276.0, 159.0) modified=Rect.fromLTRB(74.0, 159.0, 276.0, 174.0) size=Rect.fromLTRB(74.0, 174.0, 138.5, 189.0)
w=360.0 created=Rect.fromLTRB(74.0, 144.0, 310.5, 159.0) modified=Rect.fromLTRB(74.0, 159.0, 310.5, 174.0) size=Rect.fromLTRB(74.0, 174.0, 138.5, 189.0)
w=411.0 created=Rect.fromLTRB(74.0, 144.0, 310.5, 159.0) modified=Rect.fromLTRB(74.0, 159.0, 310.5, 174.0) size=Rect.fromLTRB(74.0, 174.0, 138.5, 189.0)
w=800.0 created=Rect.fromLTRB(74.0, 128.0, 310.5, 143.0) modified=Rect.fromLTRB(318.5, 128.0, 555.0, 143.0) size=Rect.fromLTRB(563.0, 128.0, 627.5, 143.0)
```

  (大きさの `top` が更新日時の `bottom` と同じ = 3行目。800dp は3つの `top` が同じ = 1行。)**実際の字体での見積もり**: 更新日時 ≒ 140px + 間 8 + `2.3 MB` ≒ 35px = 183px で、補足情報の幅(320dp で約 202px、360dp で約 236px)に収まる → 行は高くならない見込み。manual 1 で確かめる。
- **作成日時の省略は Ahem では以前から起きている**(320〜411dp。作成日時の文字列が補足情報の幅を超える)。この変更で増えたものではないので、test は「大きさが作成日時の行へ割り込まない」を主張にした。
- 範囲付き mutation(`flutter test test/spec_002_file_list test/widget_test.dart`、対象 `5b93d9f`、5件):

```text
M616 M617 M618 M619 M620 すべて KILLED
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```
- 検証(`5b93d9f`): `flutter test` +1151 PASS、`flutter analyze` No issues、`dart format` 0 changed、`check_mutation_finds.py` 569 PASS。

### manual

- `manual-verification.md` を1回目の手順にした(0 build の見分け、1 行の大きさと行の高さ、2 文字最大、3 Windows desktop)。デモの大きさの書き方は `formatFileSize` と同じ規則で計算した値を載せた。

### 実機確認 1回目(2026-10-01)

- 対象: `lib/` が `5b93d9f` と同一の build(worktree HEAD `46258c7`)。Android エミュレータと Windows desktop。手順 `manual-verification.md` の 0〜3。
- 受領: 2026-10-01、会話で開発者から「確認事項について、問題ありませんでした。」→ **0〜3 すべて期待どおり**(大きさがラベル無しで日時と同じ見え方、スマホ幅で更新日時の行に収まり行が高くならない、文字最大ではみ出さない、Windows の広い窓で1行・狭い窓ではみ出さない)。
- 1000 刻み(Android のファイルアプリ)と 1024 刻みの違いは報告で伝えた。変更の要望は無く、1024 刻みのままとした。

### 独立review

reviewerは`gpt-6-luna`(開発者指定。AGENTS.md の既定「実装より一段軽い」に代えて従った)。

- **attempt 1**: `c3cf6d2..3979a86`(全範囲) — **PASS**。確認された点: `formatFileSize` の単位・丸め・繰り上げと境界の test / 補足情報の末尾・同じ見え方 / `008:T07` の既存の保証を含む full regression 1151 PASS / M616〜M620 KILLED / manual のデモの値が `lib/main.dart` と一致 / Ahem の結果と実際の字体の見積もりの区別。analyze・format・`workspace.py check specs` PASS。
  - **P2(成果物の欠陥)**: 行の高さを「測定」と書いたが、測り方と出力が記録に無く再現できない → 一時 test の測り方と生出力を checkpoint 1 へ足して閉じた(**SELF-CHECK**、記録だけの差分)。
- 連鎖: `c3cf6d2..3979a86` PASS → 以後の記録だけの差分は SELF-CHECK。
- **SELF-CHECK**: `3979a86..HEAD` は `specs/` だけ(review・P2 の記録・handoff・実機確認の記録)。`lib/`・`test/`・`tool/` に差分なし。
