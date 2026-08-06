# ルール永続化(rule-persistence) 振る舞い仕様

- Status: approved
- Level: Light（正しさの正本は本ファイル）

## 目的（説明的・正誤判定には使わない）

直近に組み立てた「現在のルール」1件を永続化し、次回起動時に復元する。中核は 001 の `RenameRule`/`Token` の **JSON シリアライズ/デシリアライズ**（純粋関数=変換システム）。加えて、ストレージの抽象ポート `RuleStore` と、その上に載る**復元（起動時）/ 保存（変更時）**の小さなオーケストレーション（リアクティブ）を定義する。

## 境界

- 対象（in scope）: `serializeRule` / `deserializeRule`（RenameRule ⇔ JSON 文字列）、`RuleStore` ポートの契約、`loadLastRule` / `saveCurrentRule` のオーケストレーション。
- 対象外（out of scope）: トークンの評価・命名（001）／ルール編集 UI（003）／名前付きプリセット（複数保存・別機能）／undo 履歴。ストレージの具体実装（`shared_preferences` 等）は本仕様の対象外で、`RuleStore` 契約を満たす限り自由（実装は T5、実永続化はホスト検証）。
- アクター: アプリ起動時の復元処理、`RuleController` の変更購読。
- 入力: `RenameRule`（保存時）、JSON 文字列（復元時、`RuleStore` から）。
- 出力: JSON 文字列（保存時）、`RenameRule`（復元時）。
- 永続化される状態: 「現在のルール」1件（`RuleStore` が保持）。複数世代・履歴は持たない。
- 外部副作用: `RuleStore.write` によるストレージ書き込みのみ。

## 振る舞い

### 操作（変換 = 純粋関数）

| 操作 | 契約 |
|------|------|
| `serializeRule(rule)` | `rule` を JSON 文字列にする。バージョン欄と、各トークンの `type` タグ + パラメータを含む |
| `deserializeRule(json)` | JSON 文字列を `RenameRule` に戻す。失敗時（不正JSON・未知 type・欠損フィールド・非対応バージョン）は `null` |

### 操作（リアクティブ = ストレージ連携）

| 操作 | 契約 |
|------|------|
| `RuleStore.read()` | 保存済み文字列を返す（未保存なら `null`） |
| `RuleStore.write(s)` | `s` を「現在のルール」として保存する（以後の `read()` は最後に書いた値を返す） |
| `loadLastRule(store)` | `read()` → `deserializeRule`。`read()` が `null`、または `deserializeRule` が `null` なら**空 `RenameRule`** |
| `saveCurrentRule(store, rule)` | `serializeRule(rule)` を `write`。保存失敗は致命的でない（best-effort） |

### 要件

| ID | 優先度 | 要件（外部から観測可能な文で） | 検証 |
|---|---|---|---|
| REQ-001 | must | 全 Token 種別（元名/リテラル/連番/日時）と `RenameRule` について、`deserializeRule(serializeRule(rule))` は元の `rule` と等価（トークン種別と全パラメータが一致）。 | VER-001 |
| REQ-002 | must | シリアライズ結果は各トークンを安定した `type` タグ + そのパラメータで表す（元名=パラメータなし / リテラル=value / 連番=start,digits,increment / 日時=source,format）。 | VER-001 |
| REQ-003 | must | シリアライズ結果はスキーマのバージョンを含む。 | VER-001 |
| REQ-004 | must | `deserializeRule` は、不正な JSON・未知の `type`・必須フィールド欠損・非対応バージョンに対して `null` を返す（例外を投げない）。 | VER-001 |
| REQ-005 | must | `RuleStore`: `write(s)` の後の `read()` は最後に書いた `s` を返す。一度も書いていなければ `read()` は `null`。 | VER-002 |
| REQ-006 | must | `loadLastRule`: 保存が無い・壊れている場合は空 `RenameRule` を返し、正当な保存があればそれを復元する。 | VER-002 |
| REQ-007 | must | `saveCurrentRule` は `serializeRule(rule)` を `write` する。空ルールも保存対象（復元して空で始まる）。 | VER-002 |
| REQ-008 | should | 配線: 起動時に `loadLastRule` の結果で `RuleController` を初期化し、`RuleController` の変更で `saveCurrentRule` する。復元失敗時は空ルールで開始。 | VER-003 |

### 代表例

`type` タグ名・バージョン欄の具体形は open_questions（[ASSUMED] を採用）。

| # | 入力 | 期待 |
|---|---|---|
| 1 | rule=[元名, リテラル'_', 連番(start1,digits2)] を serialize→deserialize | 同一種別・同一パラメータの rule |
| 2 | rule=[日時(created,'YYYYMMDD')] を round-trip | source=created, format='YYYYMMDD' が保存・復元 |
| 3 | deserializeRule("{壊れたJSON") | null |
| 4 | deserializeRule(未知 type を含む JSON) | null |
| 5 | 空ストアで loadLastRule | 空 RenameRule |
| 6 | saveCurrentRule(store, r) 後 loadLastRule(store) | r と等価 |
| 7 | 空ルールを save→load | 空 RenameRule（例外なし） |

## 自由とする点（実装に委ねる）

- JSON の内部表現の詳細（キーの並び順・空白・使用ライブラリ `dart:convert` 等）。往復と REQ-002/003 を満たせば自由。
- `RuleStore` の具体実装（`shared_preferences`・ファイル・メモリ）とキー名。契約（REQ-005）を満たせば自由。
- 保存の粒度（変更のたび / デバウンス）。REQ-007 の「最後の状態が保存される」を満たせば自由。
- オーケストレーションの内部構造（コーディネータのクラス形・購読解除の方法）。

## 対象外・未定義とする点

- ストレージの同時書き込み・並行性（単一ユーザー・単一プロセス前提）。
- `RuleStore.write` の IO 例外時の挙動は best-effort（アプリは継続。復元は次回 `loadLastRule` のフォールバックで空になりうる）。
- スキーマの移行（旧バージョン → 新バージョンの変換）。現状はバージョン不一致を `null`（空フォールバック）とし、移行は将来。

## 検証

| ID | 種別 | 成果物パス | 対象 |
|---|---|---|---|
| VER-001 | unit | test/spec_007_rule_persistence/serialization_test.dart | REQ-001, REQ-002, REQ-003, REQ-004 |
| VER-002 | unit | test/spec_007_rule_persistence/persistence_test.dart | REQ-005, REQ-006, REQ-007 |
| VER-003 | unit | test/spec_007_rule_persistence/wiring_test.dart | REQ-008 |

- 上表の「対象」は照合用の ID 列のみ。観点の説明は各テストファイル冒頭のコメントに置く。

## 反証ログ

| 観点 | 結果 |
|---|---|
| 仕様を見ずに書いた例との照合 | 代表例7件を操作と照合。round-trip（例1,2,6）・異常系（例3,4）・空（例5,7）を網羅。 |
| 弱すぎ（ズルい実装） | REQ-001 を「全種別で全パラメータ一致の等価」と接続し、常に空ルールを返す/定数を返す実装を排除。REQ-005 に「最後に書いた値」を明記し、read が常に null を返す実装を排除。 |
| 強すぎ（過剰な条件） | JSON の内部表現・ライブラリ・ストア実装・保存粒度を「自由とする点」で明示解放。type タグ名・バージョン形は open_questions に送り固定しすぎない。 |
| 異常系の網羅 | 不正JSON・未知 type・欠損・非対応バージョン → null（REQ-004）。空ストア・空ルール・保存失敗（best-effort）を明記。 |
| 判定不能語 | 「適切に」等を排し、往復等価・「最後に書いた値」等の観測可能条件で記述。 |

## 決定済み事項（旧・未解決事項。2026-08-02 に開発者承認で確定）

- JSON スキーマ: トップレベル `{"version": 1, "tokens": [...]}`。各トークンは `type` タグ + パラメータ。**type タグ名は一目で分かる語に確定（開発者指示）**:
  - 元名: `{"type":"original_name"}`
  - 自由テキスト/区切り（同一実体 `LiteralToken`）: `{"type":"text","value":"_"}`
  - 連番: `{"type":"sequence_number","start":1,"digits":2,"increment":1}`
  - 日時: `{"type":"datetime","source":"created","format":"YYYYMMDD"}`（source は `created`/`modified`/`current`）
- 保存の粒度: 変更のたび保存（単純・確実）。デバウンスは将来の最適化。
- 読み込み失敗時: 空ルールで開始（確定・低リスク）。
- 空ルールの保存: 保存する（空も有効状態として復元）。
- 非対応バージョン: `null`（空フォールバック）。移行は将来。
