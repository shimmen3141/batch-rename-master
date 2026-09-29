# T02 コアでゼロ埋めなしの連番を評価し、桁不足と桁拡張をゼロ埋めの連番だけに限る

## 目的

001の命名エンジンで、ゼロ埋めなしの連番が数字そのままを出し、桁不足の警告(REQ-008)と桁の自動拡張(REQ-011)がゼロ埋めの連番だけに働く。

## 入力と依存

- T01で承認された001のspec・contract。

## 変更範囲

- `lib/core/token.dart`(`SequenceToken`)、`lib/core/rename_engine.dart`(`validate`・`autoResolve`)と、その001のtest。
- 既定値は今と同じ振る舞い(ゼロ埋めあり)。既存のruleの名前を変えない。
- UI・保存は変えない(T03・T04)。

## 受け入れ条件

- [ ] ゼロ埋めなしの連番が数字そのままを出し、桁不足を返さず、自動解決で桁を広げない。ゼロ埋めの連番は今と同じ。
  - 証拠: `flutter test test/spec_001_rename_core`、full `flutter test`、`flutter analyze`、`dart format`、`tool/mutations.json`への追加とその生出力。
- [ ] ゼロ埋めありとなしの連番が混在するルールで、行の桁不足の対象がゼロ埋めありの連番の超過分だけになる(002 代表例19c)。
  - 証拠: `test/spec_002_file_list`のtest(行データの導出。今の実装は警告が指す連番ごとに導出するので、testで固定する)。
- [ ] 独立reviewがPASS(strict)。

## 作業記録

実装は Claude Opus 5.5(2026-09-29)。branch `asdd/014-sequence-zero-padding/T02-core-unpadded-sequence`、起点`dev`@`4a2047c`、code `91a5386`。

- 先にtestを書いた: 001 例19〜23(`token_evaluation_test`・`validation_test`・`auto_resolve_test`)、混在(ゼロ埋めありの連番だけが警告される / 拡張しても混在の設定を保つ)、002 例19c(`preview_rows_test`)。`zeroPad`の項目だけ足した状態(振る舞いは従来)で**7件がFAIL**(例20・23は従来の実装でも成り立つ組み合わせ)。
- `lib/core/token.dart`: `SequenceToken.zeroPad`(既定`true`)。偽なら`valueAt(position).toString()`。
- `lib/core/rename_engine.dart`: `validate`の桁不足はゼロ埋めありの連番だけ。`_expandDigits`はゼロ埋めなしをそのまま返す。
- `lib/ui/file_list/row_view.dart`: `sequenceOverflowsAt`のコメントだけ(ここへ来るのはゼロ埋めありの連番)。行の導出(`file_list_controller.dart`)は変えていない — 警告が指す連番ごとに導出しており、例19cで固定した。
- 検証: `flutter test` 1026件PASS、`flutter analyze`・`dart format` PASS。
- **T03までの間の残余**: `rule_serialization.dart`はまだ`zeroPad`を保存しない(偽は保存・復元で真に戻る)。ゼロ埋めなしを作るUIは`T04`まで無いので、利用者の経路では起きない。`T03`が閉じる。

### mutation

`M486`〜`M490`を足した。`command`を`flutter test test/spec_001_rename_core test/spec_002_file_list/preview_rows_test.dart`へ絞った5件の生出力(NOTEは省いた):

```text
M486 | KILLED | lib/core/token.dart | exit 1
M487 | KILLED | lib/core/rename_engine.dart | exit 1
M488 | KILLED | lib/core/rename_engine.dart | exit 1
M489 | KILLED | lib/core/token.dart | exit 1
M490 | KILLED | lib/ui/file_list/file_list_controller.dart | exit 1
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

## 独立review

既定のreviewerは`gpt-6-luna`(開発者指定)。001 contractの判定に触れるので実装と同等以上のmodelを使う。

- attempt 1: `4a2047c..4e28318`(全範囲、implementation) — **FAIL**(成果物の欠陥なし。P0/P1 none)。reviewerのmodelは`gpt-6-luna`。**安全網の穴(P2、reviewerはFAIL条件を満たすと判定)**: `_expandDigits`が作り直すときに増分を保つことをtestが固定していない(対照`RV-T02-1`: `increment: 1`へ落としてもSURVIVED)。確認された点: contractどおりの実装、`_expandDigits`は`start`・`increment`を渡す、行の導出は警告の連番ごと、保存の欠落をT03へ送る扱いは妥当(ゼロ埋めなしを作る経路はT04まで無い)。UIのラベル(`token_presets.dart:40`・`rename_warning_view.dart:398`)は`digits`を無条件に出すので**T04で追随が要る**(T04の範囲)。full test 1026件・format・analyze・`check specs` PASS。
  - 対応: `auto_resolve_test`へ「拡張しても開始番号と増分を保つ(桁2・開始90・増分5 → 090, 095, 100)」を足し、`RV-T02-1`を`M491`として取り込んだ。範囲付き(`flutter test test/spec_001_rename_core`)の生出力:

```text
M488 | KILLED | lib/core/rename_engine.dart | exit 1
M491 | KILLED | lib/core/rename_engine.dart | exit 1
2 mutations: 2 KILLED, 0 SURVIVED, 0 SKIPPED
```

  - full `flutter test` 1027件PASS。

- attempt 2: `4e28318..98ee48d`(差分、implementation) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。前回の安全網の穴は閉じた(足したtestの数値、`M491`が`RV-T02-1`と同じ回帰を表しKILLED)。T04へ渡したUIラベルの追随の記述は事実と一致。full test 1027件・format・analyze・`check specs`・`git diff --check` PASS。reviewerの対照`RV-T02-2-control`(拡張時に開始番号を1ずらす。KILLED)を`M492`として取り込んだ。
  - 連鎖: `4a2047c..4e28318` FAIL(安全網の穴) → `4e28318..98ee48d` PASS(指摘が閉じたことを確認) → 以後は`tool/mutations.json`へreviewerの定義を足した差分と記録だけ(SELF-CHECK。再reviewは起動しない)。

## Current state / handoff

- Last checkpoint: PR #196をmerge commitで`dev`へmerge(2026-09-29、`01f1884`)。merge条件1〜7を確認した: Draftでない・一意 / 独立reviewの連鎖(`4a2047c..4e28318` FAIL → `4e28318..98ee48d` PASS → 以後はreviewerの対照の取り込みと記録のSELF-CHECK) / CI `check` PASS・未解決threadなし / baseは`4a2047c`で最新・競合なし、full test 1027件PASS / manual確認はこのtaskに無い / 未解決P0/P1なし / `.github/workflows`・AGENTS.md・sandbox境界の変更なし。
- Blocker category: none
- Evidence revision: 起点`dev`@`4a2047c`、merge `01f1884`。
- Next Agent action: なし(done)。続きは`014:T03`・`014:T04`(並行できる)。
