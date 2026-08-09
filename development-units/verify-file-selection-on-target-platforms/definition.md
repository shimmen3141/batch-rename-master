# 開発単位: target platformでファイル選択を受け入れ確認する

## 目的

既に実装されたファイル選択・一覧置換・platform adapterが、Android SAFとdesktop file pickerの実環境で承認済み004仕様どおりに動く証拠を得る。

## 根拠

- 仕様正本: `specs/004-file-source/spec.md`
- 外部I/O判断: `specs/004-file-source/decisions/ADR-001-file-source-plugins.md`
- 仕様由来test: `test/spec_004_file_source/`
- 旧受け入れ条件: `specs/004-file-source/plan.md`（cutoff前の履歴。statusには使わない）
- unit固有手順: `manual-verification.md`
- 共通host手順: `docs/development/emulator-verification.md`

## 境界

### 対象

- Androidの種類選択、document picker、複数選択、cancel、置換、場所表示、跨ぎwarning。
- desktop file picker、絶対path handle、cancel、置換。
- 作成日時不明時の表示・sort warning。
- 同じcommit/buildに対応する手動証拠の独立review。

### 対象外

- 実rename。`complete-rename-execution`で扱う。
- MediaStoreの写真・動画一覧。将来の別unitで扱う。
- UIの最終的な見た目と操作配置。将来のUI整合unitで扱う。

## 重要な決定

| 日付 | 決定 | 理由 |
|---|---|---|
| 2026-08-09 | 旧004の実装taskは再実装せず、欠けていたtarget platform受け入れだけをunitにする | 旧planはtaskをdoneとしていた一方、全体受け入れにはhost証拠待ちが残っていたため |
| 2026-08-09 | 仕様・自動testは既存正本を継続利用する | REQ/VER IDと既存検証資産を複製しないため |

## 受け入れ証拠

| 観測する成果 | 証拠 |
|---|---|
| 004の自動検証が現在のbaseで通る | `flutter test test/spec_004_file_source/` |
| 回帰・静的検査に不適合がない | `dart format --output=none --set-exit-if-changed .`、`flutter analyze`、`flutter test` |
| Android SAFの選択・cancel・置換・warningが成立する | `manual-verification.md#android-saf`を同じcommit/buildで実施した記録 |
| desktop pickerの選択・cancel・置換・absolute pathが成立する | `manual-verification.md#desktop`を同じcommit/buildで実施した記録 |
| 仕様、実装、手動観測が一致する | exact commitと証拠に対する独立reviewのPASS |

## リスクと進め方

- 主目的は受け入れ証拠の取得であり、観測前に既存挙動を変更しない。
- 製品不具合を観測したら、このunitの不足成果として実装checkpointを追加する。ASDD手順自体の再利用可能な問題だけをdevelopment findingへ分ける。
- Androidとdesktopは独立して確認できるが、unit PASSには両方が必要である。

## 未決定事項

- なし。承認済み004仕様の意味変更が必要になった場合だけ、人間判断を求める。
