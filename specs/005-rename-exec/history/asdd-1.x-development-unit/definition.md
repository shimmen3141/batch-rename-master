# 開発単位: リネーム実行を完成させる

## 目的

利用者がプレビュー済みの名前を確認して、安全性を証明できるplatformでは実ファイルへ適用できるようにする。desktopでは排他的rename、部分失敗、単一session内のundo、任意の更新日時ずらしを観測できる。Android SAFでは原子的no-replaceを保証できないため、実体を変更せず理由付きの未対応を返す。

## 根拠

- 依頼・旧計画: `specs/005-rename-exec/plan.md`（0.x cutoff以前の履歴。live statusとしては使わない）
- 仕様正本: `specs/005-rename-exec/contracts/behavior-contract.json`
- 説明・反証記録: `specs/005-rename-exec/spec.md`
- 外部I/O判断: `specs/004-file-source/decisions/ADR-001-file-source-plugins.md`
- 仕様由来test: `test/spec_005_rename_exec/`
- 共通のhost環境手順: `docs/development/emulator-verification.md`
- unit固有の手動確認: `development-units/complete-rename-execution/manual-verification.md`

## 境界

### 対象

- 警告確認、cancel、強制実行、二重実行防止、実行結果の提示。
- rule未設定時の実行防止と案内。
- desktop file systemによる排他的な実renameと、新しいhandleの反映。
- Android SAF production経路で、provider renameを呼ばず理由付きの安全な未対応を返すこと。
- 成功したrenameだけを対象にした、期限付き単一step undo。
- desktop限定・既定OFFの更新日時ずらし。

### 対象外

- rename結果を決めるtoken評価・衝突解決規則。既存の001成果を使う。
- file選択とpermission取得。既存の004成果を使う。
- sessionをまたぐundo履歴、file移動・copy・delete。
- Androidでの更新日時書き換え。
- Androidで成功可能なrename storage境界の設計・実装。調査は`design-safe-android-rename-boundary`へ分離する。
- 最終的なvisual polish。別unitで扱う。

## 重要な決定

| 日付 | 決定 | 対象仕様・revisionまたは意味差分 | 理由・決定者 |
|---|---|---|---|
| 2026-08-09 | 旧005のapproved Strict contractとREQ/VER IDを仕様正本として継続利用する | `specs/005-rename-exec/contracts/behavior-contract.json` at cutoff `8d950ca` | 0.xから1.0への移行で意味と検証資産を失わないため / 開発者の移行依頼 |
| 2026-08-09 | 旧T4以降の未実装成果だけを新execution mapへ移す | 旧T4/T9/T5/T6/T7の成果と依存。旧status・claim・logは移さない | 実装diffのないT4直前が安全なcutover境界のため / 開発者の移行依頼 |
| 2026-08-09 | INV-002をplatform例外なく維持し、Android SAF production renameを副作用なしunsupportedとする | `specs/005-rename-exec/contracts/behavior-contract.json` revision 2、`specs/005-rename-exec/decisions/ADR-001-android-saf-rename-safety.md` | SAF provider境界は原子的no-replaceと失敗理由を保証できず、provider依存raceを受容しないため / 開発者 |
| 2026-08-09 | Android成功経路の調査を別unitへ分離する | `development-units/design-safe-android-rename-boundary/definition.md` | storage方式・provider制限・追加権限・配布riskを実装前に判断するため / 開発者 |

## 受け入れ証拠

> normativeな振る舞いは既存Strict contract、package別の接続はexecution mapを正本とする。

| 観測する成果 | 証拠・実行方法 |
|---|---|
| approved contractの必須振る舞いが仕様由来testで通る | `flutter test test/spec_005_rename_exec/` |
| project全体にformat・静的解析・回帰不適合がない | `dart format --output=none --set-exit-if-changed .`、`flutter analyze`、`flutter test` |
| Android SAFでrename APIが呼ばれず、未対応理由が表示され、実データが不変である | `manual-verification.md`のAndroid SAF安全未対応手順を同じcommit/buildで実施した記録 |
| desktopで実rename・undo・更新日時ずらしが成立する | `manual-verification.md`のdesktop手順を同じcommit/buildで実施した記録 |
| working treeまたは対象commit rangeがこのunitの境界内である | `git status --short`と正確な`git diff`の独立review |

## リスクと進め方

- 曖昧さ: low — 振る舞い、異常系、自由、未解決事項はapproved Strict contractで確定済み。
- 失敗コスト: high — 実file renameは不可逆な副作用と部分失敗を含む。
- 共有調整: required — GitHub Issuesをlive status・担当・branch・review結果の正本にする。
- 振る舞い仕様: 既存の仕様正本 `specs/005-rename-exec/contracts/behavior-contract.json` を更新する。
- 実行依存マップ: 検証可能な`execution-map.json`を使う。
- 実装前の人間判断: 不要。approved contractの意味を変更する場合だけrevision差分を示して再判断を求める。

## 未決定事項

- なし
