# T39 app内browserの選択・戻る導線を実装する

## 目的

T38で承認されたbrowserの選択・一括解除・戻る導線をAndroid app内browserに実装する。T37の範囲選択とT12の保存場所入口・近道・戻る表示を保ち、利用者が「選択を解除する」と「リネーム画面へ戻る」を取り違えない画面にする。

## 依存と境界

- T38: 仕様・状態表・開発者承認。
- T12: 同じbrowser画面の入口、近道、戻る矢印、空folderの提示。
- T37: 長押しdragと全選択の基盤。
- Android app内browserだけが対象。desktopのOS pickerとrename判定、権限、ファイル変更は対象外。
- T38が決める前に見た目や選択の意味を確定・実装しない。

## machine検証範囲と引き受け先

- widget test: root/下位folder/選択0/一部/全件の導線、全選択からの一括解除、戻る操作と未確定選択破棄の区別、file行のcheckbox配置と選択表示、近道・folder非対象、T37のdrag回帰。
- semantics widget test: 戻る、一括選択、一括解除の操作名とactionを区別する。
- Android物理端末: 上記の見え方、手での選択・解除、TalkBackの読み上げと操作、狭幅と長い場所名。T39が引き受ける。
- desktopはOS picker経路のためmanual対象外。

## 受け入れ証拠

- T38が承認された仕様と状態表に対応するwidget testがPASSし、T12/T37関連testを弱めずPASSする。
- 必要なmutationがKILLED。format/analyze/full test/workspace check PASS。
- Android物理端末のmanual確認PASS。exact rangeの独立review PASS。review modelは開発者指定のluna。
- design土台との差分: T38の状態表で確定した後、適用画面範囲と離れた点・理由をここに追記する。

## Current state / handoff

- Last checkpoint: T38と同時に実装taskとして登録した。
- Blocker category: dependency / T12, T37, T38.
- Evidence revision: dev@bef8337（T37 codeは別worktree）。
- Waiting for: T12、T37、T38の完了。
- Requested action: なし。
- Next Agent action: T38の承認済み状態表を受けて専用branch/worktreeで着手する。
