# Development finding: manual手順のPowerShell変数が2回続けて失敗した

- 観測日: 2026-08-12
- 観測した作業: `005:T09`と`005:T07`のmanual verification(いずれも開発者がWindowsで実施)
- 改善先: projectのmanual手順、およびASDD plugin(`manual-verification.md`のdry-run節)
- 関連artifact: `specs/005-rename-exec/tasks/T09-empty-rule-ui/manual-verification.md`、`specs/005-rename-exec/tasks/T07-desktop-modified-time/manual-verification.md`、`specs/004-file-source/tasks/T10-verify-target-platforms/manual-verification.md`、`specs/005-rename-exec/tasks/T05-platform-rename-adapters/manual-verification.md`

## 観測した事実

同じ失敗が2回起きた。

1. `005:T09`(2026-08-12): 手順が `$emptyRuleFixture` を先頭のblockで定義し、後続blockで使っていた。実施者の環境で `Get-ChildItem : 引数が null であるため、パラメーター 'LiteralPath' にバインドできません。` が出た。→ **「同じwindowで続けて実行してください」という注意書きを追加**して対処した。
2. `005:T07`(同日): `$dir` と `$target` で同じ構造を書き、**同じerrorが再発**。実施者は「ほとんど失敗しました(これは以前も発生した)」と報告し、コマンドを諦めてエクスプローラーで直接folderを見て確認した。

1回目の対処(注意書き)は効かなかった。手順書は上から順に1つのwindowで実行される、という前提が現実と合っていない。実施者はIDEやエディタからblock単位でコピーし、windowを開き直したり順番を前後させたりする。**注意書きは、その運用を変えることを実施者へ要求している**。

同じ構造は`004:T10`(`$a`/`$b`/`$adb`)と`005:T05`(`$fixturePath`)にも残っており、次に実行する人が同じ所で詰まる。

## 期待していた動きと実際の動き

- 期待: 手順のコマンドをコピーすれば動く。
- 実際: 前のblockの変数に依存するため、単独では動かない。しかも失敗が `null` へのbindという分かりにくいerrorになる。

## 影響とworkaround

- 影響: `005:T07`の手順4(更新日時の更新だけが失敗しても改名は成功する。REQ-016の実機確認)が**実施できなかった**。受け入れの一部が取れていない。
- 影響: 実施者が本来不要な回避(folderを直接見る、コマンドを読み替える)を強いられる。確認の信頼性も下がる。
- 影響: 1回目の対処が効かなかったため、2回分の実施時間を消費した。
- workaround: 実施者はエクスプローラーで直接確認した。順序の確認だけは成立したが、失敗系(手順4)は成立しなかった。

## 根本原因と、否定された仮定

**否定された仮定**: 「手順書は上から順に、1つのshell sessionで実行される」。実際には**blockごとに独立して実行されうる**。

注意書きで補うのは、Agentが自分の前提を実施者へ押し付けることになる。手順の側を、**どのblockも単独で動く**ように書けばよい。

AGENTS.mdは「同じ根本原因が修正後も2回続いたら類似修正を止めて仮定を洗い直す」と定めている。これに該当したため、注意書きの追加(類似修正)をやめ、構造を変えた。

## 仮説と提案

- **manual手順のshell blockでは変数を使わない。** pathは毎回literalで書く。冗長になるが、どのblockも単独で動く。
- 併せて、**各stepの先頭でfixtureを作り直す**。`005:T07`では改名を重ねて `a_m_n_o.txt` のように名前が伸び、後半のstepが前提と合わなくなっていた(実施者が指摘)。step間の状態依存も、変数依存と同じく「上から順に完走する」前提に立っている。
- skillの「依頼前のdry-run」へ、**「各shell blockが単独で実行できるか」**を確認項目として加える。現在の条文(記載した文言・path・commandがcurrent revisionに存在する)は、存在の確認であって実行可能性の確認ではない。
- 一般化: 人間向け手順では、**実施者の実行方法を仮定しない**。1つのwindowで完走することも、順番どおり進むことも、前のstepの成果が残っていることも仮定しない。

## 改善結果

`005:T07`の手順を書き直した。変数を全廃してliteral pathにし、各stepの先頭でfixtureを作り直す形にした。更新日時は秒まで出ないという指摘も受け、`ToString('yyyy-MM-dd HH:mm:ss')`で整形するか、エクスプローラーの「更新日時」列でソートした並び順で判断する、と明記した。

`004:T10`と`005:T05`の手順にも同じ構造が残っている。どちらも実施済みのtaskなのでこのbranchでは変更しないが、**再実行するときは先に変数を除く必要がある**。ASDD pluginのdry-run条文への追加は未対応。
