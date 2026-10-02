# 手動確認: ルール設定buttonのチップの空白(Androidエミュレータ)

`008:T55` で、ルール設定buttonのチップの値の行の高さを、描く文字によらず一定にした。

**対象buildは、`lib/`・`hook/`・`src/`の内容が commit `__COMMIT__` と同一のもの**である。branch
`asdd/008-ui-alignment/T55-rule-chip-symbol-overflow` のHEADからbuildすればこれを満たす。
**code・dependency・build設定が変わったら、この結果は再利用しない。**

端末のフォントで字形ごとに行の高さが変わることは test で再現できないので、実機で見る。

## 使う端末と準備

- 起動と`flutter run`は`/workspace/docs/development/emulator-verification.md`のとおり。branchの移動は不要
  (`/workspace` はすでにこのbranchにある)。host側で`flutter pub get` → `flutter run`する。
- 一覧にファイルが何件か読み込まれていればよい(前回の確認のファイルのままでよい)。

## 1. 空白を含む自由テキスト

1. ルールのチップを全部消し、「＋ 自由テキスト」で `same `(**最後に半角の空白**)と入れて「追加」し、一覧へ戻る。

**こうなってほしい**

- ルール設定buttonのチップに `same␣` と出て、**黄色と黒の縞や「BOTTOM OVERFLOWED」の文字が出ない**。
- チップの高さが、他のチップ(たとえば「＋ 元の名前」を足したとき)と揃っている。

2. 同じく `a b`(間に空白)、全角の空白だけ(`　`)の自由テキストも足してみる。

- どれも縞や「OVERFLOWED」が出ない。

## 報告

結果は会話で自由に書いてよい。問題があったときだけ、どの手順で、実際に何が見えたかを添えてほしい。
