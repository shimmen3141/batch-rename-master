# Development finding: container内のFlutterが android/local.properties を書き換え、Windows hostのbuildを壊した

- 観測日: 2026-09-22
- 観測した作業: `008:T12` の手動確認のため、開発者がWindows hostで `flutter run` を実行した
- 改善先: AI container構成(`compose.ai.yml`)、`ai-sandbox-setup`、projectのtooling
- 関連artifact: `android/local.properties`、`scripts/clear-container-local-properties.sh`

## 観測した事実

host の `flutter run` が、共有された `android/local.properties` の
`flutter.sdk=/home/dev/flutter`(container内のFlutterのpath)を参照して失敗した。

container内で再現した。**`flutter test` を1回動かすだけで書き換わる。**

```console
$ sed -i 's|flutter.sdk=/home/dev/flutter|flutter.sdk=C:\\flutter|' android/local.properties
$ flutter test test/tooling
$ cat android/local.properties
sdk.dir=C:\\Users\\...\\Android\\sdk
flutter.sdk=/home/dev/flutter      # ← 書き戻されている
```

`android/local.properties` は `android/.gitignore` で ignore された**機械ごとの設定**だが、
`compose.ai.yml` が作業ディレクトリをhostと共有しているため、**containerとhostが同じ1つのfileを奪い合う**。
`sdk.dir` はhostのAndroid SDK、`flutter.sdk` はcontainerのFlutterという、どちらの環境でも成り立たない
状態になっていた。

## 影響

- **hostのAndroid buildが壊れる。** AI containerではAndroid buildができないので、手動確認は必ずhostで行う —
  つまり**手動確認を依頼するたびにこの問題に当たる**。
- 壊れ方が「共有fileの中身」なので、branchやcommitをいくら確かめても原因に辿り着かない。

## その場の対処

- 書き換わった `android/local.properties` を削除した。**hostのFlutterが作り直す**(git ignoreされた生成物である)。
- `scripts/clear-container-local-properties.sh` を足した。**`AI_SANDBOX=1` で、かつ `flutter.sdk` が
  POSIX path のときだけ** file を捨てる。hostで走っても、hostが書いた値(`C:\...`)は触らない。
  3つの分岐(container由来を消す / host由来を残す / `AI_SANDBOX` 無しでは何もしない)を実際に動かして確かめた。

## 採らなかった案: Claude Codeのhook

`PostToolUse`(Bash)で上のscriptを毎回走らせる案は、**Agentからの設定変更が自己変更ガードで拒否された**うえ、
**開発者が「Claude以外でも使えるようにするため」に見送ると決めた**(2026-09-22)。
Codexや人間が直接`flutter`を動かしたときには効かないので、**tool非依存のcompose側で閉じる**。

scriptは残す — **手で走らせる復旧手段**として使えるし、compose側の対応が入るまでの当座の手当てになる。

## 採る案: compose側で覆う(人間の作業)

hookは「書き換わった後に消す」対症である。**そもそも共有しない**ほうが確実で、次が候補になる。

- `compose.ai.yml` で `android/local.properties` だけを**anonymous volumeで覆う**
  (`- /workspace/android/local.properties`)。containerが書いてもhostへ出ない。
  `compose.ai.yml` はread-onlyなので**人間の作業**である。
- 同じ型の副作用は他にもありうる(`.dart_tool/`、`build/`、`.flutter-plugins-dependencies` など、
  container固有のpathを書く生成物)。**hostのbuildが壊れたときは、まずこの型を疑う。**
  一般化先の `ai-sandbox-setup` にも、Flutter profileの既知の落とし穴として足す候補である。

## 改善結果(2026-09-22)

`compose.ai.yml` へ次の1行を足し、開発者がDev ContainerをRebuildした。

```yaml
      - ./android/local.properties.ai:/workspace/android/local.properties
```

**単一fileのbind mountで覆う形**を採った。匿名/名前付きvolumeは必ずdirectoryとして作られるので、
fileであるこのpathには使えない。逃がし先(`android/local.properties.ai`)はhost側にあらかじめ空fileとして
作っておく必要がある — 無いとDockerがdirectoryを作ってしまう。`android/.gitignore`へも足した。

**検証(container内)**:

```console
$ findmnt -T android/local.properties -o TARGET,SOURCE
TARGET                              SOURCE
/workspace/android/local.properties C:\[/Users/.../android/local.properties.ai]
$ cat android/local.properties
flutter.sdk=/home/dev/flutter
```

container内の`android/local.properties`の実体は逃がし先のfileで、**hostの`android/local.properties`は
containerから見えない**。**Rebuild後に`flutter test`がエラーなく通った**(開発者報告: `All tests passed!`)ので、
「Flutterがこのfileをrenameで置き換えるならEBUSYになる」という懸念も外れた。

host側では次で確かめられる。

```powershell
Get-Content android\local.properties.ai   # container の書き込み先。flutter.sdk=/home/dev/flutter
Get-Content android\local.properties      # host の値(C:\...)のまま
```

**`scripts/clear-container-local-properties.sh`は残す** — この構成が入っていない環境(別のworktree、
Rebuild前のcontainer)での手当てとして使える。bind mountを外せないときも失敗しないようにしてある。
