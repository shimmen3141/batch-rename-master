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

## 実装・検証記録

- 実装Agent: `gpt-5.6-sol`（ユーザー指定）。
- implementation checkpoint: `c3e5963`。
- verification checkpoint: `d88ab4f`。
- 共通化: `DragSelectionController<T>`はactive pointer、実描画行との交差、drag経路の復路、edge auto-scroll、lift/cancelを所有する。選択集合と「選ぶ／外す」の意味は各画面が所有する。
- browser固有: 現在folderのfileだけを全選択し、folder・近道を除外する。長押しdragはbrowserの`_selected`だけを更新し、folder移動時には既存どおり解除する。全選択は操作名とtap actionを持つSemantics controlとして公開する。
- related tests: `flutter test test/spec_002_file_list/removal_selection_mode_test.dart test/spec_004_file_source/storage_browser_view_test.dart` — PASS（64 tests）。
- T37 browser tests: `flutter test test/spec_004_file_source/storage_browser_view_test.dart` — PASS（27 tests）。
- mutation: `python3 /home/dev/.agents/skills/asdd/scripts/mutation_check.py /tmp/t37-mutations.json --root .`（commandは上記related tests）— `M393`〜`M403`の11件すべてKILLED、SURVIVED 0、SKIPPED 0。
- Semantics修正後の対照: M402のみをbrowser testsで再実行 — KILLED。
- format: `dart format --output=none --set-exit-if-changed .` — PASS（132 files、変更0）。
- static analysis: `flutter analyze` — PASS。
- full regression: `flutter test --reporter compact` — PASS（954 tests）。
- ASDD構造: `python3 /home/dev/.agents/skills/asdd/scripts/workspace.py check specs` — PASS（8 plans、90 tasks）。
- Android build / 物理端末: AI containerにはAndroid SDKが無いため未実施。`manual-verification.md`で同一code revisionを確認する。
- 独立review attempt 1: `gpt-5.6-luna`、exact range `bef8337...c9f3fec` — BLOCKED。P0〜P3の成果物欠陥と安全網の穴はなし。related 64件PASS、reviewer対照を含むmutation 11件KILLED。必須のAndroid物理端末manualが未実施のためfinal-evidence判定だけを保留。

## 2026-09-22 実機報告と受け入れ境界

- 開発者の会話報告: 「概ね機能していそう」。全選択のTalkBack操作は手順の意味が分からず未実施で、「今回は成立していそうなのでスルーでよい」と明示した。対象は案内済みworktreeのcode commit `d88ab4f`（報告時HEAD `90efb6c`。両者の間にcode/dependency/build設定差分なし）。端末の種類と各manual項目の個別結果は報告されていない。
- 全選択の操作名・tap actionはwidget testでPASSし、mutation M402もKILLED。TalkBack実機動作をPASSと書き換えず、今回限りの未確認として記録する。
- UI上の追加指摘: 全選択からの一括解除が無い。ヘッダの×が画面を閉じるのか選択解除なのか紛らわしい。file行のcheckboxの位置・形をリネーム画面と揃えたい。フッタ左下に明示的な「リネーム画面に戻る」ボタン、上部へ保存場所名・戻る矢印・選択件数をまとめる案、場所の帯へフォルダ内一括選択checkboxを置く案が出た。これらは004 REQ-020の範囲選択保証とは別のUI設計として後続taskへ送る。
- 手動手順の修正: TalkBackの「focus / activate」を実際のスワイプと2回タップへ言い換え、各場面の選択0件への戻し方を明記した。code/test/buildは変更していない。
- 独立final-evidence review attempt 2: `gpt-5.6-luna`、exact range `bef8337..f4b7868` — **BLOCKED / `in_review`維持**。成果物欠陥・安全網の穴は追加なし。Android物理端末での項目2〜3・5〜11の個別結果と端末種別が未記録。「概ね機能」では必須実機証拠をPASSにできない。TalkBack項目4は開発者指示により今回は省略し、PASSと記録しない。

## Current state / handoff

- Last checkpoint: app内browserへ全選択・長押しdrag・edge auto-scrollを実装し、T31の仕組みを選択意味から分離して共通化した。machine verificationとmutationはPASS。
- Status: `in_review`。
- Blocker category: Android physical-device evidence pending.
- Evidence revision: code/test `d88ab4f`、2026-09-22の会話報告時HEAD `90efb6c`（code/dependency/build設定差分なし）。
- Waiting for: Android物理端末で行った項目2〜3・5〜11の個別結果と端末種別。TalkBack項目4は今回省略する。
- Requested action: 開発者から、Android物理端末での項目2〜3・5〜11の結果と端末種別を受け取る。
- Next Agent action: 個別結果を受領して同一code/buildとの対応を確認し、`gpt-5.6-luna`へ最終証拠を再照合させる。
