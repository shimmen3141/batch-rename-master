# Development finding: 参考designが正本の外にあり、配置の逸脱を誰も検出できなかった

- 観測日: 2026-08-12
- 観測した作業: 005 T09着手時の現在地確認と、T04(commit `9a0e0e1`)の再検査
- 改善先: project(AGENTS.mdの正本一覧と、005の契約)、およびASDD plugin(review観点)
- 関連artifact: `docs/design/Bulk Renamer.html`、`specs/005-rename-exec/contracts/behavior-contract.json`、`lib/ui/file_list/file_list_view.dart`

## 観測した事実

005 T04が、実行ボタンを`_SortBar`直下=ファイル一覧の上へ置いていた。`docs/design/Bulk Renamer.html`では、ルール設定ボタンと実行ボタンは一覧の下の固定バーへ縦積みされる。さらに`RuleBuilderWorkspace`が別のルール編集バーを持っていたため、designが1つにまとめている導線が画面の上下へ分かれていた。

この逸脱は次のどれでも検出されなかった。

- `behavior-contract.json`(Strict、revision 2、approved)は配置に言及していない。REQ/INV/OP/SM/NFRのどれにも当たらないため、仕様違反にならない。
- `flutter analyze`、`dart format`、`flutter test`のいずれも配置を検査していない(T04時点で配置を固定するtestが無かった)。
- T04のcommit `9a0e0e1`はASDD trailerの無い英語messageで、`Checkpoint`も`Evidence`も無い。

結果として、人間が画面を見て「リネームボタンが下から上へ移動している」と気づくまで、`dev`へmergeされた状態で残っていた。

さらに、配置をdesignどおりへ直した結果、実挙動の後退が1件顕在化した。結果toastが下部バーを覆い、undo buttonがhit testに当たらなくなっていた(`Offset(726.8, 564.0) would not hit test`)。toastの既定表示4秒に対しundo窓は5秒なので、取り消せる間ずっと押せない。これはT04の配置のままなら起きなかった問題で、逸脱を放置した期間が長いほど、直したときの副作用も見えにくくなることを示している。

## 期待していた動きと実際の動き

- 期待: 利用者から観測できる成果に参考designが含まれるなら、逸脱がreviewかtestのどこかで止まる。
- 実際: AGENTS.mdの「正本」一覧に`docs/design/`が入っていないため、reviewの参照先にも受け入れ証拠にもならず、素通りした。

## 影響とworkaround

- 影響: 「利用者から観測できる正しさ」を契約が持つ建前だが、配置・導線のまとまりは契約に書かれず、designにしか無い。両者の間に検査されない領域がある。
- 影響: 別AIやsessionが実装すると、designを読まないまま契約だけを満たす実装になりやすい。今回はそれが起きた。
- workaround: T09で配置をdesignへ揃え、`configure-rule`と`rename-action`の上下関係をwidget testで固定した。以後、同じ位置ずれはtestで落ちる。

## 仮説と提案

- AGENTS.mdの正本一覧へ`docs/design/`を明示し、「配置・導線のまとまりはdesignが正本、判定と文言は契約が正本」と役割を分ける。契約へ座標やpixelを書き込むのは避ける。
- 契約側には、配置そのものではなく「ルール設定と実行が同じ操作面にある」程度の観測可能な言明だけを足す案もある。ただしT08で承認済みのrevision 2を再承認する必要があるため、費用対効果は人間判断。
- ASDD pluginのreview観点(`review-task`の「逸脱」)に、「仕様正本に書かれていないがprojectがdesign正本を持つ場合、そこからの逸脱も見る」を一行入れると、project固有の設定なしで効く。
- 一般化: 「契約に書かれていない=自由」ではなく「契約に書かれていない正本があるか確認する」をreviewの既定にする。

## 改善結果

未対応。projectのT09では配置をtestで固定するところまで対処した。正本一覧の更新はAGENTS.mdの変更にあたるため人間へ依頼する。
