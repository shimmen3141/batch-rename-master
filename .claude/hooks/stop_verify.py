#!/usr/bin/env python3
"""Stop フック: 完了宣言時にテストを実行し、失敗していたら完了をブロックして
エラーを Claude に差し戻す。無限ループ防止のためブロック回数に上限を設ける。

導入時に書き換える箇所:
  TEST_CMD   — このプロジェクトのテストコマンド(高速なものを推奨)
  MAX_BLOCKS — 1セッションで完了をブロックする最大回数(トークン暴走防止)
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

TEST_CMD = "flutter test"
MAX_BLOCKS = 3
TIMEOUT_SEC = 300

# Windows では既定が cp932 になり日本語メッセージが文字化けするため UTF-8 を明示
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

try:
    hook_input = json.load(sys.stdin)
except Exception:
    hook_input = {}

session = str(hook_input.get("session_id", "default"))[:16]
base = os.path.join(tempfile.gettempdir(), f"stop-verify-{session}")
counter_file = base + ".count"
last_fail_file = base + ".lastfail"


def cleanup() -> None:
    for f in (counter_file, last_fail_file):
        if os.path.exists(f):
            os.remove(f)

blocks = 0
if os.path.exists(counter_file):
    try:
        with open(counter_file) as f:
            blocks = int(f.read().strip() or 0)
    except ValueError:
        blocks = 0

# ブロック上限に達したら、それ以上ループさせず警告だけ出して停止を許可する
if blocks >= MAX_BLOCKS:
    print(
        f"[stop-verify] ブロック上限({MAX_BLOCKS}回)に達したため停止を許可します。"
        "テストが失敗したままの可能性があります。"
    )
    cleanup()
    sys.exit(0)

result = subprocess.run(
    TEST_CMD,
    shell=True,
    capture_output=True,
    text=True,
    errors="replace",
    timeout=TIMEOUT_SEC,
)

if result.returncode == 0:
    cleanup()
    sys.exit(0)

with open(counter_file, "w") as f:
    f.write(str(blocks + 1))

tail = "\n".join((result.stdout + result.stderr).splitlines()[-30:])

# 同一エラーの検出: 実行時間や行番号のズレを吸収するため数値を除いてハッシュ化し、
# 前回の失敗と同じなら fixer への委譲を明示的に要求する
sig = hashlib.sha1(re.sub(r"\d+", "#", tail).encode()).hexdigest()
prev_sig = ""
if os.path.exists(last_fail_file):
    with open(last_fail_file) as f:
        prev_sig = f.read()
with open(last_fail_file, "w") as f:
    f.write(sig)

advice = (
    "前回と同一のエラーです。自力での修正を中止し、fixer サブエージェントに"
    "委譲してください(エラー出力の事実だけを渡し、あなたの仮説は渡さないこと)。"
    if sig == prev_sig
    else "エラー全文を読み、原因を特定してから修正してください。"
)

# exit 2: 停止をブロックし、stderr の内容が Claude にフィードバックされる
print(
    f"テストが失敗しています({blocks + 1}/{MAX_BLOCKS}回目のブロック)。"
    f"{advice}\n\n{tail}",
    file=sys.stderr,
)
sys.exit(2)
