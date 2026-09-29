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

## 作業記録

実装は Claude Opus 5.5(2026-09-29)。branch `asdd/014-sequence-zero-padding/T03-persist-zero-padding`、起点`dev`@`a2456dc`、code `73ff418`。

- 先にtestを書いた(`test/spec_007_rule_persistence/serialization_test.dart`): 例8(ゼロ埋めなしの往復)、スキーマに`zero_padding: true`が入る、例10(真偽値でない`"no"`・`0`・`null`は`null`)、**014より前の形のJSONをfixtureにした**例9(復元でき、連番はゼロ埋めあり、`IMG.jpg`の3番目が`IMG_03.jpg`)と、書き直すと`zero_padding`を含み版は1のまま。実装前は**4件がFAIL**(例9の2件は従来の実装でも成り立つ互換の守り)。
- `lib/core/rule_serialization.dart`: 書くときは`zero_padding`を常に書く。読むときは無ければ`true`、あって真偽値でなければ`null`。版は`1`のまま(T01の決定)。
- 検証: `flutter test` 1032件PASS、`flutter analyze`・`dart format` PASS。
- これで`014:T02`が残していた「ゼロ埋めなしは保存・復元で真に戻る」は閉じた。

### mutation

`M493`〜`M496`を足した。`command`を`flutter test test/spec_007_rule_persistence`へ絞った4件の生出力(NOTEは省いた):

```text
M493 | KILLED | lib/core/rule_serialization.dart | exit 1
M494 | KILLED | lib/core/rule_serialization.dart | exit 1
M495 | KILLED | lib/core/rule_serialization.dart | exit 1
M496 | KILLED | lib/core/rule_serialization.dart | exit 1
4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED
```

## 独立review

既定のreviewerは`gpt-6-luna`(開発者指定)。保存の互換に触れるので実装と同等以上のmodelを使う。

- attempt 1: `a2456dc..27d2ed7`(全範囲、implementation) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。specどおり(常に書く / 無ければゼロ埋めあり / 真偽値でなければ`null` / 版は1)、旧い形のfixtureが名前(`IMG_03.jpg`)と書き直しまで確認していること、起動時の復元経路(`main` → `PersistentRuleController.restore` → `loadLastRule` → `deserializeRule`)に他の影響が無いことを確認された。full test 1032件・format・analyze・`check specs`・`git diff --check` PASS、範囲付きmutation`M493`〜`M496`全KILLED。
  - 以後は記録だけ(SELF-CHECK)。

## Current state / handoff

- Last checkpoint: PR #197をmerge commitで`dev`へmerge(2026-09-29、`491c52e`)。merge条件1〜7を確認した: Draftでない・一意 / 独立review `a2456dc..27d2ed7` PASS → 以後は記録だけ(SELF-CHECK) / CI `check` PASS・未解決threadなし / baseは`a2456dc`で最新・競合なし、full test 1032件PASS / manual確認はこのtaskに無い / 未解決P0/P1なし / `.github/workflows`・AGENTS.md・sandbox境界の変更なし。
- Blocker category: none
- Evidence revision: 起点`dev`@`a2456dc`、merge `491c52e`。
- Next Agent action: なし(done)。続きは`014:T04`。
