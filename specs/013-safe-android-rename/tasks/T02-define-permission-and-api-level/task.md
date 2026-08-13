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

- 新規`specs/013-safe-android-rename/spec.md`(Androidのstorage権限に関する観測可能な振る舞い)。
- または004/005 specへの追記。**どちらにするかもこのtaskで決める**(権限はsourceと実行の両方に関わるため、独立したspecの方が収まりが良い可能性がある)。
- `AndroidManifest.xml`の権限宣言は**このtaskでは行わない**(T06)。

## 受け入れ証拠

- 上記4点すべてに、外部から観測できる形で答えている。
- **人間による承認**(仕様の新規approvedまたは既存specの再承認)。
- 承認されたREQ IDを、T05/T06/T07の`task.json`の`covers`へ書く。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@f97a2cc` + ADR-002
- Next Agent action: 「決めること」の4点へ案を作り、人間へ一度に問う。`minSdk`は他の3点の前提になるので最初に置く
