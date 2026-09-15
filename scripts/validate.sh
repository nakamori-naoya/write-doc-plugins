#!/usr/bin/env bash
# Deterministic contract: repository declarations and file inventory only.
# Self-tests below execute positive, negative, and boundary inputs for exact-set predicates.
# Semantic quality remains an agent review of SKILL.md, references, assets, and generated output.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
passed=0
failed=0

pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }
expect() {
  local label="$1"
  shift
  if "$@" >/dev/null; then pass "$label"; else fail "$label"; fi
}

for command in jq rg find sort; do
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

CLAUDE="$ROOT/plugins/.claude-plugin/plugin.json"
CODEX="$ROOT/plugins/.codex-plugin/plugin.json"
PLAYBOOK="$ROOT/plugins/playbooks/authoring/write-doc"
AUTHOR="$ROOT/plugins/skills/authoring/author-document"

for file in "$CLAUDE" "$CODEX" "$PLAYBOOK/SKILL.md" "$PLAYBOOK/playbook.yml" "$PLAYBOOK/CONTRACT.md" "$AUTHOR/SKILL.md"; do
  if [ -f "$file" ]; then pass "必須ファイル: ${file#"$ROOT"/}"; else fail "必須ファイル: ${file#"$ROOT"/}"; fi
done

expected_package_manifests=$(printf '%s\n' \
  plugins/.claude-plugin/plugin.json \
  plugins/.codex-plugin/plugin.json | sort)
actual_package_manifests=$(find "$ROOT/plugins" -type f \( -path '*/.claude-plugin/plugin.json' -o -path '*/.codex-plugin/plugin.json' \) | sed "s#^$ROOT/##" | sort)
if same_set "$actual_package_manifests" "$expected_package_manifests"; then pass "package manifestはrootの2本だけ"; else fail "package manifestはrootの2本だけ"; fi
nested_manifest_fixture=$(printf '%s\n' "$expected_package_manifests" plugins/playbooks/fixture/.codex-plugin/plugin.json | sort)
if ! same_set "$nested_manifest_fixture" "$expected_package_manifests"; then pass "self-test: nested manifestを拒否"; else fail "self-test: nested manifestを拒否"; fi

claude_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$CLAUDE")
codex_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$CODEX")
if [ "$claude_identity" = "$codex_identity" ]; then pass "Claude/Codex package identity一致"; else fail "Claude/Codex package identity一致"; fi
expect "package version 7.0.0" jq -e '.version=="7.0.0"' "$CODEX"
expect "contract version 2" jq -e '.metadata.harness.contractVersion==2 and .metadata.harness.implements==[{"id":"write-doc/write-doc","version":2,"kind":"playbook","playbook":"write-doc","types":.metadata.harness.implements[0].types}]' "$CODEX"
expect "公開playbookはwrite-doc 1つ" jq -e '.skills==["./playbooks/authoring/write-doc"] and (.metadata.harness.playbooks|keys)==["write-doc"]' "$CODEX"
expect "内部skillはauthor-document 1つ" jq -e '(.metadata.harness.internalPlugins|keys)==["author-document"] and .metadata.harness.internalPlugins["author-document"]=="./skills/authoring/author-document"' "$CODEX"
expect "playbookはauthor-document単一step" sh -c   'test "$(rg -c "^  - id:" "$1")" -eq 1 && rg -q "skill: author-document" "$1" && ! rg -q "playbook:|script:" "$1"' sh "$PLAYBOOK/playbook.yml"

reference_list=$(find "$AUTHOR/references" -maxdepth 1 -type f -name '*.md' -exec basename {} \; | sort)
expected_references=$(printf '%s\n' core-principles.md integrity-check.md visuals-and-tables.md)
if same_set "$reference_list" "$expected_references"; then pass "参照文書は指定3本"; else fail "参照文書は指定3本"; fi
if ! same_set "$(printf '%s\n' core-principles.md integrity-check.md)" "$expected_references"; then pass "self-test: 参照2本を拒否"; else fail "self-test: 参照2本を拒否"; fi
if ! same_set "$(printf '%s\n' core-principles.md extra.md integrity-check.md visuals-and-tables.md | sort)" "$expected_references"; then pass "self-test: 参照4本を拒否"; else fail "self-test: 参照4本を拒否"; fi

expect "template資産23件" sh -c 'test "$(find "$1" -type f | wc -l | tr -d " ")" -eq 23' sh "$AUTHOR/assets/templates"
expect "template Markdown 19件" sh -c 'test "$(find "$1" -type f -name "*.md" | wc -l | tr -d " ")" -eq 19' sh "$AUTHOR/assets/templates"
expect "example資産23件" sh -c 'test "$(find "$1" -type f | wc -l | tr -d " ")" -eq 23' sh "$AUTHOR/assets/examples"
expect "example Markdown 19件" sh -c 'test "$(find "$1" -type f -name "*.md" | wc -l | tr -d " ")" -eq 19' sh "$AUTHOR/assets/examples"
expect "persona 5件" sh -c 'test "$(find "$1" -type f -name "*.md" | wc -l | tr -d " ")" -eq 5' sh "$AUTHOR/assets/personas"
expect "型対応表を保持" test -f "$AUTHOR/assets/template-examples.yml"

expected_asset_paths=$(printf '%s\n' \
  examples/adr.example.md \
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
  templates/adr.md templates/architecture.md templates/cloud-architecture.md templates/concept.md \
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
actual_asset_paths=$(cd "$AUTHOR/assets" && find . -type f | sed 's#^./##' | sort)
if same_set "$actual_asset_paths" "$expected_asset_paths"; then pass "継承資産56 path完全一致"; else fail "継承資産56 path完全一致"; fi
if ! same_set "$actual_asset_paths" "${expected_asset_paths%templates/workload-model.md}templates/arbitrary.md"; then pass "self-test: 同数renameを拒否"; else fail "self-test: 同数renameを拒否"; fi

map_file="$AUTHOR/assets/template-examples.yml"
map_paths=$(awk '/^    (template|example): / {print $2}' "$map_file")
if [ "$(printf '%s\n' "$map_paths" | sed '/^$/d' | wc -l | tr -d ' ')" -eq 38 ] && paths_exist "$AUTHOR" "$map_paths"; then pass "型対応表19組の参照先が存在"; else fail "型対応表19組の参照先が存在"; fi
if ! paths_exist "$AUTHOR" "assets/templates/missing.md"; then pass "self-test: 対応表の欠損参照を拒否"; else fail "self-test: 対応表の欠損参照を拒否"; fi
map_slugs=$(awk '/^  [a-z0-9-]+:$/ {sub(/^  /, ""); sub(/:$/, ""); print}' "$map_file" | sort)
manifest_slugs=$(jq -r '.metadata.harness.implements[0].types[]' "$CODEX" | sort)
if same_set "$map_slugs" "$manifest_slugs"; then pass "対応表slugとimplements.types一致"; else fail "対応表slugとimplements.types一致"; fi
map_records=$(awk '/^  [a-z0-9-]+:$/ {slug=$1; sub(/:$/, "", slug)} /^    (template|example): / {field=$1; sub(/:$/, "", field); print slug "|" field "|" $2}' "$map_file" | sort)
expected_map_records=$(canonical_map_records "$map_slugs" | sort)
if same_set "$map_records" "$expected_map_records"; then pass "各slugのtemplate/example path対応一致"; else fail "各slugのtemplate/example path対応一致"; fi
remapped_fixture=${expected_map_records/adr|template|assets\/templates\/adr.md/adr|template|assets\/examples\/adr.example.md}
if ! same_set "$remapped_fixture" "$expected_map_records"; then pass "self-test: 実在pathへの誤対応を拒否"; else fail "self-test: 実在pathへの誤対応を拒否"; fi

if rg -n 'prepare\.sh|run-config\.py|reader_context\.ya?ml|reading_path\.ya?ml|figures_applied\.ya?ml|decisions\.ya?ml|(^|[^[:alnum:]_])yq([^[:alnum:]_]|$)|exit 2' "$PLAYBOOK/SKILL.md" "$AUTHOR/SKILL.md"; then
  fail "執筆SKILLに旧runtime・中間YAML呼び出しがない"
else
  pass "執筆SKILLに旧runtime・中間YAML呼び出しがない"
fi

legacy_count=$(find "$ROOT/plugins/skills/authoring" -mindepth 1 -maxdepth 1 -type d ! -name author-document | wc -l | tr -d ' ')
if [ "$legacy_count" -eq 0 ]; then pass "旧skill directoryなし"; else fail "旧skill directoryなし"; fi

symlink_count=$(find "$ROOT" -type l | wc -l | tr -d ' ')
if [ "$symlink_count" -eq 0 ]; then pass "symlinkなし"; else fail "symlinkなし"; fi

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
