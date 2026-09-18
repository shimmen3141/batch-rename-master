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

## 開発者へ出した選択肢(2026-09-18)

| 案 | 見え方 | 代償 |
|---|---|---|
| A | 1行のまま、**先頭を省略して末尾を残す**(`…/DCIM/t07-fixtures`) | 帯の高さは増えない。実装は幅を測って先頭のsegmentを落とす形になる |
| B | **場所を2行目へ**出す(buttonは右上に固定のまま) | 多くの端末では全体が見える。帯が1行分高くなる(要望13の「余白を稼ぐ」方向と逆) |
| C | 1行のまま、入りきらなければ**末尾のfolder名だけ**(`t07-fixtures`) | 最短で確実に読める。**同名folderの区別が消える**(P2-1が否定した形に近い) |

## Current state / handoff

- Last checkpoint: taskを作成し、`T08` の2回目の実機確認から要望を受け取った
- Blocker category: decision
- Waiting for: 上の案A/B/Cの選択(開発者)
- Requested action: 案A/B/Cのどれで場所を見せるかを選ぶ(質問済み)
- Evidence revision: 未着手(観測は `T08` の `f71e2f6` に対する2回目の実機確認)
- Next Agent action: 選ばれた案を記録し、実装 → 機械検証 → 独立review → 実機確認。
  実機確認は**質問2のdemo data**と同じ回にまとめて依頼する
