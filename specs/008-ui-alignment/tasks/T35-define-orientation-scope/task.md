# T35 横向きを対象にするかを決める

## 目的

**横向きの扱いを決める。** いまは横向きでも一応表示できるが、**文字サイズ最大の横向きで
画面下に縞模様(Flutter の overflow 表示)が出る**。対象にするなら直し、対象にしないなら
**縦向きに固定する**。「直さないまま出る」状態が残らないようにする。

## 受領した観測(2026-09-19、原文)

> 手順4については、フォントサイズ最大でも吹き出しは表示された。手順5については、横向きのフォントサイズ最大でも吹き出しは表示された。ただ、横向きのフォントサイズ最大だと画面下に縞模様が出た。しかし、横向きのフォントサイズ最大など考慮できるものではないと考えている(そもそも横向きを想定する必要もないと思う)ので、今回はこのままでよいと思う。横向きのUIを廃止するなど、タスクにしておくべきなら適切にタスクを立てておいてください。

**開発者は「今回はこのままでよい」と判断している。** ここは後で扱うための記録である。

## 分かっていること

- **縞模様は Flutter の overflow 表示**である(子が親の枠を超えたときに出る黄と黒の帯)。
  どの widget が溢れているかは未特定。**下部の帯(ルール設定と実行)が有力**だが、
  実機の画面写真も widget の特定もまだ無い。
- `008` はこれまで**縦向きの狭幅(320dp)× 文字倍率**を検査の格子にしてきた。
  **横向きは検査していない。**
- `android/app/src/main/AndroidManifest.xml` は `configChanges` に `orientation` を
  含んでおり、**横向きは現状サポート対象として振る舞う**(回転しても再生成されない)。
- **`T30` の吹き出しは横向きでも成立した**(実機)。機械の実測では文字倍率1.6以上で
  出なくなるはずだったが、**実機の最大でも出た** — Android の文字サイズ設定の最大は
  倍率1.5 程度までで、test で使った 2.0 / 3.0 に実機の設定では届かないためと考えられる
  (**未確認の推測である**。必要ならディスプレイサイズ設定と併用して確かめる)。

## 決めること

- **横向きを対象にするか。**
  - (a) **縦向きに固定する**(`AndroidManifest.xml` の `screenOrientation` を `portrait` へ)。
    いちばん安く、検査の格子も増えない。**ただし利用者が横向きで使えなくなる。**
  - (b) **横向きも対象にする。** 縞模様の出どころを特定して直し、
    **横向き × 文字倍率を検査の格子へ加える**(既存の `008` の格子はすべて縦向きである)。
  - (c) **対象外と明記して放置する。** 縞模様は出たままになるので、**採らない**
    (「直さないまま出る」を残さない、という目的に反する)。
- 決めたら **`AndroidManifest.xml` を変えるかどうか**まで含めて記録する。
  **manifest の変更は `.github/workflows` ではないので Agent が行える。**

## 入力と依存

- `T30` の2回目の実機確認(2026-09-19)。
- `specs/008-ui-alignment/plan.md` の決定表。
- **`T30` / `T32` とは独立**(あちらは merge 済みの見せ方の調整)。

## 受け入れ証拠

- 開発者の判断が `plan.md` の決定表に記録されている。
- (a) なら manifest の変更と、横向きにならないことの確認。
- (b) なら縞模様の出どころが特定され、直っていることを widget test が固定し、
  横向きの格子が検査に入っている。

## 縞模様の出どころ(2026-10-04 着手。widget test で特定)

開発者の指示で着手した(原文: 「008 の T35 に着手してください。」)。

**方法**: `DemoApp`(起動直後の demo data・空のルール)を、画面の大きさと `TextScaler.linear` を変えて pump し、
`FlutterError.onError` で overflow を集めた使い捨ての probe(repository には残していない)。
起動直後のメイン画面だけを見ており、browser・modal・sheet は見ていない。

| 画面(dp) | 配置 | overflow が出始める倍率 | 溢れる widget |
|---|---|---|---|
| 640×360(横・狭) | 1ペイン | **1.6**(1.6 で 2px、2.0 で 44px) | 一覧の `Column`(`lib/ui/file_list/file_list_view.dart:300`。見出し・警告帯・folder 行の固定部分が、上の読み込み帯と下部の帯を引いた高さに入らない) |
| 800×360(横・狭) | 1ペイン | **1.9**(2px)、2.0 で 44px | 同上 |
| 915×412(横・幅 ≥ 840) | 2ペイン | **1.9**(54px)、2.0 で 71px | 右のルールの `Column`(`lib/ui/rule_builder/rule_builder_view.dart:78`。案内・点線の枠などの固定の高さ) |
| 360×800(縦) | 1ペイン | 2.0 まで出ない | — |
| 1280×800・960×600・1024×600(横・タブレット)、600×960(縦) | — | 2.0 まで出ない | — |

- **下部の帯ではなかった。** 1ペインでは一覧の固定部分、2ペインでは右のルールの固定部分が溢れる。
- 縞模様は**横向きの電話の高さ(360〜412dp)× 文字倍率 1.6〜1.9 以上**でだけ出る。Android 14 以降の文字サイズ最大(200%)は
  非線形に拡大されるので、本文の実効倍率はこの範囲に入る(実機で出たことと矛盾しない)。
- **高さが 600dp 以上なら 2.0 でも出ない** — タブレットの横向きは今のままで成り立っている。
- `targetSdk` は Flutter 3.44.6 の既定 36。**Android 16 以降は、画面の短辺が 600dp 以上の端末で manifest の向きの固定を無視する**
  (大画面での向きと大きさの制限の廃止)。したがって manifest で縦に固定すると、**固定されるのは電話だけで、
  タブレット・折りたたみの展開時は回転できる**。上の表のとおり、その大きさでは縞模様は出ない。

## 決定(2026-10-04)

開発者の判断(原文):

> 横向きのUIでも、ルール設定画面を毎回開きなおさずに編集できるという点で価値がゼロではないと考え直しました。ただ、優先度は低いので、横向きのUIは残しつつ縦向きに固定し、横向きのUIの調整まで行うかは将来候補としておくことは可能ですか。

- **(a) 電話では縦に固定する。** `android/app/src/main/AndroidManifest.xml` の `MainActivity` に
  `android:screenOrientation="portrait"` を足した。
- **横向きの UI は消さない。** 2ペイン(一覧とルールを並べる)は**向きではなく幅**(`RuleBuilderWorkspace.breakpoint` = 840)で
  切り替わるので、タブレット・折りたたみの展開時(Android 16 以降は固定が無視される)と desktop では今までどおり使われる。
- **電話の横向きを解禁するか**(2か所の溢れを直し、横向き × 文字倍率を検査に加える)は**将来候補**へ送った
  (`specs/product-map.md`)。
- (b)・(c) は採らない。

## 作業記録

- manifest の変更と、固定を source から確かめる test(`test/tooling/android_orientation_test.dart`。`tooling` タグは付けず、
  mutation の command に含まれる)を足した(`feat(asdd-008/T35)` の commit)。
- mutation **M684**(固定を外す)。範囲付き(`flutter test test/tooling/android_orientation_test.dart`)、1件:

```text
command: flutter test test/tooling/android_orientation_test.dart
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M684 | KILLED | android/app/src/main/AndroidManifest.xml | 008:T35 電話の縦固定を外す | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter analyze` No issues、`dart format` 0 changed、`flutter test` **1241 PASS**、`check_mutation_finds.py` PASS(628)。
- **machine 検証の範囲**: manifest に固定が書かれていること。**回転しないこと**(電話)は実機確認が引き受ける
  ([manual-verification.md](manual-verification.md))。タブレットで固定が無視されることは、手元にその端末の確認手段が無ければ確かめない
  (Android の仕様であり、この task の受け入れには含めない)。

### 独立review

reviewer は Sonnet 5(Agent tool、`model: sonnet`。開発者の指定)。実装は Claude Opus 5.5。

- Review attempt 1: `a2fd19c..73068d0` — **PASS** — P0/P1 なし。情報2件(P3 相当)
  - 確認できた点: manifest の変更の正しさ(XML として妥当、`MainActivity` の属性)、2ペインが幅だけで切り替わること
    (`lib/` に向きの分岐が無い)、M684 の再現(KILLED)、probe 表の代表2点の再現(640×360×1.6 で overflow、360×800×2.0 で無し)、
    targetSdk 36 の出所、記録の整合、analyze・format・`flutter test` 1241 PASS・workspace check。
  - reviewer の対照 **CM1**(固定を `<application>` へ移す)→ KILLED。**M685** として表へ取り込んだ(`5afb323`)。
  - 情報: `task.json` の `pullRequest` が null → 216 を記録した(`5afb323`)。
  - 情報: Android 16 の大画面で向きの固定が無視されることは、sandbox から一次資料で確かめられなかった。受け入れに含めていないので
    残余riskとしない。

- Review attempt 2(差分): `73068d0..bbc00e3` — **PASS** — 指摘なし。M685 が CM1 の意図どおりで find が1回だけ一致すること
  (`check_mutation_finds.py` 629 PASS)、M684/M685 の再現(2 KILLED)、`flutter test` 1241 PASS、`lib/`・`android/` が `727fae8` と
  同一であること、記録の整合を確認。
- 連鎖: `a2fd19c..73068d0` PASS → `73068d0..bbc00e3` PASS。以後の記録だけの差分は SELF-CHECK。

### 実機確認(2026-10-04)

- 対象: `lib/`・`android/` が `727fae8` と同一の build(branch HEAD `992cbd2`。`git diff --stat 727fae8 HEAD -- lib android hook src pubspec.yaml pubspec.lock` が空)
- 実施: 開発者(Android エミュレータ)。手順 1〜3
- 結果: **OK**(「確認事項について、問題ありませんでした。」)

## Current state / handoff

- Last checkpoint: 実機確認 OK(2026-10-04、`727fae8` の build)。review 連鎖 `a2fd19c..bbc00e3` PASS、以後は記録だけ
- Status: done
- Next Agent action: なし(PR #216 を ready にして merge する)
