# プロダクトマップ

## この文書の役割

実装済み能力、未完了の受け入れ、現在の計画、将来候補、対象外をプロダクト構造で結ぶ。live statusは持たず、各`plan.json`・`task.json`と非終端`task.md`のhandoffを参照する。

## 能力と現在の到達点

| 領域 | 到達点 | 正本 |
|---|---|---|
| 001 コア命名エンジン | 純粋Dartの命名、preview、検証、自動解決を実装済み | [`001-rename-core/`](001-rename-core/) |
| 002 ファイル一覧 | 選択、sort、custom順、preview表示を実装済み | [`002-file-list/`](002-file-list/) |
| 003 ルール構築 | token追加・編集・並び替えとresponsive UIを実装済み | [`003-rule-builder/`](003-rule-builder/) |
| 004 ファイルsource | Android SAFとdesktop pickerからファイルを読み込み、一覧へ渡せる | [`004-file-source/`](004-file-source/) |
| 005 リネーム実行 | 警告を確認して実行し、結果と5秒以内のundoを提示できる。desktopは安全な実rename・更新日時ずらし、Androidは理由付きの未対応 | [`005-rename-exec/`](005-rename-exec/) |
| 007 ルール永続化 | 直近のルールを保存し、process再起動後に復元できる | [`007-rule-persistence/`](007-rule-persistence/) |
| 008 UIと主要操作の整合 | 005完了を受けて計画済み。並び順control、選択と除去、token追加、行と警告の情報階層、読み込み導線、表示mode、余白・typographyをT01〜T10へ分解した。今後のUI調整の受け皿でもある | [`008-ui-alignment/`](008-ui-alignment/) |
| 013 Android安全rename | 005の安全なunsupportedが統合済み。`T01`は公式資料への到達経路が2026-08-13に許可され、着手可能 | [`013-safe-android-rename/`](013-safe-android-rename/) |

## 主な依存

```text
001 rename core ─┬─> 002 file list ─┬─> 004 file source ─> 005 rename execution ─> 008 UI整合
                 └─> 003 rule UI ───┘                         └─> 013 Android安全rename

003 rule UI ─> 007 rule persistence ─> 011 schema判断 ─> 009 named presets
004 file source ─> 006 Windows D&D / 010 media source / 012 hidden-file filter
```

## 将来候補

| 予約ID・候補 | 目的 | 前提・判断点 |
|---|---|---|
| 006 Windows Explorer D&D | Explorerからfileを一覧へ追加する | 002/004の置換・追加境界とWindows host証拠を定義する |
| 009 名前付きルールpreset | 複数の名前付きruleを保存・選択する | 007を再利用し、011の要否を先に決める |
| 010 写真・動画source | MediaStoreの全件・album選択と撮影日時を提供する | 004完了。日時の意味変更は001/002を再承認する |
| 011 保存schema移行 | 保存済みruleをschema変更後も失わず変換する | 利用者資産を増やす前に必要性を判断する |
| 012 隠し・system file filter | 識別可能なplatformで対象外fileを除外する | 信頼できるAPIとfallbackが必要 |
| 元名のcase変換 | keep/upper/lowerをtokenへ追加する | 001 Strict contractの意味変更と人間承認が必要 |

### 008へ引き継いだ人間の決定(planへ反映済み)

ASDD移行で凍結した[`history/asdd-0.x-discovery.md`](history/asdd-0.x-discovery.md)の(a)〜(g)は、008の入力として有効だった。**2026-08-12に[`008-ui-alignment/plan.md`](008-ui-alignment/plan.md)へ反映済み**で、以後はplanが正本である。この節は出所の記録として残す。

- **並び順コントロール**((e)): 横並びchipをやめ、現在の状態を示す「⇅ 並び順: 名前」形式のドロップダウンボタンにする。手動で並び替えた瞬間に表示を「⇅ 並び順: カスタム」へ変える。各keyへ昇順・降順を持たせる。あわせて002 REQ-014(連番が無いときカスタム順とdrag handleを隠す)を**廃止**し、連番の有無に関わらず手動並び替えを可能にする。002の仕様変更を伴う。
- **選択と削除の役割重複**((g)): 行のcheckbox(rename対象)と行の×(一覧から除去)の併存をやめ、checkboxへ統一する。削除は左swipeで出す。**「すべて外す」は「リストを空にする」等へ改名する**(checkboxを外す操作だと誤解されるため)。002 REQ-009(`removeFile` / `clearFiles`)は状態層として残し、提示の仕方だけを変える。002/004の仕様変更を伴う。
- **token追加の導線**((f)): 「既定値で即追加してから編集」をやめ、追加を押すとmodalが出て設定を終えると追加される形にする。003の仕様変更を伴う。
- 残る(a)〜(d)(リスト表示3案、種別アイコンとリッチ行、読み込み導線とpath表示、余白・階層・typography)も、**2026-08-13に008の対象とした**。他のplanが拾わないまま残るのを避けるための人間の決定である。(b)はT07へ統合し、(c)(a)(d)はT08/T09/T10になった。以後は008が今後のUI調整の受け皿である。
- **(h) 行サブ情報の見切れ**(2026-08-12、`004:T10`のAndroid実機確認で観測。開発者がUI調整として008へ送ると判断) — 行のサブ情報は`file_list_view.dart`で「場所 · 作成日時 / 更新日時」を1つの`Text.rich`にまとめ、`maxLines: 1` + ellipsisで省略している。狭幅のAndroidでは省略が`作成日時: 不明`の手前まで届き、**日時の文字列が読めない**ことがある。ただし警告アイコンは`Expanded`の外にあり省略されないため、**002 REQ-013が求める「どのitemの作成日時が不明か」の識別自体は成立している**(仕様違反ではない。同REQは提示方法の詳細を視覚デザインとして対象外にしている)。読みやすさの問題として、折り返し、優先順位付きの省略、行レイアウトの作り直しのいずれで解くかは008の範囲。
- **(i) 重複警告の発生頻度**(2026-08-12、同確認で判明) — file選択画面の種類チップがフォルダを横断するため、複数フォルダのファイルが混ざる状況は**まれではなく通常経路で起きる**(`development-findings/2026-08-12-documentsui-type-chip-crosses-folders.md`)。001の重複判定は最終名集合を全ファイル横断で数えるため、別フォルダの同名で「実際には衝突しないのに重複警告」が出る頻度も想定より高い。005の警告UXを008で扱うときの入力にする。

005で扱うUIは`docs/design/Bulk Renamer.html`のうち各taskが明記した画面範囲に限る。上記は008の範囲であり、005のtaskで先取りしない。

## 対象外

- cloud同期
- sessionをまたぐ永続的な多世代undo履歴
- 正規表現置換
- subfolderを横断する再帰探索

再検討時は旧資料から直接taskを起こさず、要求を確認して新しいplanへ定義する。
