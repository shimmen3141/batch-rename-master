# T61 リネーム画面の行の補足情報を、使っている日時だけ「作成:」「更新:」で出す

## 目的

`T60` で定めた 002 REQ-013 を実装する。リネーム画面の行の補足情報に、並び順またはルールが使っている日時だけを出す。

## 入力と依存

- `T60`(002 REQ-013・代表例 14〜15・14b〜14d)。
- 今の実装: `lib/ui/file_list/file_list_view.dart` の `_DateSubInfo`(作成日時・更新日時・大きさを `Wrap` で並べる。`作成日時: 不明` の赤の強調は `T50`)。

## 見た目(視覚デザイン。開発者の指定)

| 使っている日時 | 表示 |
|---|---|
| どちらも使っていない | `2026/10/1 09:05`(更新日時、見出しなし)+ 大きさ |
| 作成だけ | `作成: 2026/9/30 08:05` + 大きさ |
| 更新だけ | `更新: 2026/10/1 09:05` + 大きさ |
| 両方で、表示上同じ | `作成・更新: 2026/10/1 09:05` + 大きさ |
| 両方で、違う | `作成: …` `更新: …` + 大きさ |
| 作成を使っていて不明 | `作成: 不明`(強調の条件は今のまま: 並び順が作成日時、またはルールの作成日時が空になる警告がある `T50`) |

- 「表示上同じ」は書式(`formatRowDateTime`、分まで)にした文字列が同じこと。
- 日時を使っているかは**一覧で1回だけ**決め、各行へ渡す(行ごとにルールを走査しない)。
- 場所(複数の場所のときだけ)、大きさの位置、`Wrap` の折り返し(作成日時を削らない)、作成日時の下限(`Flexible` + 省略)は変えない。

## 受け入れ条件

- [ ] 上の表のとおりに出る。
  - 証拠: widget test(並び順 × ルールの組み合わせ、一致と不一致、不明)と、使っている日時を決める関数の単体 test。
- [ ] `作成: 不明` の強調の条件が変わらない(002 代表例 15、`T50`)。
  - 証拠: 既存 test(文言の変更に伴う期待値の更新だけ)。
- [ ] 狭幅(320 / 360 / 411dp)× 文字倍率(1.0 / 1.3 / 2.0)で溢れない。大きさが削られない(`T48`)。
  - 証拠: widget test。
- [ ] Android エミュレータで見え方を確かめる。
  - 証拠: [manual-verification.md](manual-verification.md)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: どの日時を出すか・見出し・まとめ・不明の強調・溢れ。
- 端末(この task の manual): 実際の字体での見え方。

## 作業記録

- 2026-10-07 登録・着手(`T60` と同じ branch・PR)。

### checkpoint 1: 実装(`66f9c33`)

- `lib/ui/file_list/row_dates.dart`(新規): `RowDateUse`(作成・更新を使っているか)と `rowDateUseOf(sortMode, rule)`。ルールの `DateTimeToken` の `source` を見る(現在日時は数えない)。一覧の `itemBuilder` の外で**1回だけ**決め、`_FileRow` → `_DateSubInfo` へ渡す。
- `_DateSubInfo._dateItems()`: 出す日時を並べる。使っていない → 見出しなしの更新日時(`rowModifiedAtKey`)。表示上同じ(`formatRowDateTime` の文字列が同じ)→ `作成・更新: …`(`rowCreatedAtKey`)。それ以外 → `作成: …`/`作成: 不明`、`更新: …`。強調の条件(並び順が作成日時、または `T50` の警告)は変えていない。
- **どの日時にも `Flexible` + 省略の下限を付けた**(以前は作成日時だけ)。先頭がどの日時になっても溢れないため。`Wrap` で後ろの日時が次の行へ落ちる構造は同じ。
- test:
  - `row_dates_test.dart`(新規): 並び順だけ・ルールだけ・両方・現在日時を数えない・使わない場合。
  - `created_at_sort_view_test.dart` の REQ-013 の group を、更新後の代表例 14・14b・14c・14d・15 と「使わない」場合に書き換えた(**以前の例14「名前順でも不明を表示する」は仕様の変更で無くなった**)。
  - **既存 test の前提の更新**(主張は変えていない): `location_view_test.dart` は日時が出ていることを見るのに作成日時ではなく見出しなしの更新日時を見る。`row_presentation_test.dart`・`row_file_size_test.dart` は「2つの日時が行を取り合う」場合を見る test なので、並び順を作成日時・ルールに更新日時のトークンを入れて両方を出し、作成日時と更新日時を違う値にした(同じだと1つにまとまる)。`row_emphasis_test.dart` は文言を「作成: 不明」へ。
- mutation: `find` を追随させた M163(日時の下限)・M624(`T50` の強調)。足した M826〜M831。範囲付き(`flutter test test/spec_002_file_list test/spec_005_rename_exec test/widget_test.dart`、対象 `66f9c33`、8件):

```text
M163 | KILLED | lib/ui/file_list/file_list_view.dart
M624 | KILLED | lib/ui/file_list/file_list_view.dart
M826 | KILLED | lib/ui/file_list/row_dates.dart
M827 | KILLED | lib/ui/file_list/row_dates.dart
M828 | KILLED | lib/ui/file_list/row_dates.dart
M829 | KILLED | lib/ui/file_list/file_list_view.dart
M830 | KILLED | lib/ui/file_list/file_list_view.dart
M831 | KILLED | lib/ui/file_list/file_list_view.dart
8 mutations: 8 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`66f9c33`: `01:11 +1430: All tests passed!`。`flutter analyze` No issues、`dart format` PASS。

### 独立review attempt 1

- range `f704d85..d0e2725`(全範囲。`T60` と `T61`)。reviewer: Codex **gpt-6-luna**(開発者の指定。実装は Claude Opus 5.5)。
- 判定: **PASS**。P0/P1 なし。仕様(REQ-013・代表例・更新節・Status 行)が承認の範囲どおりで、行データの供給・REQ-011・005 REQ-009 との境界を保つこと、日時を一覧で1回だけ決めること、表示上の比較と不明のときにまとめないこと、強調の条件(`T50` を含む)、`Flexible` の下限、既存 test の書き換えが主張を緩めていないことを確かめた。reviewer の実行結果: `flutter analyze` No issues、`dart format` PASS、`flutter test` `01:09 +1430: All tests passed!`、`workspace.py check` PASS。reviewer が回した mutation(範囲付き):

```text
M163 | KILLED | M624 | KILLED | M826 | KILLED | M827 | KILLED | M828 | KILLED
M829 | KILLED | M830 | KILLED | M831 | KILLED
M832 | KILLED | Reviewer control: keep rule warning emphasis but drop createdAt sort emphasis
9 mutations: 9 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 指摘 P2 ×1(成果物の欠陥・記録): `T60`・`T61` の `task.json` の `pullRequest` が `null`(PR #233)。

### SELF-CHECK(attempt 1 の後)

- P2 を閉じた: 両方の `task.json` に `pullRequest: 233` を書いた。
- reviewer の対照を **M832** として取り込んだ。`find` の一致 PASS(752)、`flutter test test/tooling` PASS、範囲付き(`flutter test test/spec_002_file_list`)で `M832 | KILLED`、`1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED`。`lib/`・`test/` は変えていないので再reviewは起動しない。
- review の連鎖: `f704d85..d0e2725` PASS → `d0e2725..` SELF-CHECK。

## Current state / handoff

- Last checkpoint: 独立review attempt 1 PASS(`f704d85..d0e2725`)。Draft PR #233
- Blocker category: manual-evidence
- Evidence revision: `66f9c33`(code の最後の commit)
- Waiting for: 開発者(Android エミュレータの確認)
- Requested action: [manual-verification.md](manual-verification.md) の手順を行い、結果を会話で伝える
- Next Agent action: 結果を記録する。PASS なら `T60`・`T61` を done にし、PR #233 を ready にして merge する
