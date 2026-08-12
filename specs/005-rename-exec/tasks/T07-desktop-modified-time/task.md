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

- 以下のattempt 1〜4は、**PR #121(manual checklist復元のdocs PR)に対するreview**であり、このtaskの実装に対するものではない。指摘内容も内部用語やfindingの粒度で、実装とは無関係。
- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — 残るP0/P1: none(このtaskへの指摘はP2-2内部用語とP2-7 findingの粒度。前者は`fb6f7d7`で一部、残りをこの修正で解消)
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — 残るP0/P1: none(P2-a `manual-verification.md`に内部用語が残存、P2-b このattempt行の欠落。いずれもこの修正で解消)
- Review attempt 3: PR #121 `dev@abc8007...6432da8` — FAIL — 残るP0/P1: none(このtaskへの指摘なし。P2-a/P2-b/P2-7は解消を確認)

- Review attempt 4: PR #121 `dev@abc8007...3255f87` — PASS — 残るP0/P1: none(このtaskへの指摘なし)
- **実装に対するreviewはここから。**
- Review attempt 5(実装 1回目): `dev@b7f1e1b...1bf73e9` — FAIL — P1: VER-006がREQ-014の核心(実行計画順ではなく表示順)を判別できず、testのコメントが判別すると偽って主張していた

- 2026-08-12 / **manual verification 1回目 / 一部のみ確認**。開発者がbranch headのWindows desktop buildとAndroid buildで実施。
  - **確認できた**: 設定が既定OFFでOFFのままなら更新日時が変わらない(手順1)。ONにすると一覧の並び順に更新日時がずれる(手順2)。Androidでは設定そのものが出ない(REQ-015)。
  - 更新日時は秒まで表示されなかったため、値の比較ではなく**更新日時順に並べ替えても順番が変わらない**ことで順序を確認した。REQ-014の観測としては成立している。
  - **確認できなかった**: 手順3(並び替えへの追随)と手順4(更新日時だけ失敗しても改名は成功)。
  - 手順3の原因は手順書の不備。ドラッグの取っ手は連番トークンがあるときだけ出る(002 REQ-014)のに、その理由を書かずに「取っ手が出ない場合は連番を足してください」とだけ書いたため、実施者に「連番で順序が変わるわけではない」と受け取られた。あわせて、改名を重ねると`a_m_n_o.txt`のように名前が伸びる点を手順が考慮していなかった。
  - 手順4の原因はPowerShellの変数依存。`$dir`が別windowでは残らず`LiteralPath`にnullがbindされて失敗した。**005:T09で同じ失敗があり注意書きで対処したが、再発した**(`development-findings/2026-08-12-powershell-variables-break-manual-steps.md`)。
- 2026-08-12 / 手順を書き直した。変数を全廃してliteral pathにし、各stepの先頭でfixtureを作り直す形にした。ドラッグの取っ手が連番に依存する理由も明記した。**手順3と手順4の再実施が要る。**

- 2026-08-12 / **manual verification 2回目 / 残りの手順3・4もPASS**。書き直した手順で開発者が実施し、全項目を確認した。
  - 手順3(並び替えへの追随): 画面で c, b, a に入れ替えた順で更新日時がずれることを確認。REQ-014の「実行計画ではなく表示順」が実機で観測できた。
  - 手順4(更新日時だけ失敗しても改名は成功): 「**改名は成功しましたが、1 件の更新日時は変更できませんでした**」が表示され、改名の失敗としては出ないことを確認。REQ-016の実機受け入れが取れた。
  - あわせて1回目の手順1・2・Android(REQ-015)がPASS済みで、code差分が無いため再利用できる。これでREQ-014 / REQ-015 / REQ-016の実機確認がすべて揃った。
  - 変数依存が再発した原因も判明した(開発者の報告): 手順を上から実行すると`$dir`を定義したterminalでemulatorを起動することになり、起動したまま確認するには**必然的に別のterminalを使うことになる**。「同じwindowで実行」という前提自体が、この手順では成立しない。

- 2026-08-12 / 実装に対する独立review(attempt 5)がFAIL。**P1はtestの判別力**だった。REQ-014は「実行計画ではなく表示順」と書いて特定の誤実装を排除しているが、置いたtestの入力はどれも目標名が既存名と衝突せず、`planExecution`が並べ替えないため**実行順=成功順=表示順**になっていた。`outcome.successes`を辿る誤実装でも全testがPASSする状態で、コメントだけが「両者が食い違う入力で検査する」と主張していた。reviewerがprobeで実装自体は正しいことを確認している。
  - 対処: `f1→f2, f2→f3`(f1の目標名が既存のf2と衝突するので計画が逆順になる)を入力にしたtestを追加し、実行順が表示順の逆であることをtestの前提として押さえたうえで、更新日時が表示順に増えることを検査した。誤ったコメント2箇所も実態へ直した。
  - **判別力をmutationで実証した**。`_shiftModifiedAtOfSuccesses`を`outcome.successes`順へ一時改変すると、**追加したtestだけがFAIL**し、他8件はPASSのままだった。改変は元へ戻してある。
- 2026-08-12 / P2も対処した。`DesktopRenameExecutor.setModifiedAt`に自動testが1件も無かった(注入口を用意しながら未使用)ため4件追加した(実file更新、対象なし、想定外の例外、権限)。例外の捕捉を`FileSystemException`限定から全捕捉へ広げ、分類を独自のerrorCode読みからrename側と同じ`errorOf`へ寄せた。POSIXの5はEIO、Win32の5はACCESS_DENIEDで意味が違うため、数値を直接読まない。

- 2026-08-12 / 独立reviewが挙げた「巻き戻しで更新日時が戻らない」点を、開発者が**意図した受容**と決定。契約の`scope.out`と`spec.md`の対象外へ明記し、代表例5bを追加、contract revisionを2→3にした。実装の振る舞いは変えていない(元から戻さない)。名前は`REQ-006`どおり戻る。

## Current state / handoff

- Last checkpoint: 実装・仕様由来test・manual verificationがすべて揃った
- Blocker category: review
- Waiting for: exact revisionと証拠を対象にした独立review
- Requested action: なし(Agentがreviewを起動する)
- Evidence revision: branch `asdd/005-rename-exec/T07-desktop-modified-time`。手順1・2・Androidは1回目、手順3・4は2回目に実施。両者の間に`lib/`と`test/`の差分はゼロ(手順書の書き直しのみ)
- Evidence: manual verification=PASS(全手順。Windows desktop + Android、2026-08-12、開発者)、`flutter test`=PASS(354、うち`modified_time_test.dart` 8件)、`flutter analyze`=PASS(0)、`dart format`=PASS(76 files / 0 changed)
- Next Agent action: 独立reviewを起動し、PASSならPRを出して人間へmergeを依頼する
