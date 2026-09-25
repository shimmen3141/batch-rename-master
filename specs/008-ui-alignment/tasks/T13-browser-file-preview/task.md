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

## 決定(2026-09-24)

| 論点 | 決定 | 決定者 |
|---|---|---|
| テキストのpreview | **入れない。画像・動画だけ**(`T07`の基盤を行へ繋ぐ)。行の狭い枠では先頭の数文字しか読めず、binary判定を新設する割に得るものが少ない。**テキストは将来候補**として`product-map.md`へ残す | 開発者 |
| cacheの寿命 | **browserを開くたびに専用の`CachedFilePreview`を作る**(一覧のcacheと共有しない)。`BrowserEntry`は更新日時を持たず、cacheのkeyに更新日時が入るため、共有すると一覧のkeyと食い違い、同じsession中に中身が変わったfileの古いthumbnailが残りうる。寿命を画面1回分にすれば起きない | Agent |

上の「このtaskに残るもの」のうち、テキストの項は**この決定で対象外になった**。manual手順の「中身のあるテキストfile」「binaryだがテキスト拡張子のfile」も同じく対象外にする(テキストはpreviewの対象外 = 種別アイコンになることだけを見る)。

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

## 実装の記録(2026-09-24)

実装は Claude Opus 5.5。起点は`dev`@`15a15f0`、branch `asdd/008-ui-alignment/T13-browser-file-preview`。

- `lib/ui/file_source/storage_browser_view.dart`: file行の`leading`へ一覧と同じ`RowPreviewView`を置いた。`BrowserEntry`から`FileEntry`(名前・元場所ハンドル=path。日時と大きさは埋め草 — portは使わない)を作って渡す。`StorageBrowserView`は任意の`preview`を受け取り、`null`なら種別アイコンだけ。
- `lib/main.dart`: browserを開くたびに`CachedFilePreview(const KindRoutingFilePreview())`を渡す(上の決定)。
- **件数の多いfolder**: `ListView(children:)`は行のwidgetを作っても、**stateを持つ子は見えている分(とcache extent)しかbuildしない**ので、`RowPreviewView`の要求も見えている行の分だけになる(widget testで300件中30件未満を確認)。同時実行数と件数の上限は`T07`の`CachedFilePreview`が持つ。
- 004 specは変えていない(REQ-017: previewは絞り込みではなく、出せないfileも隠さず並べ替えない)。

### 自動検証

- `flutter test test/spec_004_file_source/storage_browser_view_test.dart`: 67件PASS(T13で4件追加: thumbnail・出せない・読めないの提示と並び順 / portへpathを渡しfolderには要求しない / 300件で見える分だけ要求 / previewの上を押しても選択が切り替わる)。
- `flutter test`: 993件PASS。`flutter analyze`: No issues。`dart format`: 0 changed。

### mutation

`command`を`flutter test test/spec_004_file_source/storage_browser_view_test.dart`へ絞り、T13で足した3件と、file行の見た目・semanticsを守る既存3件を回した:

```text
M414 | KILLED | lib/ui/file_source/storage_browser_view.dart | file行のcheckboxを円にしない | exit 1
M415 | KILLED | lib/ui/file_source/storage_browser_view.dart | 選択済みのfile行の面を染めない | exit 1
M418 | KILLED | lib/ui/file_source/storage_browser_view.dart | file行の名前とcheckboxを別々のsemantics nodeにする | exit 1
M431 | KILLED | lib/ui/file_source/storage_browser_view.dart | file行からpreviewの枠を外す | exit 1
M432 | KILLED | lib/ui/file_source/storage_browser_view.dart | 渡されたportを使わない | exit 1
M433 | KILLED | lib/ui/file_source/storage_browser_view.dart | 元場所ハンドルにpathではなく名前を渡す | exit 1
6 mutations: 6 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。browser関連の全mutationの`find`が現行コードに1回ずつ一致することも確かめた。)

**安全網の穴(受容)**: `lib/main.dart`がbrowserへpreviewを渡すこと自体はtestで固定していない(composition rootのwidget testが無い)。落ちても「previewが出ない」だけで、AGENTS.mdのFAIL条件2(データ損失・無断置換・偽の成功・権限逸脱・互換性破壊)に当たらない。**manualの0が観測する**(引き受け先はこのtaskのmanual)。

## manual確認の結果

### 1回目(2026-09-25、Androidエミュレータ、debug build、`lib/`は`ba6e815`)

開発者の報告(会話):「確認事項は全体的にほとんど問題なかったが、件数の多いフォルダにおいての素早いスクロールだけは引っかかった。ゆっくりだとうまくスクロールできた。ただ、PCの性能やエミュレータの挙動による部分もあるかもしれない」。

| 項目 | 結果 |
|---|---|
| 0〜1、3、4 | 問題なし(個別の指摘なし) |
| 2 件数の多いfolder | **素早いscrollで引っかかる。** ゆっくりなら問題ない |

**切り分け(Agent)**: `flutter run`の既定は**debug build**(JIT)で、scrollの滑らかさを判断する材料にならない。また`008:T07`の同じ観測(N-5)で、開発者はscrollの引っかかりを**previewより前からのもの**と判断している。**開発者の決定(2026-09-25)で、release buildで2だけを再確認する。** 滑らかならdebug由来として記録してmergeへ進み、引っかかるなら`dev`(previewの無いbrowser)のrelease buildと比べてT13が原因かを分ける。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。AGENTS.mdの差分review(連鎖)に従う。

- attempt 1: `15a15f0..de16159`(全範囲、implementation) — **PASS、指摘なし**。決定(画像・動画だけ、開くたびの新しいcache)とREQ-017、T07の基盤の区別・古い応答の破棄・同時実行上限の維持、T39/T40の行・選択・semantics、MediaStoreを使わないこと、300件のtestの妥当性、manualのコマンドの正しさと既存fileを消さないこと、記録の一致、full test 993件PASSを確認された。reviewerの範囲付きmutation 5件(M414・M418・M431〜M433)と対照1件はKILLED。
  - reviewerの対照`R-T13-FAILED-VS-UNSUPPORTED`(読めなかったfileを「出せない」と同じアイコンにする)を`M434`として`tool/mutations.json`へ取り込んだ。
  - **manualの結果はまだ無い**。受領後、`de16159`以後の差分をreviewする(差分review)。

## Current state / handoff

- Last checkpoint: manual 1回目(debug build)を受領。素早いscrollの引っかかりだけが残り、release buildで再確認する(2026-09-25)。
- Blocker category: 人間のmanual確認(Androidエミュレータ)。
- Evidence revision: base `dev`@`15a15f0`、code `ba6e815`。
- Waiting for: release buildでの手順2の結果(`lib/`が`ba6e815`)。
- Requested action: 人間がworktreeから`flutter run --release -d <emulator>`し、`many`を素早くscrollして結果を知らせる。
- Next Agent action: 結果を記録し、`de16159..HEAD`の差分review(記録だけならSELF-CHECK)→ PRをready → CI → merge判断。
