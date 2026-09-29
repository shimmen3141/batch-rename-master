# T03 ゼロ埋めの有無を保存・復元し、項目の無い既存の保存をゼロ埋めありとして読む

## 目的

ゼロ埋めなしのルールが再起動後も復元され、**このplanより前に保存されたルールが今と同じ名前をつけるまま復元される**(利用者のルールを失わない)。

## 入力と依存

- T01で承認された007のspec。T02の`SequenceToken`。

## 変更範囲

- `lib/core/rule_serialization.dart`と007のtest。
- 保存の版の扱いはT01の決定に従う(版を上げると既存の保存が復元されなくなるので、上げる場合は移行を伴う)。

## 受け入れ条件

- [ ] ゼロ埋めあり・なしの両方が往復する。ゼロ埋めの項目を持たない保存(このplanより前の形)をゼロ埋めありとして読む。
  - 証拠: `flutter test test/spec_007_rule_persistence`(旧い形のJSONをfixtureとして置く)、full test・analyze・format、mutation。
- [ ] 独立reviewがPASS(互換に触れるので実装と同等以上のmodel)。

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: none
- Evidence revision: none
- Next Agent action: T02のmerge後、旧い形の保存をfixtureにした失敗するtestから書く
