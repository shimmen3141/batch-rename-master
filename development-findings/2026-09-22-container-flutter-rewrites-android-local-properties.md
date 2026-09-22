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

## 残っている作業(人間)

**Claude Codeの設定変更はAgentから拒否された**(auto modeの自己変更ガード)。**人間が`.claude/settings.json`へ
hookを足す**と、container内でBashを使うたびに上のscriptが走り、書き換えが残らなくなる。

```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "sh \"$CLAUDE_PROJECT_DIR/scripts/clear-container-local-properties.sh\" 2>/dev/null || true",
          "timeout": 10
        }
      ]
    }
  ]
}
```

## より根本的な案(compose側。人間の作業)

hookは「書き換わった後に消す」対症である。**そもそも共有しない**ほうが確実で、次が候補になる。

- `compose.ai.yml` で `android/local.properties` だけを**anonymous volumeで覆う**
  (`- /workspace/android/local.properties`)。containerが書いてもhostへ出ない。
  `compose.ai.yml` はread-onlyなので**人間の作業**である。
- 同じ型の副作用は他にもありうる(`.dart_tool/`、`build/`、`.flutter-plugins-dependencies` など、
  container固有のpathを書く生成物)。**hostのbuildが壊れたときは、まずこの型を疑う。**
  一般化先の `ai-sandbox-setup` にも、Flutter profileの既知の落とし穴として足す候補である。
