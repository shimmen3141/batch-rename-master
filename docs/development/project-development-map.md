# プロジェクト開発マップ

## この文書の役割

この文書は、旧ASDD 0.xが`specs/discovery.md`と各`plan.md`に持っていたプロジェクト全体像を、ASDD 1.0から参照できる形へ移した**移行カバレッジ**である。liveな進捗台帳ではない。

- 仕様の正本は、表から参照する既存`spec.md`、contract、ADR、test、またはdevelopment unitに置く。
- 作業中のstatus、担当、branch、review対象、外部待ちはGitHub Issueに置く。
- 旧`plan.md`のcheckbox、task status、claim、log、Issue番号はcutoff後の状態判定に使わない。
- 将来候補のIssueは先に一括作成しない。候補をdevelopment unitへ定義し、共有調整を開始するときだけ作成または再利用する。
- この文書を更新するのは、能力・候補・依存・対象外の分類が変わったときだけである。日々の進捗では更新しない。

## 0.xからの移行カバレッジ

Cutoffは`8d950ca173e2d0f22a6dad1432dd2b2e285cd2ec`。次の表で、旧全体像の各項目を新ASDDから辿れる対象へ一度だけ対応付ける。

| 旧領域・候補 | 移行後の分類 | 新ASDDから読む正本・入口 | 補足 |
|---|---|---|---|
| 001 コア命名エンジン | 既存能力 | `specs/001-rename-core/spec.md`、`contracts/`、`decisions/`、`test/spec_001_rename_core/` | 旧taskは全件実装済み。現在の適合性は旧checkboxでなくtestで判定する |
| 002 ファイル一覧・選択・ソート・preview | 既存能力 | `specs/002-file-list/spec.md`、`test/spec_002_file_list/` | 視覚デザインは既存仕様の対象外。UI整合候補へ接続する |
| 003 ルール構築UI | 既存能力 | `specs/003-rule-builder/spec.md`、`test/spec_003_rule_builder/` | token追加時のinteraction変更はUI整合候補で仕様更新して扱う |
| 004 ファイル読み込み | 実装済み・target platform受け入れ未完 | `specs/004-file-source/spec.md`、ADR、test、`development-units/verify-file-selection-on-target-platforms/` | 旧task statusはdoneだが、旧plan全体のAndroid/Windows手動証拠が未完だったため独立unitへ移した |
| 005 リネーム実行 | 実行中unit | `development-units/complete-rename-execution/`と`specs/005-rename-exec/` | live statusは対応するGitHub Issueだけを見る |
| 006 Windows Explorer D&D | 将来候補 | 下記「将来候補」 | 002の追加経路。着手時にdefinitionを作る |
| 007 前回ルール復元 | 実装済み・再起動受け入れ未完 | `specs/007-rule-persistence/spec.md`、test、`development-units/verify-rule-persistence-across-restart/` | 自動testはあるがprocess deathをまたぐ実ストア証拠が未完だった |
| 008 UI仕上げ | 将来候補 | 下記「UIと主要操作の整合」 | 005完了後に参考デザイン・旧実装・現実装を比較してdefinitionを作る |
| 009 名前付きルールpreset | 将来候補 | 下記「ルールpreset」 | 007のserializationを再利用する |
| 010 写真・動画source | 将来候補 | 下記「写真・動画source」 | 004の選択境界・handleの上に構築する |
| 011 保存schema移行 | 条件付き将来候補 | 下記「保存schema移行」 | 名前付きpresetで利用者資産を持つ前に要否を判断する |
| 012 隠し・system file filter | 条件付き将来候補 | 下記「隠しfile filter」 | platformごとに信頼できる識別手段が得られた場合だけ定義する |
| 元名tokenの大文字・小文字変換 | 将来候補 | 下記「元名のcase変換」 | 001 Strict contractの意味変更と人間承認が必要 |
| 永続的な多世代undo、cloud同期、正規表現置換、再帰探索 | 対象外 | 本文末尾の「対象外」 | 要求が変わったらdiscover-requirementsから始める |

この表により、旧`discovery.md`と全6個の旧`plan.md`に存在した実装済み能力、未完了受け入れ、実行中作業、将来候補、対象外をすべて分類している。旧資料は由来と判断履歴として残すが、上の分類に無いlive taskを旧資料から直接開始しない。

## 現在定義済みのdevelopment unit

| development unit | 観測可能な成果 | blocking dependency |
|---|---|---|
| `complete-rename-execution` | Android/desktopで安全な実rename、結果、undo、desktop更新日時ずらしまで成立する | 既存001〜004能力 |
| `verify-file-selection-on-target-platforms` | 既存004の選択・置換・cancel・warningがAndroid/desktopで成立した証拠を得る | 既存004実装。別unitのcode変更には依存しない |
| `verify-rule-persistence-across-restart` | 既存007の保存値がprocess終了後もAndroid/desktopで復元される証拠を得る | 既存007実装。別unitのcode変更には依存しない |

`complete-rename-execution`が現在の共有作業である。ほか2件は旧受け入れ条件から漏れていた検証負債であり、同じエミュレータ確認sessionで証拠を取ってよいが、各unitのPASSは別々に判定する。

## 将来候補と依存

候補は優先順位の確定や着手claimを表さない。依存を満たす候補が複数ある場合、Agentが製品優先度を推測せず、人間へ一問で選択を求める。

| 候補 | 目的・保持する決定 | 前提 |
|---|---|---|
| UIと主要操作の整合 | `docs/design/Bulk Renamer.html`、以前の実装、現実装を比較し、表示形式、情報階層、rename操作の位置、sort操作、token追加modal、選択と削除を整える | `complete-rename-execution`完了後。renameボタンの期待配置は人間が決める |
| Windows Explorer D&D | Explorerからfileを一覧へ追加する | 002と004の境界を維持し、Windows host証拠を定義する |
| 写真・動画source | MediaStoreの全件/album選択と撮影日時を提供する | 004完了。001/002の日時意味を変更する場合は仕様承認 |
| ルールpreset | 名前付きruleを複数保存・選択する | 007のserialization。保存schema移行の要否を先に決める |
| 保存schema移行 | 保存済みruleをschema変更後も失わず変換する | preset等で利用者資産が増える前に必要性を判断する |
| 隠しfile filter | 判別可能なplatformだけで隠し/system fileを除外できるようにする | 信頼できるplatform APIとfallback方針が必要 |
| 元名のcase変換 | 元名tokenへkeep/upper/lowerを追加する | 001 Strict contract更新、実行可能な検証、人間承認 |

主な依存関係は次のとおり。

```text
rename core ─┬─> file list ─┬─> file source ─┬─> rename execution ─> UI整合
             └─> rule UI ───┘                 ├─> Windows D&D
                                              ├─> 写真・動画source
                                              └─> 隠しfile filter

rule UI ─> 前回ルール復元 ─> 保存schema判断 ─> ルールpreset
```

## 「続けて」での選択規則

1. current branch、diff、open PR、live Issueに対応するdevelopment unitが一意なら、そのunitの次checkpointを進める。
2. current unitが無く、定義済みの未完unitが一つならそれを提示して進める。複数なら依存と必要な人間証拠を示し、一問だけ選択を求める。
3. 定義済みunitが無ければ、上の将来候補から依存を満たす候補を提示する。選ばれた候補だけを`define-development-unit`で具体化する。
4. Issueは共有調整を開始するときだけ作成または再利用する。候補一覧の複製としてIssueを一括作成しない。
5. 旧`plan.md`のpending/doneやIssue番号から作業を再開しない。

## 対象外

- cloud同期
- sessionをまたぐ永続的な多世代undo履歴
- 正規表現置換
- subfolderを横断する再帰探索

これらを再検討するときは、既存候補へ直接追加せず`discover-requirements`で利用者・問題・境界を確認する。
