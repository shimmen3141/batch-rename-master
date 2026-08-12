# 手動確認: desktopの更新日時ずらし

## この文書の状態

**T07はまだ実装されていません。** 実行可能なchecklistは、optionの置き場所・刻み幅・失敗表示が決まる実装時に書きます。UIが決まる前に手順を書くと、実際の画面と食い違うものが残ります。

以下は、実装時にchecklistへ必ず落とすべき観点です。出所は`task.md`の受け入れ証拠と、`history/asdd-0.x-plan.md`のT7受け入れ条件。

## 実装時にchecklistへ落とす観点

1. **既定OFF** — 初回起動時にoptionがOFFで、OFFのまま改名しても`modifiedAt`が変わらない。実filesystemのmtimeで確認する(Windowsなら`Get-ChildItem | Select-Object Name, LastWriteTime`)。
2. **Androidでは提示しない** — SAFに設定APIが無いため、Androidではoption自体を出さない。「効かない設定」を見せていないことをAndroid buildで確認する。
3. **ONのとき表示順にずれる** — 改名に成功したファイルのmtimeが、**一覧の表示順**で一定間隔ずつ後ろへずれる。並び替えてから実行し、ソートキーではなく**表示順**に対応することを確認する。
4. **刻み幅とfilesystem解像度** — FAT系は2秒粒度など、filesystemによって刻みが丸められる。丸められた場合でも順序が保たれることを確認する(等間隔であることは要求しない)。
5. **日時の更新に失敗しても改名は取り消さない** — 更新日時のずらしに失敗しても、改名そのものは成功として残り、続けて操作できる。読み取り専用属性やロック中のファイルなど、日時の更新だけが失敗するfixtureで確認する。
6. **失敗の見分け** — mtime更新の失敗が、改名の失敗と**区別して**表示される。利用者が「改名は成功したが日時だけずれなかった」と読み取れる。

## 事前準備(実装時に具体化する)

共通の起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)に従う。fixtureは、mtimeを比較できる複数ファイルと、mtime更新だけを拒否できるファイル(読み取り専用属性など)を用意する。

## 結果の伝え方

会話でそのまま教えてください。書式は問いません。結果は`task.md`の作業記録へAgentが要約します(このfileにstatusは書きません。状態の正本は`task.json`です)。
