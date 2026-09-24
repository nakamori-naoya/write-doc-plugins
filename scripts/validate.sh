#!/usr/bin/env bash
# Deterministic contract: repository declarations and file inventory only.
# Self-tests below execute positive, negative, and boundary inputs for exact-set predicates.
# Semantic quality remains an agent review of SKILL.md, references, assets, and generated output.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# 保守toolの参照元は兄弟checkoutの harness-tools。無ければ止まる（fixtureで代用しない）。
TOOLS="$ROOT/../harness-tools/tools"
[ -d "$TOOLS" ] || { echo "[error] 兄弟 checkout harness-tools が無い: $TOOLS" >&2; exit 2; }
passed=0
failed=0

pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }
expect() {
  local label="$1"
  shift
  if "$@" >/dev/null; then pass "$label"; else fail "$label"; fi
}

for command in jq yq rg find sort; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'FAIL: required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

same_set() { [ "$1" = "$2" ]; }
paths_exist() {
  local base="$1" paths="$2" rel
  while IFS= read -r rel; do [ -z "$rel" ] || [ -f "$base/$rel" ] || return 1; done <<< "$paths"
}
canonical_map_records() {
  local slugs="$1" slug
  while IFS= read -r slug; do
    [ -z "$slug" ] || printf '%s\n' "$slug|example|assets/examples/$slug.example.md" "$slug|template|assets/templates/$slug.md"
  done <<< "$slugs"
}

PACKAGE="$ROOT/plugins/write-doc"
CLAUDE="$PACKAGE/.claude-plugin/plugin.json"
CODEX="$PACKAGE/.codex-plugin/plugin.json"
ENTRY="$PACKAGE/skills/write-doc"

# ── 配置: package root にだけ manifest、公開入口は skills/write-doc の1つ ─────
for file in "$CLAUDE" "$CODEX" "$PACKAGE/LICENSE" "$ENTRY/SKILL.md" "$ENTRY/playbook.yml" "$ENTRY/CONTRACT.md"; do
  if [ -f "$file" ]; then pass "必須ファイル: ${file#"$ROOT"/}"; else fail "必須ファイル: ${file#"$ROOT"/}"; fi
done

expected_manifest_dirs=$(printf '%s\n' plugins/write-doc/.claude-plugin plugins/write-doc/.codex-plugin | sort)
actual_manifest_dirs=$(find "$ROOT/plugins" -type d \( -name '.claude-plugin' -o -name '.codex-plugin' \) | sed "s#^$ROOT/##" | sort)
if same_set "$actual_manifest_dirs" "$expected_manifest_dirs"; then pass "runtime manifest directoryはpackage rootの2つだけ"; else fail "runtime manifest directoryはpackage rootの2つだけ"; fi
nested_manifest_fixture=$(printf '%s\n' "$expected_manifest_dirs" plugins/write-doc/skills/write-doc/.codex-plugin | sort)
if ! same_set "$nested_manifest_fixture" "$expected_manifest_dirs"; then pass "self-test: nested manifest directoryを拒否"; else fail "self-test: nested manifest directoryを拒否"; fi

skill_files=$(find "$ROOT/plugins" -name SKILL.md -type f | sed "s#^$ROOT/##" | sort)
if same_set "$skill_files" "plugins/write-doc/skills/write-doc/SKILL.md"; then pass "SKILL.mdは公開入口の1本だけ（内部skillなし）"; else fail "SKILL.mdは公開入口の1本だけ（内部skillなし）"; fi
skill_dirs=$(find "$PACKAGE/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
if same_set "$skill_dirs" "write-doc"; then pass "skills/直下はwrite-docだけ"; else fail "skills/直下はwrite-docだけ"; fi

# ── manifest: 両runtime一致、identity、公開契約宣言 ──────────────────────
claude_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$CLAUDE")
codex_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$CODEX")
if [ "$claude_identity" = "$codex_identity" ]; then pass "Claude/Codex package identity一致"; else fail "Claude/Codex package identity一致"; fi
expect "package version 9.4.3" jq -e '.version=="9.4.3"' "$CODEX"
expect "harness marketplace / contractVersion" jq -e '.metadata.harness.marketplace=="write-doc" and .metadata.harness.contractVersion==2 and (.metadata.harness|has("installationSurface")|not) and (.metadata.harness|has("entryRoot")|not) and (.metadata.harness|has("internalPlugins")|not)' "$CODEX"
expect "implements は write-doc/write-doc v2 の1件" jq -e '.metadata.harness.implements==[{"id":"write-doc/write-doc","version":2,"kind":"playbook","playbook":"write-doc","types":.metadata.harness.implements[0].types}]' "$CODEX"
expect "公開入口はskills/write-docの1つでplaybooksにも載る" jq -e '.skills==["./skills/write-doc"] and .metadata.harness.playbooks=={"write-doc":"./skills/write-doc"}' "$CODEX"
for market in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do
  if jq -e '.name=="write-doc" and (.plugins|length)==1 and .plugins[0].name=="write-doc" and .plugins[0].version=="9.4.3"
            and ((.plugins[0].source=="./plugins/write-doc") or (.plugins[0].source=={"source":"local","path":"./plugins/write-doc"}))' "$ROOT/$market" >/dev/null; then
    pass "$market identityとsource"
  else
    fail "$market identityとsource"
  fi
done

# ── 公開入口: frontmatter name と隣接 playbook.yml ─────────────────────────
frontmatter_name=$(awk 'NR==1 { if ($0 != "---") exit 2; next } $0=="---" { exit } { print }' "$ENTRY/SKILL.md" | yq -r '.name')
if [ "$frontmatter_name" = "write-doc" ]; then pass "SKILL frontmatter name = write-doc"; else fail "SKILL frontmatter name = write-doc"; fi
playbook_json=$(yq -o=json -I=0 '.' "$ENTRY/playbook.yml")
expect "playbook.yml identity（version 2 / name write-doc / requires []）" jq -e '.version==2 and .name=="write-doc" and .requires==[]' <<<"$playbook_json"
expect "steps は agent_work だけで工程idが一意" jq -e '(.steps|type)=="array" and (.steps|length)==7 and all(.steps[]; .agent_work=="invoking_agent" and (has("script") or has("skill") or has("playbook")|not) and (.id|type)=="string" and (.id|length)>0) and ((.steps|map(.id)|unique|length)==(.steps|length))' <<<"$playbook_json"
expect "self-edit工程が草稿と保存の間にある" jq -e '(.steps|map(.id)|index("self-edit")) as $s | (.steps|map(.id)|index("draft")) < $s and $s < (.steps|map(.id)|index("save"))' <<<"$playbook_json"
expect "最終工程がstatus/path/reasonをprovideする" jq -e '.steps[-1].provides==["status","path","reason"]' <<<"$playbook_json"

# ── 参照文書と資産の閉じた集合 ────────────────────────────────────────────
reference_list=$(find "$ENTRY/references" -maxdepth 1 -type f -name '*.md' -exec basename {} \; | sort)
expected_references=$(printf '%s\n' integrity-check.md visuals-and-tables.md writing-norms.md)
if same_set "$reference_list" "$expected_references"; then pass "参照文書は指定3本"; else fail "参照文書は指定3本"; fi
if ! same_set "$(printf '%s\n' writing-norms.md integrity-check.md)" "$expected_references"; then pass "self-test: 参照2本を拒否"; else fail "self-test: 参照2本を拒否"; fi
if ! same_set "$(printf '%s\n' extra.md integrity-check.md visuals-and-tables.md writing-norms.md | sort)" "$expected_references"; then pass "self-test: 参照4本を拒否"; else fail "self-test: 参照4本を拒否"; fi

expect "template資産24件" sh -c 'test "$(find "$1" -type f | wc -l | tr -d " ")" -eq 24' sh "$ENTRY/assets/templates"
expect "template Markdown 20件" sh -c 'test "$(find "$1" -type f -name "*.md" | wc -l | tr -d " ")" -eq 20' sh "$ENTRY/assets/templates"
expect "example資産24件" sh -c 'test "$(find "$1" -type f | wc -l | tr -d " ")" -eq 24' sh "$ENTRY/assets/examples"
expect "example Markdown 20件" sh -c 'test "$(find "$1" -type f -name "*.md" | wc -l | tr -d " ")" -eq 20' sh "$ENTRY/assets/examples"
expect "persona 5件" sh -c 'test "$(find "$1" -type f -name "*.md" | wc -l | tr -d " ")" -eq 5' sh "$ENTRY/assets/personas"
expect "型対応表を保持" test -f "$ENTRY/assets/template-examples.yml"

expected_asset_paths=$(printf '%s\n' \
  examples/adr.example.md \
  examples/agent-session-digest.example.md \
  examples/architecture.example.md \
  examples/cloud-architecture.example.md \
  examples/concept.example.md \
  examples/domain-model.example.md \
  examples/domain-rule.example.md \
  examples/how-to.example.md \
  examples/north-star.example.assets/north-star-boundary.svg \
  examples/north-star.example.assets/north-star-value-flow.svg \
  examples/north-star.example.md \
  examples/period-digest.example.md \
  examples/pr-walkthrough.example.md \
  examples/quality-requirements.example.md \
  examples/rdb-logical-data-modeling.example.md \
  examples/rdb-physical-design.example.md \
  examples/readme.example.md \
  examples/requirements-discovery.example.md \
  examples/strategy.example.assets/strategy-action-chain.svg \
  examples/strategy.example.assets/strategy-choice.svg \
  examples/strategy.example.md \
  examples/troubleshooting.example.md \
  examples/user-journey-bdd.example.md \
  examples/workload-model.example.md \
  personas/backend-1.md personas/backend-5.md personas/pm-1.md personas/pm-3.md personas/product-user.md \
  template-examples.yml \
  templates/adr.md templates/agent-session-digest.md templates/architecture.md templates/cloud-architecture.md templates/concept.md \
  templates/domain-model.md templates/domain-rule.md templates/how-to.md \
  templates/north-star-boundary.svg templates/north-star-value-flow.svg templates/north-star.md \
  templates/period-digest.md templates/pr-walkthrough.md templates/quality-requirements.md \
  templates/rdb-logical-data-modeling.md templates/rdb-physical-design.md templates/readme.md \
  templates/requirements-discovery.md templates/strategy-action-chain.svg templates/strategy-choice.svg \
  templates/strategy.md templates/troubleshooting.md templates/user-journey-bdd.md templates/workload-model.md \
  visual-guidance/LICENSE.drawio-diagram-skills \
  visual-guidance/reference-business-flow.png \
  visual-guidance/reference-cicd-pipeline.png \
  visual-guidance/reference-system-architecture.png | sort)
actual_asset_paths=$(cd "$ENTRY/assets" && find . -type f | sed 's#^./##' | sort)
if same_set "$actual_asset_paths" "$expected_asset_paths"; then pass "継承資産58 path完全一致"; else fail "継承資産58 path完全一致"; fi
if ! same_set "$actual_asset_paths" "${expected_asset_paths%templates/workload-model.md}templates/arbitrary.md"; then pass "self-test: 同数renameを拒否"; else fail "self-test: 同数renameを拒否"; fi

map_file="$ENTRY/assets/template-examples.yml"
map_paths=$(awk '/^    (template|example): / {print $2}' "$map_file")
if [ "$(printf '%s\n' "$map_paths" | sed '/^$/d' | wc -l | tr -d ' ')" -eq 40 ] && paths_exist "$ENTRY" "$map_paths"; then pass "型対応表20組の参照先が存在"; else fail "型対応表20組の参照先が存在"; fi
if ! paths_exist "$ENTRY" "assets/templates/missing.md"; then pass "self-test: 対応表の欠損参照を拒否"; else fail "self-test: 対応表の欠損参照を拒否"; fi
map_slugs=$(awk '/^  [a-z0-9-]+:$/ {sub(/^  /, ""); sub(/:$/, ""); print}' "$map_file" | sort)
manifest_slugs=$(jq -r '.metadata.harness.implements[0].types[]' "$CODEX" | sort)
if same_set "$map_slugs" "$manifest_slugs"; then pass "対応表slugとimplements.types一致"; else fail "対応表slugとimplements.types一致"; fi
map_records=$(awk '/^  [a-z0-9-]+:$/ {slug=$1; sub(/:$/, "", slug)} /^    (template|example): / {field=$1; sub(/:$/, "", field); print slug "|" field "|" $2}' "$map_file" | sort)
expected_map_records=$(canonical_map_records "$map_slugs" | sort)
if same_set "$map_records" "$expected_map_records"; then pass "各slugのtemplate/example path対応一致"; else fail "各slugのtemplate/example path対応一致"; fi
remapped_fixture=${expected_map_records/adr|template|assets\/templates\/adr.md/adr|template|assets\/examples\/adr.example.md}
if ! same_set "$remapped_fixture" "$expected_map_records"; then pass "self-test: 実在pathへの誤対応を拒否"; else fail "self-test: 実在pathへの誤対応を拒否"; fi

# ── template資産の構造: 冒頭の `> 型:` 引用行と「状態と引き継ぎ」表を持たない ──
# 生成物には適用しない（生成物の冒頭が本文段落かは意味評価）。
if rg -n '^> 型:|^## 状態と引き継ぎ' "$ENTRY/assets/templates" "$ENTRY/assets/examples" >/dev/null; then
  fail "template / example に > 型: 行または「状態と引き継ぎ」表が残っている"
else
  pass "template / example に > 型: 行と「状態と引き継ぎ」表が無い"
fi
if printf '> 型: x ／ 読み手: y\n' | rg -q '^> 型:'; then pass "self-test: > 型: 行を検出できる"; else fail "self-test: > 型: 行を検出できる"; fi

# ── Zero-Plumbing: 配布指示に禁止参照形と旧runtime呼び出しが無い ───────────
if rg -n --fixed-strings -e '${.' -e '<!-- BEGIN shared:' -e 'CLAUDE_PLUGIN_ROOT' -e 'BUNDLE_ROOT' "$ENTRY/SKILL.md" "$ENTRY/CONTRACT.md" "$ENTRY/playbook.yml" "$ENTRY/references" >/dev/null; then
  fail "配布指示に禁止参照形が無い"
else
  pass "配布指示に禁止参照形が無い"
fi
if rg -n 'prepare\.sh|resolve\.sh|run-config\.py|reader_context\.ya?ml|reading_path\.ya?ml|figures_applied\.ya?ml|decisions\.ya?ml|(^|[^[:alnum:]_])yq([^[:alnum:]_]|$)|exit 2' "$ENTRY/SKILL.md" >/dev/null; then
  fail "執筆SKILLに旧runtime・中間YAML呼び出しがない"
else
  pass "執筆SKILLに旧runtime・中間YAML呼び出しがない"
fi

# repositoryの回帰検査（harness-tools）: CI workflowのSHA固定、公開入口の一意性、doctorの読み取り専用性、templateと記載例の対応
if python3 "$TOOLS/test-hardening.py" --repository "$ROOT" >/dev/null 2>&1; then pass "test-hardening --repository"; else fail "test-hardening --repository"; fi

symlink_count=$(find "$ROOT" -type l | wc -l | tr -d ' ')
if [ "$symlink_count" -eq 0 ]; then pass "symlinkなし"; else fail "symlinkなし"; fi

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
