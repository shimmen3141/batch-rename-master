# T37 app内file browserへ範囲選択を実装する

## 目的

T36で承認された004 REQ-020をAndroid app内file browserへ実装する。T31で確立した長距離dragの仕組みを再利用しつつ、browser固有の「読み込むfileの選択」と、メイン一覧固有の「リネーム対象から外す候補」を混ぜない。

## 依存

- T36（004 REQ-020の定義）。
- T31（pointer追跡・行交差・edge auto-scrollの検証済み実装）。
- 004 REQ-016/017（同一folder、entryを絞らない）。

## 変更範囲

- `storage_browser_view.dart`のfile選択UIと状態。
- pointer追跡、実在行との交差、edge auto-scrollのうち画面に依存しない部分を共通部品へ抽出する。
- T31の`RemovalSelection`とbrowserの`_selected`は別状態のまま保つ。共通部品は選択の意味を所有せず、通過した項目とscroll/pointer lifecycleだけを通知する。
- 現在folderのfileだけを対象にする全選択操作を追加する。folder・近道は含めない。

## machine検証範囲と引き受け先

- widget test: 全選択、通常/モード中の長押しdrag、往復解除、開始時選択保護、**通常scrollでは選択追跡が始まらないこと**、folder行・近道非対象、可変行・edge auto-scroll、offscreen後の停止/反転/解除、lift/cancel/bounds、folder移動で解除。root fixtureへfile・folder・近道を同時に置き、全選択がfileだけを選ぶことを反証する。
- semantics widget test: 全選択controlの操作名が支援技術から認識でき、tap actionで実行できる。
- mutation: 共通pointer所有、往復解除、全選択対象のfile限定（folderと近道の両方）、Semantics actionを検出する。
- Android実機: 長押し感、edge速度、長距離往復、全選択controlが読み取れてtapできること。T37が引き受ける。
- desktopはOS picker経路であり、製品経路にこのwidgetが載らないため実機対象外。

## 受け入れ証拠

- REQ-020由来widget testと既存`test/spec_004_file_source/`がPASSする。
- T31の関連testが継続PASSし、共通化で既存の除去選択を壊さない。
- 必要なmutationがKILLED。
- format/analyze/full test/workspace checkがPASSする。
- Android物理端末で`manual-verification.md`がPASSする。
- exact rangeの独立reviewがPASSする。review modelは開発者指定のlunaを使う。

## Current state / handoff

- Last checkpoint: T36と同時に実装taskとして定義した。
- Status: `pending`（T36依存）。
- Blocker category: dependency / T36.
- Evidence revision: `dev@65fbc3b`.
- Waiting for: T36完了。
- Requested action: なし。
- Next Agent action: T36完了後、専用branch/worktreeで着手する。
