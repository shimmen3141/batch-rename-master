# 無限ループを作るmutationがホストのメモリを枯渇させ、WSL2 VMごとDockerを落とした

## 観測

2026-10-03、dev container作業中に「Docker returned an error. Make sure the Docker daemon is running and select an option how to proceed.」で2回中断した（03:13頃と04:23頃）。1回目の復旧から**約50分**で再発した。

症状はDocker daemonの異常に見えるが、実体はWSL2 VM全体のハングだった。

- 名前付きパイプへの接続は成功するが、全Docker APIが500を返す
- `com.docker.backend` のログに `dialing 192.168.127.7:2376: no route to host` が連続
- `wsl -d docker-desktop` と `wsl -d Ubuntu` の**両方**がタイムアウト（`Wsl/Service/0x8007274c`）
- `wsl -l -v` は両distroを `Running` と表示するが、実体は応答しない
- Linux側のOOM記録はなし（`oom-tracer` 稼働中、kill記録ゼロ）
- Windowsイベントログに該当時刻のWarning/Errorは皆無

## 原因

因果は3段である。

### 1. mutation M662 が無限ループを作る

```
id      = M662
file    = lib/ui/file_list/folder_names_sync.dart
find    = "        _failed.add(folder);\n"
replace = ""
note    = 008:T54 取れなかった folder を覚えない — 列挙できない経路(SAF)で問い合わせを繰り返し続ける
```

`NameListFailed()` で失敗したフォルダを `_failed` へ記録しなくなるため、直後の `_onFilesChanged()` が同じフォルダを再問い合わせし、無限に繰り返す。noteに書かれているとおりの挙動である。

### 2. testに上限が無いため `flutter_tester` が無制限に膨らむ

実測で `flutter_tester` のRSSは **15〜27MB/秒** で増加し、**8.5GB** まで到達した（その時点で手動停止）。対象testは `test/spec_005_rename_exec/folder_names_sync_test.dart` など。testは無限ループを検出して落ちるのではなく、メモリを食い続ける。

### 3. ホストのコミットメモリが枯渇し、WSL2 VMが凍結する

`C:\Users\yshin\.wslconfig` が存在せず、WSL2がデフォルトで物理メモリの50%（27.81GB中13.97GB）を**コミット予約**していた。実使用7.67GBに対し予約だけで14GB占有していたため、ホストは常時カツカツだった。

ハング時点の実測値:

| 指標 | 値 |
|---|---|
| Commit Limit | 65.71 GB |
| Committed Bytes | 64.92 GB（98.8%） |
| 物理メモリ空き | 787 MB |

ここへ `flutter_tester` の膨張が乗ると、Windowsがメモリを裏付けられず、Linux OOM killerが動く前にVMごと凍結する。だからLinux側にOOM記録が残らない。

## 手当て（実施済み）

`C:\Users\yshin\.wslconfig` を新規作成した（それまで存在しなかった）。

```ini
[wsl2]
memory=10GB
swap=8GB
autoMemoryReclaim=gradual
sparseVhd=true
```

効果は同じ暴走を再現させて確認した。`flutter_tester` が8.5GBまで膨らむ間、`vmmemWSL` は上限10GBで頭打ちになり、超過分はswap（Windowsのコミットを消費しないVHD）へ流れ、**ホストのコミット空きは2.4GBで安定してハングしなかった**。暴走プロセス停止後は `autoMemoryReclaim` が働き、`vmmemWSL` は4.11GB、コミット空きは7.74GBまで戻った。

つまり被害はVM内に封じ込められ、最悪でもLinux OOM killerが処理する状態になった。

## 残る問題

**`.wslconfig` はホストを守るだけで、mutationの検証そのものは直っていない。**

- M662を当てたtestは、無限ループを検出して落ちるのではなく、メモリを食い尽くして異常終了する。その結果 `mutation_check.py` はM662を `KILLED` と記録するが、それは「testが検出した」ではなく「OOMで死んだ」である。**偽の `KILLED`** にあたる。
- 1件あたり約10分かかり、その間ホストは危険域に入る。
- 同じ構造のmutation（ガード削除で再試行ループになるもの）が他にもあれば同じことが起きる。

引き受け先: 008/T54。対応の方向は次のいずれかだが、どれを採るかは所有taskの判断である。

1. 対象testへ時間またはイテレーション回数の上限を入れ、ループを**有限時間で検出して落ちる**ようにする
2. 実装側に再問い合わせ回数の上限を持たせ、ガード1行の欠落で無限ループにならない構造にする（`_failed` への記録が唯一の歯止めになっている現状が脆い）
3. mutation表の `command` を、暴走しうるmutationだけ範囲と上限付きのcommandへ分ける

1は安全網の穴を閉じるだけで、2は成果物の構造を変える。`spec.md` が「列挙できない経路では問い合わせを諦める」ことをどこまで保証として要求しているかの確認が必要である。

## 教訓

- 「Docker daemonが落ちた」に見える事象で、`wsl -l -v` のSTATE表示とWindowsイベントログは当てにならない。コミットメモリ（`Win32_OperatingSystem.FreeVirtualMemory`）と `wsl -d <distro> -- uptime` の応答で切り分ける。
- 無限ループを作るmutationは、testが検出する前にホストを落としうる。mutationのnoteに「繰り返し続ける」「止まらない」と書いたものは、当てる前に上限の有無を確認する。
- mutation実行中はworking treeにmutationの差分が乗る。`git status` の `M` を人間の未コミット作業と誤認しないこと（今回も一度誤認した）。
