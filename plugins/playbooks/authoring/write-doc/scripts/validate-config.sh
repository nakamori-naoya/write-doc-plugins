#!/usr/bin/env bash
set -euo pipefail
file="$1"
jq -e '.contract.save_modes == ["create","replace-existing-target"]' "$file" >/dev/null \
  || { echo "[error] write-docの保存モードは新規作成とguard済み既存path差し替えに固定する" >&2; exit 2; }
jq -e '.contract.output_format_precedence == ["caller","doc-render"] and .contract.output_formats == ["markdown","html"]' "$file" >/dev/null \
  || { echo "[error] 呼び出し元が固定した媒体をdoc-render設定より優先し、markdown / htmlだけを許可する" >&2; exit 2; }
jq -e '.steps | all(.[]; .completion == "artifact-set")' "$file" >/dev/null \
  || { echo "[error] write-docの全工程はcompletion=artifact-setが必要" >&2; exit 2; }
# on_failure は stop か、前方にある工程idだけを許す。前方の工程へ戻す形でだけ、
# 判定に落ちた本文を作り直せる。後方や存在しない工程を指すと、失敗時に進んでしまう。
jq -e '
  [.steps[].id] as $ids
  | .steps
  | to_entries
  | all(.[];
      (.value.on_failure == "stop")
      or ((.value.on_failure as $t | $ids | index($t)) as $i
          | $i != null and $i < .key))
' "$file" >/dev/null \
  || { echo "[error] on_failure は stop か、自分より前にある工程idであること" >&2; exit 2; }
if jq -e '.requirements | has("figures")' "$file" >/dev/null; then
  jq -e '.requirements.figures | type == "boolean"' "$file" >/dev/null \
    || { echo "[error] requirements.figures は true / false で指定すること" >&2; exit 2; }
  if jq -e '.requirements.figures == true' "$file" >/dev/null; then
    jq -e '[.steps[] | .provides[]?] | index("figures_applied") != null' "$file" >/dev/null \
      || { echo "[error] requirements.figures が true だが、figures_applied を provides する工程が無い" >&2; exit 2; }
  fi
fi
