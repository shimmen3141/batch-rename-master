# T36 app内file browserの範囲選択を定義する

## 目的

Androidのapp内file browserで、現在のfolder内のfileを一括選択し、長押ししたままdragして連続選択できる振る舞いを004 specへ定義する。実装はT37が行う。

この要望は`product-map.md`の将来候補と`T11`の申し送りに残っていた。T11は入口・近道のU1/U2という別の未決定事項を所有しており、T11自身も範囲選択を「単独taskに値する」と記録しているため、承認境界を分ける。

## 入力と依存

- `004 REQ-016`: 選択は同一folder内に限り、folder移動で解除する。
- `008:T31`: 長押しdrag、実在行の矩形、edge auto-scroll、offscreen後のpointer追跡、往復時の今回追加分だけの解除。
- 2026-09-21の開発者判断: T31を活かし、browserの全選択と長押しdrag選択を次に進める。

## 変更範囲

- `specs/004-file-source/spec.md`へREQ-020と代表例を追加する。
- Androidのapp内browserだけを対象とする。desktopはOS pickerの標準複数選択へ委ねる。
- T37を実装taskとして接続する。

## 定義する振る舞い

- 現在のfolder直下にあるfileだけを一操作ですべて選べる。folder・近道は選択対象にしない。
- fileの長押しでそのfileを選び、押したまま通過したfileを連続選択する。
- drag中に既に辿ったfileへ戻ると、そのdragが追加した後続fileだけを解除する。drag開始前から選択済みのfileは解除しない。
- 一覧端で保持すると自動scrollし、新しく通過した実在fileを選ぶ。開始行がoffscreenになっても停止・反転・解除・lift/cancelを追跡する。
- 通常scroll、folder行の操作、checkboxの個別切替を壊さない。
- folder移動時の解除はREQ-016を維持する。

## 受け入れ証拠

- REQ-020と代表例が外部から観測できる言葉で定義されている。
- T37がREQ-020をcoversし、自動test・mutation・Android実機manualを受け持つ。
- 既存REQ-016/017、desktop境界、accessibility代替との関係が明記されている。
- 独立reviewがPASSする。review modelは開発者指定のlunaを使う。
- `workspace.py check specs`がPASSする。

## 人間の決定

- 2026-09-21: 開発者は、現在folderの全選択、T31と同じ往復規則、edge auto-scroll、folder移動時の既存解除、全選択によるaccessibility代替、desktopはOS pickerへ委ねる方針を示した提案に対し「その推奨で進めてください」と承認した。
- 実装はCodex本体が行い、独立reviewはlunaを使う。

## Current state / handoff

- Last checkpoint: review attempt 1はFAIL。REQ-020のVER接続、通常scroll表現、近道除外、Semantics検証、T31依存を補正した。reviewはluna指定で起動したが、reviewerの実行model報告はGPT-6 Codexだったため指定不一致として記録する。
- Status: `done`。
- Blocker category: none.
- Evidence revision: `dev@65fbc3b`.
- Waiting for: なし。
- Requested action: なし。
- Review: attempt 2は`gpt-5.6-luna`でPASS。成果物欠陥・安全網の穴なし。workspace check / JSON / diff check PASS。
- Next Agent action: T36を統合後、T37を着手する。
