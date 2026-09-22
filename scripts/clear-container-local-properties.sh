#!/bin/sh
# AI container内のFlutterが書き換えた android/local.properties を捨てる。
#
# **なぜ**: `compose.ai.yml` は作業ディレクトリをhostと共有している。container内で
# `flutter` を1回でも動かすと `flutter.sdk` がcontainerのpath(`/home/dev/flutter`)へ
# 書き換わり、**Windows host の `flutter run` が壊れる**。この file は git ignore された
# 機械ごとの設定で、host側のFlutterが必要になったときに作り直す。
#
# **hostでは何もしない**: `AI_SANDBOX=1` でないときと、`flutter.sdk` がPOSIX pathで
# ないとき(= hostが書いた値)は触らない。
set -eu

[ "${AI_SANDBOX:-}" = "1" ] || exit 0

root=${CLAUDE_PROJECT_DIR:-.}
target="$root/android/local.properties"

[ -f "$target" ] || exit 0
grep -q '^flutter\.sdk=/' "$target" || exit 0

rm -f "$target"
