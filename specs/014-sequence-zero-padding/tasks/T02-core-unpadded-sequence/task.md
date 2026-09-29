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

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: none
- Evidence revision: none
- Next Agent action: T01の承認後、承認されたREQに対応する失敗するtestから書く
