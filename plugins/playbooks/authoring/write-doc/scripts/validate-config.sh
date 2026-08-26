#!/usr/bin/env bash
set -euo pipefail
file="$1"
jq -e '.contract.save_modes == ["create","replace-existing-target"]' "$file" >/dev/null \
  || { echo "[error] write-docの保存モードは新規作成とguard済み既存path差し替えに固定する" >&2; exit 2; }
jq -e '.contract.output_format_precedence == ["caller","doc-render"] and .contract.output_formats == ["markdown","html"]' "$file" >/dev/null \
  || { echo "[error] 呼び出し元が固定した媒体をdoc-render設定より優先し、markdown / htmlだけを許可する" >&2; exit 2; }
jq -e '.steps | all(.[]; .completion == "artifact-set" and .on_failure == "stop")' "$file" >/dev/null \
  || { echo "[error] write-docの全工程はcompletion=artifact-set、on_failure=stopが必要" >&2; exit 2; }
if jq -e '.requirements | has("figures")' "$file" >/dev/null; then
  jq -e '.requirements.figures | type == "boolean"' "$file" >/dev/null \
    || { echo "[error] requirements.figures は true / false で指定すること" >&2; exit 2; }
  if jq -e '.requirements.figures == true' "$file" >/dev/null; then
    jq -e '[.steps[] | .provides[]?] | index("figures_applied") != null' "$file" >/dev/null \
      || { echo "[error] requirements.figures が true だが、figures_applied を provides する工程が無い" >&2; exit 2; }
  fi
fi
