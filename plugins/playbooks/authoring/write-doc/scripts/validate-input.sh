#!/usr/bin/env bash
# 契約固有の入力schemaを入口で検査する任意hook。
#
#   validate-input.sh <正規化済みの入力YAMLの絶対path>
#
# resolve.sh が --input を受けたときだけ呼ぶ。共通resolverは契約ID・版・能力・
# output_to までしか見ないので、write-doc/write-doc 契約 v1 の必須キー・未知キー・
# 保存先の排他規則・材料と追加指示のpathは、ここで見る。
#
# **非0で一律拒否する。** 診断は stderr の [error:input-schema] key=value を読む。
set -uo pipefail
[ "$#" -eq 1 ] || { echo "[error:input-schema] reason=usage detail=validate-input.sh <入力path>" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/contract-io.py" check --input "$1"
