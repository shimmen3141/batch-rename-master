# T23 読み込んだ場所の表示を読めるようにする

## 目的

読み込み帯が出す場所の文字列が、**入りきらないときに判別できる部分を残す**ようにする。
あわせて、製品経路からは到達できない**複数folderの表示**を実機で目視できる状態を作る。

## 入力と依存

- 観測の出所: [`T08`](../T08-load-affordance-and-path/task.md) の
  「manual確認の結果(2026-09-18。2回目)」。開発者の原文はそこにある。
- 現行実装: `lib/ui/file_source/file_source_bar.dart`(帯)、
  `lib/ui/file_source/storage_browser_view.dart` の `_displayPathOf`(文字列の作り手)、
  `lib/main.dart` の `_sampleFiles()`(demo data)。
- 承認済みの制約: 004 REQ-009(表示用の場所は**人間可読**。`should`。**省略の向きは定めていない**)、
  004 REQ-013(識別は不透明ハンドルが担うので、**表示を短くしても識別は壊れない**)、
  002 REQ-010 と `T22` の決定(行は**混在時だけ**場所を出す)。
- `T08` が固定した保証(**壊さない**): 帯が画面幅いっぱい / folder名の長さでbuttonが動かない /
  狭幅・大きい文字ではみ出さない。widget testと `M265`〜`M279` がある。

## 変更範囲

- 帯の場所表示の**省略の向き**、または場所を**2行目**へ出すかの選択(開発者の決定待ち)。
- demo data(`_sampleFiles()`)へ**2 folder分の場所**を入れる(質問2)。
- 上記に対応するwidget testとmutation。

**判定・状態遷移・読み込みの意味は触らない。** 帯の文言(`未選択` / folder名 / `複数のフォルダ` /
`ファイルを選ぶ` / `別フォルダへ`)の**決め方**も `T08` のまま変えない — 変えるのは
「決まった文字列が幅に入りきらないときの見せ方」だけである。

## なぜ末尾が消えるのか(2026-09-18に調べたこと)

帯が受け取る `sourceLocation` は **`保存場所名 + rootからの相対path`** である
(`_displayPathOf`)。保存場所名だけにする案は**独立review attempt 2 の P2-1 で否定されている** —
どのfolderから読み込んでも `Internal shared storage` と表示され、区別がつかなくなるためである。
その結果、実機では `Internal shared storage/DCIM/t07-fixtures` のような長い文字列になり、
`TextOverflow.ellipsis` が**末尾から削る**ので、**全folderで共通の接頭辞だけが残る**。

## 開発者の決定(2026-09-18): 案A — 先頭を省略して末尾を残す

| 案 | 見え方 | 代償 |
|---|---|---|
| A | 1行のまま、**先頭を省略して末尾を残す**(`…/DCIM/t07-fixtures`) | 帯の高さは増えない。実装は幅を測って先頭のsegmentを落とす形になる |
| B | **場所を2行目へ**出す(buttonは右上に固定のまま) | 多くの端末では全体が見える。帯が1行分高くなる(要望13の「余白を稼ぐ」方向と逆) |
| C | 1行のまま、入りきらなければ**末尾のfolder名だけ**(`t07-fixtures`) | 最短で確実に読める。**同名folderの区別が消える**(P2-1が否定した形に近い) |

**案Aを選んだ。** 帯の高さを増やさずに判別できる部分が残り、案Cが失う上位folderの区別も
幅がある限り残る。案B(2行化)と案C(末尾のfolder名だけ)は採らない。

## machine検証する範囲(着手時の宣言)

**閉じる**:

- 幅が足りるときは**全体を出す**。足りないときは**先頭のsegmentから落として `…/` を付ける**。
- **落とす段数は入るところまで**(`…/DCIM/t07-fixtures` が入るならそれを出し、`…/t07-fixtures` へ
  落とさない)。
- 1 segmentしか残らず、それでも入らないときは**末尾から省略する**(`t07-fix…`)。
  folder名の**頭**のほうが判別に効くためである。
- **`/` を含まない文言は形を変えない**(`未選択` / `複数のフォルダ` / 場所を持たないとき)。
- `T08` が固定した保証を壊さない: 帯が画面幅いっぱい / folder名の長さでbuttonが動かない /
  狭幅・大きい文字ではみ出さない。
- demo dataが**2 folder分の場所**を持ち、起動直後に帯が `複数のフォルダ`、各行に場所が出る。

**閉じられない範囲と引き受け先**:

- **実機の字形での見え方**(省略位置が読みやすいか、`…/` が記号として伝わるか)。
  → このtaskの `manual-verification.md` で開発者に見てもらう。
- **文字の大きさ・字体の最終調整** → [`T10`](../T10-spacing-and-typography/task.md)。

## 実装の記録(2026-09-18)

### 共有widget `SourcePathText` を作った

`lib/ui/file_source/source_path_text.dart`。**帯と行の両方が使う** — 同じ文字列
(004 REQ-009)を出しているので、片側だけ直すと混在時に見え方が割れる。

- `visibleSourcePathOf` が**表示文そのもの**を返す純関数である。`TextPainter` で候補を測り、
  **入る中で最も長いもの**を選ぶ。
- **測る体裁と描く体裁を揃える。** `Text` は `DefaultTextStyle` と混ぜてから描くので、
  混ぜた結果を測定にも描画にも渡す(混ぜる前で測ると境界が数px ずれて、省略が1段多くなる)。
- **文字倍率も測定へ渡す**(`MediaQuery.textScalerOf`)。無視すると端末の「文字を大きく」設定で
  予測が外れ、入らない文字列をそのまま出す(`T08` で2回踏んだはみ出しと同じ型)。
- 鍵は**実際に描く `Text`** へ付ける(`textKey`)。`RenderParagraph` を見て省略の有無を
  確かめる検査があるので、wrapperに付けると掴めない。

**1 segmentも入らないときだけ向きが逆になる** — `…/` を付けずに最後のsegmentを返し、
呼び出し側の `TextOverflow.ellipsis` に末尾を削らせる。folder名は**頭のほうが判別に効く**ためで、
`…/` を付けると読める文字がさらに2つ減る(対照 `M286`)。

### `/` を含まない文言は形を変えない

`未選択` / `複数のフォルダ` / 場所を持たないときは、落とせる段が無いので加工しない
(`segments.length < 2` で抜ける。対照 `M287`)。

### demo dataを2フォルダに分けた(質問2)

`main.dart` の `_sampleFiles()` を `Internal shared storage/DCIM/Camera` と
`Internal shared storage/Download` に分け、**表示用の場所と所属folderハンドルの両方**を持たせた。
片方だけにすると、001 の重複判定(folder単位)が1 folderとして数えて表示と食い違う。

**これが複数folder表示を実機で見られる唯一の経路である** — Androidは 004 REQ-016 で1 folder、
desktopのpickerもfolderを跨げない。`widget_test.dart` に「帯が `複数のフォルダ` を選び、行が
場所を出している」ことを固定した(対照 `M288`)。**「2種類見えるはず」とは書いていない** —
`ListView` は見えている行しか作らないので、viewportの高さに依存する検査になる。

## mutation の記録

`M278` の錨が `T23` で共有widgetへ移ったので**貼り直した**(意図「省略せず折り返す」は同じ)。
`M280`〜`M288` を足した。範囲を絞って実行した(`AGENTS.md` の手順どおり、表をscratchへcopyし
`command` を `flutter test test/spec_004_file_source test/spec_002_file_list test/widget_test.dart`
へ差し替えた)。

```text
10 mutations: 10 KILLED, 0 SURVIVED, 0 SKIPPED
M278 KILLED / M280 KILLED / M281 KILLED / M282 KILLED / M283 KILLED
M284 KILLED / M285 KILLED / M286 KILLED / M287 KILLED / M288 KILLED
```

**置かなかった対照**: `maxWidth.isFinite` の番をやめる mutation。`fits` は
`width <= double.infinity` を真と返すので**結果が変わらない**(等価mutant)。番は
「幅が決まっていないところでは縮めない」という意図の表明として残す。

## 検証の記録

**この表は commit ごとに置き換える。**

| 検査 | 結果 |
|---|---|
| `flutter test` | PASS(882。`T08` の866 + 16) |
| `flutter analyze` | PASS(No issues found) |
| `dart format --output=none --set-exit-if-changed .` | PASS(0 changed) |
| `mutation_check.py --list`(全表) | `279 mutations, 0 with an unexpected match count` |
| 範囲を絞った mutation | `M278`/`M280`〜`M288` = **10 KILLED, 0 SURVIVED** |
| `workspace.py check specs` | PASS(8 plans, 77 tasks) |
| Android実機 | **未実施**(`manual-verification.md`) |

## 受け入れ証拠

- 帯: 狭幅で `…/t07-fixtures` のように**末尾が残る**。幅が足りるときは丸ごと出す。
  `未選択` は形が変わらない。はみ出さない。
- 行: 混在時の場所も同じ見せ方になり、**共通の接頭辞だけが残る形**を排除した。
- demo: 起動直後に帯が `複数のフォルダ`、行に場所が出る。
- `T08` が固定した保証(帯の幅・buttonの位置・狭幅でのはみ出し)は**testごと据え置き**で、
  すべてPASSしている。

## Current state / handoff

- Last checkpoint: 実装と機械検証が完了(`flutter test` 882 PASS、範囲を絞った mutation 10 KILLED)
- Blocker category: review
- Waiting for: 独立review(Sonnet)
- Requested action: なし(人間の作業は実機確認から)
- Evidence revision: branch `asdd/008-ui-alignment/T23-source-path-legibility`(`dev@02aacc8` から作成)
- Next Agent action: 独立reviewを回し、PASSしたら実機確認を依頼する
