# T02 権限とAPI levelの方針を定義する

## 目的

`MANAGE_EXTERNAL_STORAGE`をどう要求し、許可されないときに何が起きるか、どのAndroid versionを対象にするかを、外部から観測できる形で決める。**以後のtaskはすべてこの決定に乗る。**

## 入力と依存

- [`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)(accepted)。
- `developer.android.com/training/data-storage/manage-all-files`(`Environment.isExternalStorageManager()`、`Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`)。
- 現在の`minSdk`は`24`(Flutterの既定)。
- `renameat2`が**bionicのwrapperとして**公開されたのはAPI 30とされるが、これは検索結果の要約であり原文を読めていない(**[未到達]**)。**しかも生の`syscall(SYS_renameat2, ...)`を使えばwrapperの有無に依存しない。** `T01`のspike binaryは`android24`向けにビルドして動作した。**制約はlibcではなくkernelとfilesystemの側にある。**

## 決めること

**人間の決定が要るものを先に挙げる。** ADR-002が「未解決のまま残る決定」としたものを含む。

1. **`minSdk`をどうするか。** 少なくとも3案ある。**2案の二択として人間へ出さない。**
   - (a) 30へ上げて24〜29の端末を切る。最も単純だが端末を失う。
   - (b) 24のまま**生のsyscall**で呼び、`renameat2`が使えない端末を**実行時に検出して**未対応へ落とす。端末を失わないが、「同じappでも端末によって改名できない」状態を作る。
   - (c) 24のまま**API levelで一律分岐**し、30未満は無条件に未対応。(b)より単純だが、実際には動く端末も切る。
   - (b)(c)は利用者へどう説明するかまで決める。**どれを採っても、対応可否の判定は実測に基づくこと**(API levelは代理指標にすぎない)。
2. **権限が無いときの振る舞い。** file一覧の読み込み自体をさせないか、読めるが実行時に未対応を返すか。
3. **権限を要求する時機。** 起動時か、読み込みを試みたときか、実行を押したときか。
4. **権限を拒否されたあとの導線。** 設定画面へ再度誘導するか、一度断られたら黙るか。

## 変更範囲

- **新規[`specs/013-safe-android-rename/spec.md`](../../spec.md)** を作成した。権限はsource(004)と実行(005)の両方に関わるため、どちらかへ追記すると片方の仕様が他方の都合で膨らむ。独立させた。
- 改名そのものの正しさは**005 contractが正本**であり、013は緩めない(INV-001)。004/005 specは`T03`/`T04`が触る。
- `AndroidManifest.xml`の権限宣言は**このtaskでは行わない**(T06)。

## 受け入れ証拠

- 上記4点すべてに、外部から観測できる形で答えている。
- **人間による承認**(仕様の新規approvedまたは既存specの再承認)。
- 承認されたREQ IDを、T05/T06/T07/T08の`task.json`の`covers`へ書く。
- **Playのpolicy原文との突き合わせを人間が済ませていること。** ADR-002は「一括改名appがpermitted usesに入るか」を`[未到達]`のまま残している。**T05〜T07の実装へ投資する前にこのgateを通す。** 通らなければ候補Eは配布できず、Android未対応維持へ戻る(ADR-002の退避経路)。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-13 / 着手。`T01`のP2×4(結論節の未検証が7項目のうち4つ、plan.mdの未決定が2件、`Evidence revision`の二重括弧とmerge前base、trailing whitespace)を先に解消した。
- 2026-08-13 / **開発者が`minSdk`を「24のまま実行時検出」と決定。** API levelは対応可否の代理指標として弱く、実際に効くかを決めるのはkernelとfilesystemであるため。
- 2026-08-13 / `spec.md`をdraftとして起草した。**preflight(REQ-005〜008)がこのtaskで最も重要な設計判断である。** `renameat2`が`EINVAL`/`ENOSYS`を返す端末は安全(実体不変)だが、**フラグを黙って無視して上書きする端末は実行時に検出できない**(`T01`のspikeの`C)`)。したがって実行前に対象folderで実測する必要がある。対照(flags=0)を含めるのは、`T01`のreviewで「片側だけでは因果を示せない」と指摘されたのと同じ理由による。
- 2026-08-13 / **`minSdk`の判断材料を整理し、人間へ問うた。** `renameat2`のkernel実装はLinux 3.15で入っており、bionicのwrapperが無くても生syscallで到達できる(`T01`のspike binaryは`android24`向けにビルドして動作)。**したがってAPI levelは対応可否の代理指標として弱い。** 実際に効くかを決めるのはkernelとfilesystem(FUSEの下がext4かFATか等)であり、これはAPI levelと独立に端末ごとに変わる。

## Current state / handoff

- Last checkpoint: `spec.md`をdraftとして起草した。人間の承認待ち
- Blocker category: decision
- Waiting for: **`spec.md`の承認**(draft → approved)と、Playのpolicy原文との突き合わせ
- Requested action: `spec.md`のREQ-001〜009とINV-001〜003を確認する。特にREQ-005(preflight)が受け入れられるか
- Evidence revision: `dev@70e4287` + ADR-002
- Next Agent action: 承認されたらREQ IDをT05〜T08の`covers`へ書き、`T03`(Androidの読み込み導線)と`T04`(005契約)へ進む。差し戻しなら該当REQだけ直す
