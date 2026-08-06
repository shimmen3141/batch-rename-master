# ルール構築UI(rule-builder) 振る舞い仕様

- Status: approved
- Level: Light（正しさの正本は本ファイル。視覚デザインは非規範）

## 目的（説明的・正誤判定には使わない）

トークンビルダーの状態層 `RuleController` の振る舞いを定義する。編集中のトークン列（001 の `Token`）を保持し、追加・削除・並び替え・差し替えの各操作で 001 の `RenameRule` を組み上げ、変更を通知する。この `RenameRule` を 002 の `FileListController.setRule` に渡すとリアルタイムプレビューへ反映される。ウィジェット（Chip 列・詳細エディタ・レスポンシブ外殻）はこの状態を描画・操作する薄い層で、視覚デザインは本仕様の対象外。

## 境界

- 対象（in scope）: `RuleController` の状態（トークン列）と操作（追加・削除・並び替え・差し替え）、`RenameRule` の組み上げ、変更通知。
- 対象外（out of scope）: トークンの評価・プレビュー生成・検証（001）／ファイル一覧・選択・ソート・プレビュー表示（002）／視覚デザイン（レイアウト・配色）／ルールの永続化（プリセット保存・前回ルール復元は別機能）／元名トークンの大小変換（001 未対応）。
- アクター: ユーザー操作（ウィジェット経由）。
- 入力: 初期トークン列（省略時は空）、各操作の引数（`Token`・インデックス）。
- 出力: 現在のトークン列、組み上げた `RenameRule`、変更通知。
- 永続化される状態: なし（画面内の編集状態のみ。永続化は別機能）。
- 外部副作用: なし。

## 振る舞い（リアクティブ: 操作の順序が状態に影響する）

### 状態変数

- `tokens`: 編集順の `Token` 列（001 の sealed `Token`。5種: `OriginalNameToken` / `LiteralToken`（自由テキスト・区切り兼用）/ `SequenceToken` / `DateTimeToken`）。
- `rule`: `RenameRule(tokens)`（派生値。常に現在の `tokens` と一致）。

### 操作（イベント）

| 操作 | 効果 |
|------|------|
| 初期化([tokens]) | `tokens` = 与えられた初期列（既定は空） |
| `addToken(token)` | `tokens` の末尾に `token` を追加 |
| `removeAt(index)` | `index` の要素を取り除く |
| `reorder(oldIndex,newIndex)` | `oldIndex` の要素を取り出し `newIndex` の位置へ挿入（`onReorderItem` 規約: `newIndex` は削除後の挿入先） |
| `replaceAt(index,token)` | `index` の要素を `token` に差し替える（詳細編集の反映） |

### 要件

| ID | 優先度 | 要件（外部から観測可能な文で） | 検証 |
|---|---|---|---|
| REQ-001 | must | 初期化後、`tokens` は与えられた初期列を順に保持し（既定は空）、`rule.tokens` は `tokens` に等しい。 | VER-001 |
| REQ-002 | must | `addToken(token)` は `tokens` の末尾に `token` を追加する。 | VER-001, VER-002 |
| REQ-003 | must | `removeAt(index)` は `index` の要素だけを取り除き、他の要素の相対順を保つ。 | VER-001, VER-002 |
| REQ-004 | must | `reorder(oldIndex,newIndex)` は `oldIndex` の要素を取り出して `newIndex`（削除後の挿入先）へ挿入する。 | VER-001, VER-002 |
| REQ-005 | must | `replaceAt(index,token)` は `index` の要素を `token` に差し替え、位置と他要素を保つ。 | VER-001, VER-002 |
| REQ-006 | must | 上記いずれの変更操作後も `rule.tokens` は現在の `tokens` に等しく、リスナーへ変更を通知する。 | VER-001 |
| REQ-007 | should | `tokens` が空でも有効な状態であり、`rule` は空トークンの `RenameRule` を返す（評価結果は 001 の責務）。 | VER-001 |

### 代表例

| # | 状態・操作 | 期待 |
|---|---|---|
| 1 | 空から addToken(元名)→addToken(区切り'_')→addToken(連番) | `rule.tokens` = [元名, '_', 連番] の3件 |
| 2 | 上の状態で removeAt(1) | `rule.tokens` = [元名, 連番] |
| 3 | [A,B,C] で reorder(0,2) | `tokens` = [B,C,A]（onReorderItem 規約） |
| 4 | [連番(digits1)] で replaceAt(0, 連番(digits3)) | `rule.tokens` = [連番(digits3)]（位置保持・差し替え） |
| 5 | 全 removeAt して空 | `rule.tokens` = []（REQ-007） |

## 自由とする点（実装に委ねる）

- `RuleController` の内部表現（`ChangeNotifier` か否かを含む）。
- トークンの同一性の扱い（reorder/差し替えのキー戦略）。002 の identity 追従と揃えてよいが必須ではない。
- ウィジェットのレイアウト・配色・アニメーション・詳細エディタのUI形態（ダイアログ/ボトムシート/インライン）。
- 各追加ボタンが挿入する初期トークンの既定値（open_questions で確定するが、その通りなら実装形態は自由）。

## 対象外・未定義とする点

- 不正インデックス（範囲外の `removeAt`/`reorder`/`replaceAt`）の扱いは未定義（呼び出し側=ウィジェットが有効な index のみ渡す前提。必要なら実装で防御してよいが本仕様は要求しない）。
- 視覚デザインの詳細（後日の参考デザインで確定）。

## 検証

| ID | 種別 | 成果物パス | 対象 |
|---|---|---|---|
| VER-001 | unit | test/spec_003_rule_builder/rule_controller_test.dart | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007 |
| VER-002 | widget | test/spec_003_rule_builder/ | REQ-002, REQ-003, REQ-004, REQ-005 |

- VER-002 は上記 REQ の**UI 操作 → 状態反映**と、002 への `setRule` 連携によるプレビュー反映を見る。
- 上表の「対象」は照合用の ID 列のみ。観点の説明は各テストファイル冒頭のコメントに置く。

## 反証ログ

| 観点 | 結果 |
|---|---|
| 仕様を見ずに書いた例との照合 | 代表例5件を操作列と照合。例3で reorder を 002 と同じ onReorderItem 規約に固定（規約の取り違えを排除）。 |
| 弱すぎ（ズルい実装） | REQ-006 で「rule は常に現在の tokens に一致」と接続し、rule を空/固定で返す実装を排除。REQ-003/005 に「他要素の相対順・位置を保つ」を明記し、全消去や並べ替えを排除。 |
| 強すぎ（過剰な条件） | 内部表現・同一性戦略・詳細エディタのUI形態・視覚を「自由とする点」で明示的に解放。トークンの具体的既定値は open_questions に送り固定しすぎない。 |
| 異常系の網羅 | 空列（REQ-007）、全削除（例5）を明記。範囲外インデックスは「未定義」と明示（呼び出し側前提）。 |
| 判定不能語 | 「使いやすい」等を排し、操作→観測可能な状態変化で記述。 |

## 決定済み事項（旧・未解決事項。2026-08-02 に開発者承認で確定）

- 各追加ボタンの初期トークン: 元名=`OriginalNameToken()` / 自由テキスト=詳細エディタで非空を確定して初めて挿入（下記「自由テキストの空値」）/ 区切り=`LiteralToken('_')` / 連番=`SequenceToken(start:1,digits:2,increment:1)` / 日時=`DateTimeToken(source: created, format: 'YYYYMMDD')`。（連番 digits=2 は開発者指示）
- 区切りプリセットの集合: `-`（ハイフン）/ `_`（アンダーバー）/ 半角スペース / 全角スペース の4種。（全角スペースは開発者指示）
- 自由テキストの空値: 空を許容しない。詳細エディタは未入力（空文字）のあいだ確定ボタンを無効化し、非空の値でのみトークンを確定・差し替える（T4 のエディタ振る舞い。VER-002 で検証。`RuleController` 自体は汎用で値を検証しない）。
- 連番の入力範囲: **start ≥ 0・digits ≥ 1・increment ≥ 1（正のみ）**。負の連番・降順は採用しない（降順はリストのカスタム順で代替。将来必要になれば別途検討）。001 の `SequenceToken` 自体は任意整数を受けられ、制約は 003 のエディタ層のみ。
- 日時 format の指定方法: プリセット＋自由入力。自由入力は任意のフォーマット文字列を直接入力し、001 の記号 `YYYY/YY/MM/DD/HH/mm/ss` を展開・その他はそのまま出力（例 `YYYY年MM月DD日`→`2026年08月02日`）。プリセット集合は参考デザイン準拠で `YYYYMMDD` / `YYYY-MM-DD` / `YYYYMMDD_HHmmss` / `YYMMDD`。source は 001 の enum（created/modified/current）。**自由入力欄の UI 形態は T4 で検討**（開発者コメント）。
- レスポンシブのブレークポイント: 画面幅 < 840dp = モバイル（ModalBottomSheet）、≥ 840dp = デスクトップ（2ペイン）。
- 空ルール・全削除時の扱い: 空を有効状態として許容（REQ-007。プレビューの結果は 001 の責務）。
