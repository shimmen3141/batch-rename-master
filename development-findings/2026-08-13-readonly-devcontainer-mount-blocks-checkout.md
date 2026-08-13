# Development finding: read-onlyな`.devcontainer`マウントがgitのcheckout・mergeを止める

- 観測日: 2026-08-13(初回は2026-08-11、以後3回)
- 観測した作業: `dev`の更新取り込み、branch切替、005:T09での`git checkout`
- 改善先: project(`AGENTS.md`のAI sandbox節)、およびAgentの手順
- 関連artifact: `compose.ai.yml`のread-only mount、`.devcontainer/`

## 観測した事実

`/workspace`はrw、その上に`.devcontainer/`と`compose.ai.yml`が**ro bind mount**で重なっている。

```text
C:\ on /workspace type 9p (rw,...)
C:\ on /workspace/.devcontainer type 9p (ro,...)
C:\ on /workspace/compose.ai.yml type 9p (ro,...)
```

これは設計どおりである(`AGENTS.md`:「`compose.ai.yml`と`.devcontainer/`はread-only。変更は人間へ依頼する」)。

問題は、**gitがこれらのfileを更新する必要がある操作すべてが止まる**ことである。commitがそれらのpathを含むかどうかではなく、**checkout先とcheckout元で内容が違えば**起きる。

```text
error: unable to unlink old '.devcontainer/devcontainer.json': Read-only file system
```

3回起きた。

1. 2026-08-11 — 人間が`.devcontainer/Dockerfile`へ`clang`を追加した後の`git checkout`。
2. 2026-08-13 — PR #127(`init-firewall.sh`)をmergeした`dev`への`git merge --ff-only`。
3. 2026-08-13 — PR #132(`devcontainer.json`)を含む`dev`への`git merge --ff-only`。

**3回目が最も危険だった。** ff-mergeは`.devcontainer/devcontainer.json`のunlinkで失敗したが、**その時点で他のfileは既に更新されていた**。HEADは古いまま、working treeは新旧混在、`AGENTS.md`・`specs/README.md`・`docs/development/ai-sandbox.md`が変更済み、新しいfindingが未追跡で置かれた状態になった。**「失敗したから何も起きていない」ではない。**

## 期待していた動きと実際の動き

- 期待: read-only mountは書き込みを拒むだけで、それ以外の作業には影響しない。
- 実際: 人間が`.devcontainer/`へ触るたびに、**Agentは`dev`を進められなくなる**。しかも失敗が中途半端な状態を残す。

## 根本原因

`.devcontainer/`はgit管理下にあり、かつworktree上でread-onlyである。gitはworktreeを書き換えることで状態を移すので、この2つは両立しない。

`git update-index --skip-worktree`を先に設定しても**防げなかった**。skip-worktreeはstatusとcommitからは外すが、2-tree checkout/mergeがentryを更新しようとするのは止まらない。

## workaround(有効だったもの)

worktreeを触らずにHEADとindexだけ進め、read-only path以外を後から実体化する。

```bash
git reset --mixed <target> -q
git checkout -- ':(exclude).devcontainer' ':(exclude)compose.ai.yml'
git ls-files .devcontainer compose.ai.yml | xargs git update-index --skip-worktree
```

結果として次の状態になる。

- HEADとindexは正しい内容(read-only pathも**indexは新しいblob**)。
- worktreeの`.devcontainer/`はhostのbuild時点の内容のまま。
- skip-worktreeによりstatusは clean で、commitにはindexの正しい内容が入る。

**この状態は正直である。** containerが実際に動いているのはhostがbuildした時点の設定であり、worktreeがそれを映しているほうが実態に近い。

ただし**副作用**がある。`.devcontainer/`の変更をAgentがcommitしたい場合(そもそも規約で禁じている)や、skip-worktreeを知らない次のAgentが混乱する可能性がある。skip-worktreeが設定されていることは`git ls-files -v`の先頭`S`で分かる。

## 影響

- 影響: 人間が`.devcontainer/`を変えるたびにAgentの`dev`追従が止まる。今回はfirewall変更(#127)とsecret log修正(#132)という**Agentの作業に必要な変更**そのものが原因だった。
- 影響: 失敗が中途半端なworking treeを残す。**気付かずに次の操作へ進むと、意図しない内容をcommitしうる。**
- 影響なし: 成果物の内容。今回は検知して`git reset --hard`で戻した。

## 仮説と提案

- **`AGENTS.md`のAI sandbox節へ一文足す。** 「`.devcontainer/`と`compose.ai.yml`はread-only mountのため、これらを変更するcommitへcheckout・mergeできない。`git reset --mixed` + pathspec除外で進め、skip-worktreeを設定する。**失敗時はworking treeが中途半端になるので`git status`を必ず確認する。**」
- 一般化: **git管理下のpathをread-onlyでmountすると、そのrepositoryのcheckoutが壊れる。** sandbox設計としては、(i) `.devcontainer/`をgit管理外にする、(ii) mountせずimageへ焼き込む、(iii) 現状どおりでAgent側の手順で回避する、のいずれか。(i)(ii)はこのprojectの秘密境界の設計に関わるので人間の判断。
- Agent側の規律: **失敗したgit操作の後は必ず`git status --short`を見る。** 「errorが出た=何も起きていない」と読まない。

## 改善結果

workaroundを適用し、`dev`を`f97a2cc`へ進めた。`AGENTS.md`への追記は人間の判断待ち(`AGENTS.md`はAgentが変更しない対象)。
