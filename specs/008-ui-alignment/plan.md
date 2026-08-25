# 008 UIと主要操作の整合

## 目的

実機で触って出た「操作の意味が読み取れない」指摘を解消する。並び順は現在の状態が見える一つのcontrolになり、リストからの除去は選択と混同されなくなり、tokenは設定を終えてから列に入る。参考designと現実装の食い違いのうち、**利用者の操作の意味に関わるもの**を揃える。

002/003の仕様は「視覚デザインは非規範」として見た目を対象外にしており、その結果これらの指摘がどの計画にも割り当てられないまま残っていた。008がその受け皿になる。

## 境界

### 対象

- 並び順controlの作り直しと、002 REQ-014(連番が無いとき手動並び替えを隠す)の廃止。
- 行のcheckbox(rename対象)と行の×(一覧から除去)の役割重複の解消。「すべて外す」の改名。
- token追加を「既定値で即追加してから編集」から「modalで設定を終えてから追加」へ変える。
- 行のサブ情報と警告帯の情報階層。狭幅で必要な情報が読めなくなる問題を含む。ファイル種別アイコンとリッチな行layoutを含む。
- 読み込み導線と場所の提示。
- **Androidのapp内file browserの提示**(入口、近道の見分け、上位へ戻る操作、行のpreview)。`013:T07`が画面を新設し、実機確認で指摘が出た。
- modalの文言と見せ方(結果の提示手段を含む)。
- リスト表示modeの切替。
- 全体の余白・階層・typography。
- 上記に伴う002/003/004 specの更新と、人間の再承認。

**このplanはUI調整の受け皿である。** 実機で触って出るUIの指摘は今後も増える前提で、新しい指摘は原則このplanへtaskとして足す。別planを立てるのは、UIの提示ではなく判定・契約・permissionが動くときに限る。

### 対象外

- ルールのpreset保存UI。→ 009
- 元名の大小変換。→ 001の将来拡張
- 001の重複判定をfolder単位へ変えること。→ 判定は001が正本。008は提示だけを扱う
- Androidのrename成功経路。→ 013

## 方針

- **仕様を変えるものは、仕様更新taskと実装taskを分ける。** 002/003/004はいずれもLightだがapprovedなので、外部から観測できる振る舞いを変えるには人間の再承認が要る。承認前に実装を始めない。
- **`covers`は仕様更新taskが埋める。** 全taskの`covers`は現在空である。REQ IDが確定するのはT01/T03/T05/**T11**の承認時なので、その4taskの受け入れ証拠に「対応する実装taskの`covers`を書く」ことを入れてある。T07/T08/T10/**T13/T14**は仕様を変えないため、空のままが正しい。
- **判定は動かさない。** 001の重複・桁不足・空名・基準日時不明の判定、005の実行可否、004の読み込み契約はそのまま。008が変えるのは**提示と操作の導線**である。
- 参考design `docs/design/Bulk Renamer.html` は配置・導線・情報階層の正本(AGENTS.md)。各taskは適用する画面範囲を`task.md`へ書く。
- 実機で触らないと判断できない項目があるため、実装taskはmanual確認を持つ。手順は実装後にcurrent revisionと照合して具体化する。
- 005:T09で下部固定バーへ集約した実行導線は動かさない。今回触るのは一覧の行、並び順control、token追加、警告帯である。

## 全体の受け入れ条件

- [ ] 連番トークンの有無に関わらず手動並び替えができ、並び順controlが現在の状態(名前/作成日時/更新日時/サイズ/カスタム、昇順・降順)を常に示す
  - 証拠: 002 specの更新と再承認、仕様由来test、Windows desktopとAndroidでの手動確認
- [ ] 一覧からの除去がcheckboxと混同されない導線になり、「すべて外す」が何をするか名前から分かる
  - 証拠: 002/004 specの更新と再承認、仕様由来test、手動確認
- [ ] tokenは設定を終えてから列に入る。既定値のままのtokenが紛れない
  - 証拠: 003 specの更新と再承認、仕様由来test、手動確認
- [ ] 狭幅でも、どの行の作成日時が不明かと、警告の内容が読み取れる
  - 証拠: widget test、Android実機での手動確認
- [ ] 読み込み前・読み込み後・複数folderが混ざった状態で、どこから何が入っているかが読み取れる
  - 証拠: widget test、AndroidとWindows desktopでの手動確認
- [ ] リスト表示modeを切り替えても、選択・手動並び替え・警告表示が成立する
  - 証拠: widget test、両platformでの手動確認
- [ ] 余白と文字の階層がapp全体で一貫し、値がthemeへ寄っている
  - 証拠: 既存widget testの継続PASS、diff、両platformでの手動確認
- [ ] Androidのapp内file browserで、どこから読み込もうとしているか・近道と実体のfolderの違い・ファイルの中身が読み取れる
  - 証拠: 004 specの更新と再承認(入口と近道)、widget test、Android実機での手動確認。**`013:T07`が実機で確かめた要求(階層、選択、注記、rootの上限)を弱めていないこと**
- [ ] modalが、何を聞かれているか・実行すると何が起きるか・結果がどうなったかを、件数が多いときにも読み取れる
  - 証拠: widget test、Android実機での手動確認
- [ ] `python <asdd-plugin>/scripts/workspace.py check specs`、`flutter test`、`flutter analyze`、`dart format --output=none --set-exit-if-changed .` がPASS
- [ ] 001の判定、004の読み込み契約、005の実行・undo・警告の判定を変えていない(既存testの継続PASS)

## 人間の決定

| 日付 | 論点 | 決定 | 決定者 |
|---|---|---|---|
| 2026-08-05 | 実施順 | 警告表示・進捗・undoのUIは005が作るため、008は005完了後に行う | 開発者 |
| 2026-08-05 | 並び順control | 横並びchipをやめ、現在の状態を示すドロップダウンにする。手動で並び替えた瞬間に「カスタム」へ変える。各keyへ昇順・降順を持たせる。あわせて002 REQ-014を廃止し、連番の有無に関わらず手動並び替えを可能にする | 開発者 |
| 2026-08-05 | 選択と削除 | 行のcheckboxと行の×の併存をやめ、checkboxへ統一する。削除は左swipeで出す。「すべて外す」は「リストを空にする」等へ改名する | 開発者 |
| 2026-08-05 | token追加 | 「既定値で即追加してから編集」をやめ、追加を押すとmodalが出て設定を終えると追加される形にする | 開発者 |
| 2026-08-12 | 行サブ情報の見切れ | 狭幅で`作成日時: 不明`の文字列が読めない件を、UI調整として008で扱う(識別自体は警告アイコンで成立しており仕様違反ではない) | 開発者 |
| 2026-08-13 | (a)〜(d)の扱い | 他のplanが拾わないため**008の対象へ入れる**。T07へ(b)を統合し、(c)(a)(d)をT08/T09/T10として足す。あわせて008を今後のUI調整の受け皿と位置づける | 開発者 |
| 2026-08-15 | 再採番結果の提示方法 | **`013:T11`が結果toastへ入れた「旧 → 新」の全件表示を、008で見直す。** 件数が多いとtoastが縦に伸びる(現在は高さ96pxで打ち切ってscroll)。**modalの方が向いている**という指摘を受けたが、005 contract REQ-024が求めるのは「どの項目がどの名前になったかを示す」ことで、提示手段は自由(005 spec「自由とする点」)。**振る舞いは変えず提示手段だけを動かすので008の範囲**である | 開発者 |
| 2026-08-25 | `013:T07`のUI指摘 | app内file browserの実機確認で出たU1〜U5を**008へtask化する**(T11〜T14)。U6(「すべて」を開き直したときに前回の場所と選択を復元する)は本人が「ふとした思い付き」としたため`product-map.md`の将来候補へ置く | 開発者 |
| 2026-08-13 | 計画の承認 | 状態 draft → **approved**。task分割、対象外の範囲、(a)〜(d)を含めた構成に個別異議なし | 開発者承認 |

出典: `specs/product-map.md`の「008へ引き継いだ人間の決定(planへ反映済み)」節。原文は凍結した[`specs/history/asdd-0.x-discovery.md`](../history/asdd-0.x-discovery.md)の44〜48行。

## review記録

- Review attempt 1: `ea1dd04..d9d6bb2` — FAIL — P1: T09の`dependsOn`がtask.md本文の前提(T02によるREQ-014廃止)を宣言していない。P2×6: 引用節名の陳腐化、`008-ui-polish` slugの残存、`file_source_bar.dart`の担当重複、T07/T08の場所の提示の分担未定、`covers`を埋める時期の未定義、product-mapの到達点が古い。
- Review attempt 3(T11〜T14の登録): `ae59859...8726de6` — FAIL — **P1-1: `T14`のmodal一覧の4行目が誤り。** `rule_builder_workspace.dart:76`を「tokenの追加 / `T05`/`T06`が持つ」と書いたが、実体は**ルール構築画面まるごとのbottom sheet**(mobileの下部バー「ルール設定」)で、`T05`/`T06`はこれを持っていない。**Androidではルールの編集が必ずこのsheet越し**なので、U5がこれを指していた場合に**どのtaskも拾わないまま落ちる**ところだった。P2×5: 種類選択sheetの分担を片側だけで宣言、`covers`の方針段落が新taskに未追随、境界に足した2行に対応する全体の受け入れ条件が無い、`T13→T12`の依存にした理由が未記載、`T11`のU2に「そもそも要求を足さない」案が無い。**すべて直した**(下の日付の決定表を参照)。
- Review attempt 2: `ea1dd04..72dd5f8` — PASS — 未解決P0/P1なし。残P2×3(行widgetのT04/T07/T09間の分担未宣言、T08 task.mdの内部矛盾、product-mapのlive status寄り記述)は`ec2e74f`のmerge後に解消した。

## タスク

タスクのID・依存・状態は`plan.json`と各`tasks/*/task.json`が正本。詳細は各`task.md`を読む。番号は安定した識別子であり、実行順や優先順位ではない。

| ID | 詳細 |
|---|---|
| T01 | [task.md](tasks/T01-define-sort-control/task.md) |
| T02 | [task.md](tasks/T02-implement-sort-control/task.md) |
| T03 | [task.md](tasks/T03-define-selection-flow/task.md) |
| T04 | [task.md](tasks/T04-implement-selection-flow/task.md) |
| T05 | [task.md](tasks/T05-define-token-add-modal/task.md) |
| T06 | [task.md](tasks/T06-implement-token-add-modal/task.md) |
| T07 | [task.md](tasks/T07-row-and-warning-presentation/task.md) |
| T08 | [task.md](tasks/T08-load-affordance-and-path/task.md) |
| T09 | [task.md](tasks/T09-list-display-modes/task.md) |
| T10 | [task.md](tasks/T10-spacing-and-typography/task.md) |
| T11 | [task.md](tasks/T11-define-browser-entry-and-shortcuts/task.md) |
| T12 | [task.md](tasks/T12-implement-browser-presentation/task.md) |
| T13 | [task.md](tasks/T13-browser-file-preview/task.md) |
| T14 | [task.md](tasks/T14-modal-wording-and-presentation/task.md) |
