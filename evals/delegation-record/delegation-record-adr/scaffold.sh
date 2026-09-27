#!/usr/bin/env bash
# 素材の検討メモを作業場所へ置く。
set -euo pipefail
CASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mkdir -p input out
cp "$CASE_DIR"/materials/input/*.md input/
