# T52 件数が増えたとき連番の桁数を自動で引き上げて通知する

## 目的

`T51` で定義した振る舞い(ゼロ埋めありの連番の桁数が下限を下回ったら、ルールを下限まで引き上げてトーストで知らせる)を実装する。

## 範囲(`T51` の承認後に詰める)

- composition root(一覧の件数を知る側)で件数とルールを見て、下限を下回る連番の桁数を引き上げる。`RuleController` 経由で変えるので、前回ルールとして保存される(007)。
- 引き上げたことをトースト(`008:T25` の閉じられる通知)で知らせる。
- 件数が減っても下げない。

## 受け入れ証拠

- widget test(003 の代表例15〜15d: 件数が増えて引き上がる・通知が出る・減っても下がらない・ゼロ埋めなしは触らない・復元して起動しても引き上がる・**連番が複数なら下限を下回るものだけ引き上がる**・保存される(007 REQ-008 の経路))。mutation。
- `flutter test`・`flutter analyze`・`dart format`。独立review。
- `manual-verification.md` で Android 実機と Windows desktop を確認する。

## Current state / handoff

- Last checkpoint: 登録しただけ(2026-10-01)
- Blocker category: none
- Evidence revision: none
- Next Agent action: `T51` の承認を待ってから着手する
