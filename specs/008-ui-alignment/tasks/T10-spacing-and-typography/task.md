# T10 余白・階層・typographyを揃える

## 目的

参考designの(d)にあたる最終の追い込み。個々の画面ではなく、**app全体で余白と文字の階層が一貫している**状態にする。

## 入力と依存

- `specs/history/asdd-0.x-discovery.md`の(d)「全体の余白・階層・タイポグラフィ」。
- 参考design `docs/design/Bulk Renamer.html`。
- 現行実装: `lib/ui/theme/app_theme.dart`、`lib/ui/theme/app_colors.dart`(`AppColors` ThemeExtension)。
- **008の他の実装task(T02/T04/T06/T07/T08/T09)すべて。** 構造が動いている間に余白だけ整えても作り直しになる。

## 変更範囲

- 余白・文字sizeの値をthemeへ寄せ、画面側の直書きを減らす。
- 見出し・本文・補助情報のtypography階層。
- 上記に伴う各画面の調整。

**振る舞いは変えない。** 文言、判定、状態遷移、操作の意味はこのtaskで触らない。触りたくなったら別taskへ送る。

### 引き受けた残余risk(`008:T07`から)

- **N-8b**: 文字サイズを最大(`textScaler` 3.0相当)にすると、一覧の`_HeaderBar`と外側の
  `Column`がoverflowする。**`T07`が触っていない既存code**で、行(`_FileRow`)は無傷である
  (2026-08-29のAndroid emulator確認と、`T07`の独立reviewのprobeで観測)。sort chipの側は
  `T02`が引き受けた(N-8a)。

## 受け入れ証拠

- 既存のwidget testがすべて継続PASSする(振る舞いを変えていないことの主な証拠)。
- 余白・文字sizeの直書きがthemeへ寄っていることをdiffで示す。
- 狭幅で情報が読めることを検査するT07/T09のtestが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機とWindows desktopの主要画面を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-13 / 人間の判断で(a)〜(d)を008の対象へ入れた際に定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: 008の実装taskすべて。最後に一度で行う
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 先行taskの完了後に着手する。先に手を付けない
