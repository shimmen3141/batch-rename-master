# 008 / T63 manual確認: 変更前後をつなぐ矢印

- 対象 branch: `asdd/008-ui-alignment/T63-row-name-arrow`
- 対象 commit(code): `2ec1184` 以後(この後の commit は `specs/` の記録だけ)
- 起動手順: [`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。branch の移動は不要(`/workspace` がこの branch にある)

## 手順と期待結果

1. 写真を数件読み込み、ルールを入れて変更後の名前が出る状態にする。
   - 変更前後をつなぐ矢印が、**軸が長く矢じりが小さい**形で、白に近い色。以前(短い軸に大きな矢じり)より軸が目立つ。
   - 矢印と変更後の名前の間が詰まりすぎ・空きすぎていない。**大きさや間を変えたければ伝えてほしい**(今は大きさ 18dp、間 2dp + glyph の余白)。
2. 補足情報の字下げ(縦線ごと、矢印の左端から少し右)が崩れていない。

## 結果

未実施。結果は会話で自由に伝えてもらい、Agent が task.md へ記録する。
