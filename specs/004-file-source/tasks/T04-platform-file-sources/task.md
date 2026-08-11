# T04 実 FileSource(Android SAF + Windows ピッカー)+ 実データ入口配線(ホスト検証)

## 目的

- 実 FileSource(Android SAF + Windows ピッカー)+ 実データ入口配線(ホスト検証)

## 入力と依存

- 依存: T03
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- Android(SAF フォルダ URI 権限 + `OPEN_DOCUMENT` 複数選択、必要な永続化権限)/ Windows(ピッカー)の `FileSource` 実装を追加(プラグイン選定は実装制約として ADR)。可能な範囲でモック/ユニット test を置く。
  - **返す全エントリに `sourceHandle` を必ず設定する**(実 URI/パス)。null は作業セットのハンドル重複排除の対象外になり、同一ファイルが多重に積まれるため(T2 の申し送り)。
  - アプリ入口で実 `FileSource` を注入し、実ファイルを 002 の作業セットに流す。`flutter analyze`/`dart format`/`flutter test` PASS。
  - 003 T6 の修正を受けて、読み込み入口のバーが作業セットを購読し直し、**空のときは「すべて外す」を無効表示**にする。あわせて T6 で不正確になったコメントを実態に合わせる(2026-08-04 開発者指示で T4 に含める)。
  - **実権限・実読み込み・複数フォルダ蓄積(別フォルダの選択を重ねて1リストになる)の実機/エミュレータ確認はホスト側**(手順は emulator-verification.md。T4 の実装に合わせて手順を更新する)。`.github/workflows` 変更が要る場合は人間に依頼。
- 参考: T1、T3、PRD §5、`docs/development/emulator-verification.md`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-04 / 申し送り: (1) **Android の個別ファイル選択のみ `sourceLocation` が null**(親フォルダが分からないため)。デスクトップは親フォルダ名が入るのでプラットフォーム間で非対称。REQ-009 は should かつ「場所文字列の形は自由」のため違反ではないが、ホスト検証で不具合と誤認されないよう手順書にも明記した。(2) 起動直後のサンプル9件は `sourceHandle` を持たないため行の × が出ない(全消去のみ)。実データ入口が本番化したので、サンプルを残すかは製品判断。(3) **実権限・実読み込み・複数フォルダ蓄積の確認はホスト側**(手順は emulator-verification.md を T4 の実装に合わせて更新済み)。
  - 2026-08-04 / PR #76 作成(Closes #54)。マージ+ホスト検証待ちで停止。
  - 2026-08-04 / 計画変更 / T4 の受け入れ条件に「返す全エントリに `sourceHandle` を必ず設定する」を追加(T2 の申し送り(2)。承認済み 004 REQ-002 の詳細化であり矛盾のない追加)。
  - 2026-08-04 / 計画変更 / T4 の**変更対象と受け入れ条件を更新**(開発者確認済み: 「T4に含めるのが自然だとあなたが判断したら含めてください」)。読み込み入口バーの購読復活(空なら「すべて外す」を無効表示)+ T6 で不正確になったコメント修正を T4 に含め、変更対象に `lib/ui/file_source/file_source_bar.dart` / `specs/004-file-source/decisions/` / `docs/development/emulator-verification.md` /(`flutter pub get` が生成する plugin registrant)を追記。**実装前に書くべき手続きが遅れたため verifier に逸脱として指摘され、その場で文書化した**(FINDINGS 記録済み)。
  - 2026-08-04 / T4 着手 / shimmen3141。Issue #54 を assign(claim)、ブランチ asdd/004-file-source/T4。
  - 2026-08-04 / T4 完了 / **Android = `saf_util`**(`SafFileSource`: `pickDirectory` で永続化可能な書き込み権限を取得 → `list`、`pickFiles` で複数選択。ハンドル= SAF document URI)、**デスクトップ = `file_selector`**(`DesktopFileSource`: `getDirectoryPath`/`openFiles` + `dart:io` の `FileStat`。ハンドル=絶対パス)、`createPlatformFileSource()` で選択し未対応 PF は `UnsupportedFileSource` が `Failed` を返す。`lib/main.dart` を fake から実 `FileSource` へ差し替え。**作成日時は両実装とも常に不明**(代替しない)。ADR-001 にプラグイン選定(決め手は **rename の有無** — 最人気の `saf` は rename が無く 005 で行き詰まる)を記録。テスト +18(合計 257)。**257 tests PASS / analyze 0 issue / format PASS**。verifier PASS(2回目。1回目の指摘4件—スコープ文書化漏れ・ADR の minSdk 誤り(21→**24**)・コメントと実装の不一致・ホスト検証手順の誤認リスク—を修正し、追加テストはミューテーションで捕捉力を実証)。
  - 2026-08-05 / ホスト検証(T4)/ 実機で動作確認。**実 SAF は正常に動いた**が、導線に3つの問題が判明: (a) フォルダ選択で許可した瞬間に全件が自動追加され「選んでから追加する」感覚と合わない、(b) 「フォルダを開く」と「ファイルを選ぶ」の2ボタンが直感的でない、(c) **複数フォルダにまたがる一括リネームは需要が薄い**(同じフォルダの同種ファイルをまとめるのが実際の用途で、別フォルダのファイルはリネームしても同じ場所に並ばない)。加えて「作成日時: 不明」の赤字が常時出て煩い、との指摘。→ 決定事項に2026-08-05 の4行を追加し、**T7(仕様更新)/ T8(実機スパイク)/ T9(実装)** を追加。
