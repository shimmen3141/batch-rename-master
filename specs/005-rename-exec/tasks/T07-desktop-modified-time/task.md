# T07 desktopの更新日時ずらしを実装する

## 目的

desktopでだけ表示される既定OFFの設定により、rename成功後の更新日時を表示順にずらし、副次処理失敗でもrename成功を維持する。

## 入力と依存

- `T05`のdesktop adapter統合。
- 005 REQ-014〜016、VER-006。
- Issue #98。

## 変更範囲

- desktop限定option、表示順に対応するmtime更新、失敗結果の分離、仕様由来testとmanual確認。
- Androidでのmtime更新は対象外。

## 受け入れ証拠

- option既定OFF、ON時の順序、mtime失敗時もrename成功維持を自動testで検査する。
- [`manual-verification.md`](manual-verification.md)で実filesystemのmtimeとUIを確認する。

## 作業記録

- 旧005 T07とASDD 1.x work packageから未着手成果として移行。Issue #98はT05統合待ち。

- 2026-08-12 / manual checklistを点検した。004/007と違い、**移行での欠落は無かった**(凍結0.x planのT7受け入れ条件3件のうち、既定OFF/表示順と「ずらし失敗でもrename成功」は受け入れ証拠へ、「Androidでは設定自体を提示しない」は変更範囲へ移っている。受け入れ証拠側には無いが失われてはいない)。stubだったのは実装前だからで、UIが未確定のまま手順を書くと実画面と食い違うため、`manual-verification.md`には実装時にchecklistへ落とす観点6件(既定OFF、Android非提示、表示順、filesystem解像度、副次失敗でrename維持、失敗の見分け)を残し、実行手順は実装時に書くことを明記した。あわせてskillの規定に反していた返信templateとstatus欄を外した。

- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — 残るP0/P1: none(このtaskへの指摘はP2-2内部用語とP2-7 findingの粒度。前者は`fb6f7d7`で一部、残りをこの修正で解消)
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — 残るP0/P1: none(P2-a `manual-verification.md`に内部用語が残存、P2-b このattempt行の欠落。いずれもこの修正で解消)
- Review attempt 3: PR #121 `dev@abc8007...6432da8` — FAIL — 残るP0/P1: none(このtaskへの指摘なし。P2-a/P2-b/P2-7は解消を確認)

- Review attempt 4: PR #121 `dev@abc8007...3255f87` — PASS — 残るP0/P1: none(このtaskへの指摘なし)

- 2026-08-12 / **manual verification 1回目 / 一部のみ確認**。開発者がbranch headのWindows desktop buildとAndroid buildで実施。
  - **確認できた**: 設定が既定OFFでOFFのままなら更新日時が変わらない(手順1)。ONにすると一覧の並び順に更新日時がずれる(手順2)。Androidでは設定そのものが出ない(REQ-015)。
  - 更新日時は秒まで表示されなかったため、値の比較ではなく**更新日時順に並べ替えても順番が変わらない**ことで順序を確認した。REQ-014の観測としては成立している。
  - **確認できなかった**: 手順3(並び替えへの追随)と手順4(更新日時だけ失敗しても改名は成功)。
  - 手順3の原因は手順書の不備。ドラッグの取っ手は連番トークンがあるときだけ出る(002 REQ-014)のに、その理由を書かずに「取っ手が出ない場合は連番を足してください」とだけ書いたため、実施者に「連番で順序が変わるわけではない」と受け取られた。あわせて、改名を重ねると`a_m_n_o.txt`のように名前が伸びる点を手順が考慮していなかった。
  - 手順4の原因はPowerShellの変数依存。`$dir`が別windowでは残らず`LiteralPath`にnullがbindされて失敗した。**005:T09で同じ失敗があり注意書きで対処したが、再発した**(`development-findings/2026-08-12-powershell-variables-break-manual-steps.md`)。
- 2026-08-12 / 手順を書き直した。変数を全廃してliteral pathにし、各stepの先頭でfixtureを作り直す形にした。ドラッグの取っ手が連番に依存する理由も明記した。**手順3と手順4の再実施が要る。**

## Current state / handoff

- Last checkpoint: 実装と仕様由来testは通っている。manualは手順1・2・AndroidがPASS、手順3・4は手順書の不備で未実施
- Blocker category: manual
- Waiting for: 書き直した[`manual-verification.md`](manual-verification.md)の**手順3(並び替えへの追随)と手順4(更新日時だけ失敗しても改名は成功)**の実施
- Requested action: 人間が手順3と手順4だけを実施し、結果を会話で返す(手順1・2・Androidは再実施不要。code差分が無いため前回の結果を再利用できる)
- Evidence revision: branch `asdd/005-rename-exec/T07-desktop-modified-time`。手順書の書き直し以後、`lib/`と`test/`の差分はゼロ
- Evidence: `flutter test`=PASS(354、うち`modified_time_test.dart` 8件)、`flutter analyze`=PASS(0)、`dart format`=PASS(76 files / 0 changed)。manual=**部分的**(手順1・2・AndroidのみPASS)
- Next Agent action: 手順3・4の結果を受け取って記録し、揃ったら独立reviewへ回す
