# ファイル選択・リストUI(file-list) 振る舞い仕様

- Status: draft
- Level: Light（正しさの正本は本ファイル。視覚デザインは非規範）

## 目的（説明的・正誤判定には使わない）

メイン画面のプレゼンテーション状態層 `FileListController` の振る舞いを定義する。ファイル一覧の保持・選択・ソート・カスタム順・ルール注入から、各行の「現在名／変更後名（001 のプレビュー）」を供給する。ウィジェットはこの状態を描画する薄い層で、視覚デザインは本仕様の対象外（後日の参考デザインですり合わせ）。

## 境界

- 対象（in scope）: `FileListController` の状態と操作、行データ（RowView 列）の算出、ソート種別、カスタム順への自動切替。
- 対象外（out of scope）: 実ファイル読み込み（004）・リネーム実行（005）・ルール構築UI（003）・エクスプローラ D&D（006）・視覚デザイン（レイアウト/配色/余白）。
- アクター: ユーザー操作（ウィジェット経由）、注入元（003 の `RenameRule`、004 の `FileEntry` 一覧）。
- 入力: `List<FileEntry>`、`RenameRule`（注入、既定は元名トークンのみ）、`now`。
- 出力: 行データ列（各行の現在名・変更後名・選択状態）、現在のソート種別。
- 永続化される状態: なし（画面内の表示状態のみ）。
- 外部副作用: なし（ファイル操作は行わない）。

## 振る舞い

### 状態変数

- `items`: 表示順の `FileEntry` 列。
- `selectedOf(item)`: 各 item の選択フラグ。
- `sortMode`: `name` / `createdAt` / `size` / `custom`。
- `rule`: プレビューに用いる `RenameRule`（注入。既定は元名トークンのみ）。

### 操作（イベント）

| 操作 | 効果 |
|------|------|
| 初期化(files, rule) | `items` = 入力順、選択 = 既定状態（open_question）、`sortMode` = 入力順を表す初期値、`rule` を保持 |
| `setSortMode(mode)` | `items` を mode の comparator で安定ソートし、`sortMode` を更新（`custom` 指定時は現在の順を保持） |
| `reorder(oldIndex,newIndex)` | `items` をその移動後の順に並べ替え、`sortMode` を `custom` へ自動切替 |
| `toggleSelection(item)` | その item の選択を反転 |
| `selectAll()` / `clearAll()` | 全 item を選択 / 全解除 |
| `setRule(rule)` | プレビューに使う `RenameRule` を差し替え |

### 要件

| ID | 優先度 | 要件（外部から観測可能な文で） | 検証 |
|---|---|---|---|
| REQ-001 | must | 初期化後、`items` は入力の並び順を保持し、各行の現在名は `FileEntry.name` に等しい。 | VER-001 |
| REQ-002 | must | `setSortMode(name/createdAt/size)` は該当キーで昇順・安定ソートし、`sortMode` を更新する。 | VER-001 |
| REQ-003 | must | `reorder` は `items` を移動後の順に並べ替え、`sortMode` を `custom` へ自動的に切り替える。 | VER-001, VER-002 |
| REQ-004 | must | `toggleSelection` は対象の選択を反転し、`selectAll`/`clearAll` は全選択/全解除にする。 | VER-001, VER-002 |
| REQ-005 | must | `setRule` はプレビューに用いるルールを差し替え、以降の行データに反映される。 | VER-001 |
| REQ-006 | must | 行データは現在の `items` 順で供給され、選択行の変更後名は 001 の `generatePreview`（選択行を表示順で連番割り当て）に一致する。 | VER-001 |
| REQ-007 | should | 未選択行は変更後名を持たない（プレビュー対象外として供給する）。 | VER-001 |

### 代表例

`now` は固定。rule は既定（元名トークンのみ）または注入されたもの。

| # | 状態・操作 | 期待 | 備考 |
|---|---|---|---|
| 1 | files=[b,a,c] を name でソート | items=[a,b,c] | 昇順・安定 |
| 2 | reorder で c を先頭へ | items=[c,...]、sortMode=custom | 自動切替（REQ-003） |
| 3 | rule=[連番 桁2]、3件選択、b を未選択 | 選択行の変更後名が表示順で 01,02… | 連番は選択行のみ・上から（001 準拠） |
| 4 | clearAll 後 | 全行が未選択・変更後名なし | REQ-004/007 |

## 自由とする点（実装に委ねる）

- `RowView` / コントローラの内部表現（ChangeNotifier か否かを含む）。
- ウィジェットのレイアウト・配色・余白・アイコン・アニメーション（視覚デザインは非規範）。
- comparator の内部実装（安定ソートの結果が満たされれば自由）。

## 対象外・未定義とする点

- 視覚デザインの詳細（後日の参考デザインで確定）。
- ファイルの読み込み・リネーム実行・権限（004/005）。

## 検証

| ID | 種別 | 成果物パス | 対象 |
|---|---|---|---|
| VER-001 | unit | test/spec_002_file_list/controller_test.dart | REQ-001〜007 |
| VER-002 | widget | test/spec_002_file_list/file_list_view_test.dart | REQ-003, REQ-004（ウィジェット操作→状態反映） |

## 反証ログ

| 観点 | 結果 |
|---|---|
| 仕様を見ずに書いた例との照合 | 代表例4件を状態遷移と照合。例3で「連番は選択行のみ・表示順」を 001 の generatePreview に委ねる形に整理（重複定義を避けた）。 |
| 弱すぎ（ズルい実装） | REQ-006 を「001 の generatePreview に一致」と接続し、変更後名を空返しする実装を排除。REQ-002 に安定・昇順を明記し空ソートを排除。 |
| 強すぎ（過剰な条件） | 内部表現・視覚を「自由とする点」で明示的に解放。ソート方向・名前順の詳細は open_questions に送り固定しすぎない。 |
| 異常系の網羅 | 空 files（行データ空）、全未選択（プレビュー空）、reorder の端インデックスを VER-001 で扱う。 |
| 判定不能語 | 「使いやすい」等の判定不能語を排し、操作→観測可能な状態変化で記述。 |

## 未解決事項（approved にする前に解消。各行に推奨デフォルトを併記）

- 既定の選択状態: [ASSUMED] 全選択（リネーム対象を明示しやすい。PRD は「全選択または全解除」）。
- 名前ソートの順序: [ASSUMED] 自然順（数値を数値として比較、`file2` < `file10`）・大文字小文字を区別しない。
- ソート方向: [ASSUMED] 昇順固定（MVP）。昇降トグルは将来。
- 未チェック行の変更後名表示: [ASSUMED] 変更後名を供給せず現在名のみ（プレビュー対象外を示す）。
- 同値時のソート安定性: [ASSUMED] 安定（元の相対順を保持）。
- 初期 `sortMode`: [ASSUMED] 入力順を表す `custom`（読み込んだ順をそのまま表示）。
