# プロダクトマップ

## この文書の役割

実装済み能力、未完了の受け入れ、現在の計画、将来候補、対象外をプロダクト構造で結ぶ。live statusは持たず、各`plan.json`・`task.json`と非終端`task.md`のhandoffを参照する。

## 能力と現在の到達点

| 領域 | 到達点 | 正本 |
|---|---|---|
| 001 コア命名エンジン | 純粋Dartの命名、preview、検証、自動解決を実装済み | [`001-rename-core/`](001-rename-core/) |
| 002 ファイル一覧 | 選択、sort、custom順、preview表示を実装済み | [`002-file-list/`](002-file-list/) |
| 003 ルール構築 | token追加・編集・並び替えとresponsive UIを実装済み | [`003-rule-builder/`](003-rule-builder/) |
| 004 ファイルsource | Android SAF・desktop pickerと選択導線を実装済み。target platformの手動受け入れが未完 | [`004-file-source/`](004-file-source/) |
| 005 リネーム実行 | 警告確認・結果表示は統合済み。desktop安全rename・undoはPR #116の手動証拠待ち。Androidは安全にunsupported。空ルールUIと更新日時ずらしは未完 | [`005-rename-exec/`](005-rename-exec/) |
| 007 ルール永続化 | serialization・保存・復元を実装済み。process再起動をまたぐ手動受け入れが未完 | [`007-rule-persistence/`](007-rule-persistence/) |
| 013 Android安全rename | 原子的no-replaceを満たすstorage・permission境界の設計判断が未着手 | [`013-safe-android-rename/`](013-safe-android-rename/) |

## 主な依存

```text
001 rename core ─┬─> 002 file list ─┬─> 004 file source ─> 005 rename execution ─> 008 UI整合候補
                 └─> 003 rule UI ───┘                         └─> 013 Android安全rename

003 rule UI ─> 007 rule persistence ─> 011 schema判断 ─> 009 named presets
004 file source ─> 006 Windows D&D / 010 media source / 012 hidden-file filter
```

## 将来候補

| 予約ID・候補 | 目的 | 前提・判断点 |
|---|---|---|
| 006 Windows Explorer D&D | Explorerからfileを一覧へ追加する | 002/004の置換・追加境界とWindows host証拠を定義する |
| 008 UIと主要操作の整合 | 参考デザイン、以前の実装、現実装を比較し、rename操作位置、情報階層、sort、token追加、選択・削除を整える | 005完了後。見た目と操作の優先順位は人間が決める |
| 009 名前付きルールpreset | 複数の名前付きruleを保存・選択する | 007を再利用し、011の要否を先に決める |
| 010 写真・動画source | MediaStoreの全件・album選択と撮影日時を提供する | 004完了。日時の意味変更は001/002を再承認する |
| 011 保存schema移行 | 保存済みruleをschema変更後も失わず変換する | 利用者資産を増やす前に必要性を判断する |
| 012 隠し・system file filter | 識別可能なplatformで対象外fileを除外する | 信頼できるAPIとfallbackが必要 |
| 元名のcase変換 | keep/upper/lowerをtokenへ追加する | 001 Strict contractの意味変更と人間承認が必要 |

## 対象外

- cloud同期
- sessionをまたぐ永続的な多世代undo履歴
- 正規表現置換
- subfolderを横断する再帰探索

再検討時は旧資料から直接taskを起こさず、要求を確認して新しいplanへ定義する。
