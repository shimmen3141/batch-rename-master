# Development finding: SAF rename fakeがproviderの競合意味論を隠した

- 観測日: 2026-08-09
- 観測した作業: `complete-rename-execution` / `platform-rename-adapters` / PR #116独立review
- 改善先: project
- 関連Issue・commit・artifact: Issue #96、PR #116、`specs/005-rename-exec/decisions/ADR-001-android-saf-rename-safety.md`

## 観測した事実

既存testの`FakeRenameExecutor`と注入した`SafRenameOperation`は、同名targetがあれば`nameConflict`を返し、要求名どおりの成功だけを返した。実際のAndroid `DocumentsContract.renameDocument`はproviderが別名を選べ、AOSP filesystem providerの候補名選択と通常renameの間には外部競合raceがある。さらに`saf_util 3.1.0`はfile renameの原因例外をgeneric errorへ変換する。

期待はINV-002とOP-004どおり、既存targetを置換せず、失敗時に実体が不変であることだった。実際にはfakeだけが本物より強い保証を供給し、自動testと初期reviewがproduction境界の欠落を検出できなかった。

## 影響とworkaround

- 影響: provider依存の別名成功、結果と実体の不一致、競合raceによる既存file置換の可能性を、Android production adapterが持ち込む設計になった。
- その場のworkaround: Android SAF production renameをprovider call前の`unsupportedPlatform`へ変更し、desktopだけを成功可能な実renameとして検証する。Android成功経路は別unitへ分離する。

## 仮説と改善案

- 仮説: 外部portの成功値だけを実機spikeし、失敗時・競合時・並行時のprovider契約を仕様化しなかったため、fakeが過剰に親切になった。
- 改善案: irreversibleな外部I/O adapterでは、採用前に「成功値、失敗分類、同名競合、外部race、失敗時不変」を一次資料と実環境で検査する。fakeは未証明の保証を追加せず、保証不能ならproductionをunsupportedとして扱う。

## 改善結果

`behavior-contract.json` revision 2、ADR、production SAF adapterのnegative test、同一buildのAndroid無変更手動確認へ接続した。将来設計は`development-units/design-safe-android-rename-boundary/`で調査する。
