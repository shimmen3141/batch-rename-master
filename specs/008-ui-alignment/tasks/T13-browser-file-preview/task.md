# T13 browserのファイル行にpreviewを出す

## 目的

`013:T07`の実機確認で開発者が挙げた**U4**を実装する。app内file browserの選択画面で、
**画像やテキストの中身が行から分かる**ようにする。

## 入力と依存

- **観測の出所**: [`013:T07`のtask.md](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/task.md)
  「受領したUIの改善点」の U4。原文は「ファイルにチェックボックスがあるが、画像や
  テキストのプレビューが表示されるようにしたい」。
- **`T07`**(preview の基盤を作った側)。**ここは依存edgeにした** — 下記。
- `T12`(同じ画面の行を作り直すため、**後に着手する**)。**ここは依存edgeにした。**
  `T07`/`T08`の場所の提示は「どちらが先でも成立する」ため edge にせず「後の側が先の結果に
  合わせる」で解いているが、**preview は行のlayoutそのものを変える**ので、先に入れると
  `T12`が作り直す分が丸ごと無駄になり、**manual確認も2回要る**。
  **ただし下の「先に決めること」(調査)は`T11`の承認も`T12`の完了も待たない。**
  `T12`の着手中に並行して進めてよい。
- 004 spec REQ-017(絞り込まない)。**previewは絞り込みではない**ので要求とは両立するが、
  「previewを出せなかったfile」を隠したり並べ替えたりしないこと。
- `013 ADR-002` の権限境界。**MediaStoreは使わない**(010 写真・動画sourceの領域であり、
  権限モデルが別)。

## 先に決めること(調査) — **`T07`が埋めた(2026-08-27)**

**もう調査から始めない。** 開発者の決定で、preview の基盤は `T07` が作り、このtaskは
**それをbrowserの行へ繋ぐだけ**になった(`plan.md` の決定表 2026-08-27)。画面は違うが
仕組みは同じで、二度作るのを避けるためである。

`T07` が作ったもの(`lib/data/preview/`)。

| | |
|---|---|
| `FilePreviewPort` | `thumbnail(entry, maxEdge:)` を返す port。**例外を投げない** |
| `PreviewReady` / `PreviewUnsupported` / `PreviewFailed` | 「preview がある」「無い」「読めなかった」を**型で分ける**。潰さないこと |
| `ImageFilePreview` | 画像。decode 時点で縮めるので、元が何MBでも保持量は上限で決まる |
| `MethodChannelVideoPreview` | 動画。**OS を判定せず**、channel が応えなければ対象外を返す |
| `KindRoutingFilePreview` | 拡張子で振り分ける。preview を出さない種別は**開きに行かない** |
| `CachedFilePreview` | 件数上限の LRU、同時実行数の上限、進行中の重複をまとめる。**失敗も覚える** |
| `filesystemPathOf` | ハンドルが SAF の document URI なら `null`。`013 ADR-002` の退避経路を壊さない境界 |
| `RowPreviewView` | 一覧の行側の widget。**古い応答を破棄する**仕組みを含む |

当初ここに書いていた4つの論点(数百件でのメモリと速度 / 遅延読み込みと上限と cache /
binary を text として出さない判定 / 「無い」と「読めなかった」の区別)のうち、**最後の
3つは `T07` が閉じた**。

**このtaskに残るもの。**

- **テキストの preview**(U4 の原文にある)。`T07` は画像と動画だけを実装した
  (開発者決定)。text を足すなら `FilePreviewPort` の実装を1つ増やし、
  `KindRoutingFilePreview` の振り分けへ加える。**先頭何byteを読むか**と
  **binary を誤って text として出さない判定**はこのtaskが決める。拡張子で決めるなら
  004 の「判定を新設しない」方針との関係を書くこと。
- **browser の行への適用。** `storage_browser_view.dart` の行は `BrowserEntry` を持ち、
  一覧の行(`FileEntry`)とは型が違う。port の入口を合わせる必要がある。
- **`013:T07` が入れた既存testが継続 PASS すること。**

## 変更範囲

- `lib/ui/file_source/storage_browser_view.dart` の file 行。
- **`lib/data/preview/` の port を使う。新しく作らない**(`T07` が作った)。
  browser の行が持つ `BrowserEntry` から port の入口へ渡す形だけを足す。
- text の preview を入れる場合は `FilePreviewPort` の実装を1つ増やす。

## 受け入れ証拠

- previewの有無・失敗・大きなfolderでの挙動を widget test / unit test で検査する。
- **`013:T07`が入れた既存testが継続PASSする**(絞り込まないこと、選択が同一folderに
  限られること)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の見え方と**速度**を確認する。
  **件数の多いfolder**(DCIM等)を対象に含める。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-25 / `013:T07`の実機確認(U4)を受けて定義。開発者が「U1〜U5をすべてtask化する」
  と決定した。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手。**2026-08-27 に`T07`がpreview基盤を作ったので、調査から始める必要は無くなった**
- Blocker category: dependency
- Waiting for: `T12`(同じ行を作り直すため)。`T07`の基盤は済み
- Requested action: なし
- Evidence revision: `dev@ae59859`(定義)、基盤は`008:T07`(PR #159)
- Next Agent action: `T12`の後に着手し、`lib/data/preview/`のportをbrowserの行へ繋ぐ。**textのpreviewを入れるかを最初に決める**(残っている論点はそこだけ)
