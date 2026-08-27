#!/usr/bin/env bash
# Scenario: write-doc marketplaceが5 pluginで自己完結し、両runtimeで解決できる
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/write-doc-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
passed=0 failed=0
pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }

validate_dependency_resolution_contract() {
  local resolver="$ROOT/shared/playbook/resolve-dependency.py"
  local fixture="$TMP_ROOT/dependency-resolution"
  local cache="$fixture/cache"
  local status=0
  local out

  mkdir -p "$fixture/empty" "$cache/fixture-market/fixture-plugin/1.0.0/.codex-plugin" "$cache/fixture-market/fixture-plugin/1.0.0/.claude-plugin"
  mkdir -p "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin" "$cache/fixture-market/fixture-plugin/9.9.9/.claude-plugin"
  for version in 1.0.0 9.9.9; do
    printf '{"name":"fixture-plugin","version":"%s"}\n' "$version" > "$cache/fixture-market/fixture-plugin/$version/.codex-plugin/plugin.json"
    printf '{"name":"fixture-plugin","version":"%s"}\n' "$version" > "$cache/fixture-market/fixture-plugin/$version/.claude-plugin/plugin.json"
  done
  printf '%s\n' '---' 'name: wrong-skill' 'description: fixture' '---' > "$cache/fixture-market/fixture-plugin/9.9.9/SKILL.md"

  local marketplace repository_plugin
  marketplace=$(jq -r '.name' "$ROOT/.agents/plugins/marketplace.json")
  repository_plugin=$(jq -r '.plugins[0].name' "$ROOT/.agents/plugins/marketplace.json")
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" python3 "$resolver" --plugin-root "$ROOT/shared/playbook" --plugin "$repository_plugin" --marketplace "$marketplace" 2> "$fixture/repository-$runtime.err")
    jq -e --arg runtime "$runtime" --arg plugin "$repository_plugin" '.runtime==$runtime and .plugin==$plugin and .source_kind=="repository"' >/dev/null <<<"$out" || status=1

    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$resolver" --plugin-root "$fixture/empty" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/cache-$runtime.err")
    jq -e --arg runtime "$runtime" '.runtime==$runtime and .version=="9.9.9" and .source_kind=="installed-cache"' >/dev/null <<<"$out" || status=1
  done

  mkdir -p "$fixture/dev/.codex-plugin" "$fixture/dev/.claude-plugin"
  printf '%s\n' '{"name":"fixture-plugin","version":"3.4.5"}' > "$fixture/dev/.codex-plugin/plugin.json"
  printf '%s\n' '{"name":"fixture-plugin","version":"3.4.5"}' > "$fixture/dev/.claude-plugin/plugin.json"
  jq -n --arg root "$fixture/dev" '{schema:1,dependencies:{"fixture-market/fixture-plugin":$root}}' > "$fixture/dev-map.json"
  out=$(HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-map.json" HARNESS_PLUGIN_CACHE_ROOT="$fixture/empty" python3 "$resolver" --plugin-root "$fixture/empty" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/dev.err")
  jq -e '.version=="3.4.5" and .source_kind=="dev-map"' >/dev/null <<<"$out" || status=1

  if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$fixture/empty" python3 "$resolver" --plugin-root "$fixture/empty" --plugin missing-plugin --marketplace fixture-market >/dev/null 2> "$fixture/missing.err"; then
    status=1
  else
    rg '\[error:dependency-missing\].*plugin=missing-plugin.*marketplace=fixture-market' "$fixture/missing.err" >/dev/null || status=1
  fi

  mv "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json" "$fixture/correct-manifest.json"
  printf '%s\n' '{"name":"other-plugin","version":"9.9.9"}' > "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"
  if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$resolver" --plugin-root "$fixture/empty" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/identity.err"; then
    status=1
  else
    rg 'manifest-identity-mismatch' "$fixture/identity.err" >/dev/null || status=1
  fi
  mv "$fixture/correct-manifest.json" "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"

  mkdir -p "$fixture/ambiguous/.agents/plugins" "$fixture/ambiguous/.claude-plugin" "$fixture/ambiguous/plugins/caller"
  jq -n '{name:"fixture-market",plugins:[{name:"fixture-plugin",source:{source:"local",path:"./plugins/a"}},{name:"fixture-plugin",source:{source:"local",path:"./plugins/b"}}]}' > "$fixture/ambiguous/.agents/plugins/marketplace.json"
  if HARNESS_PLUGIN_RUNTIME=codex python3 "$resolver" --plugin-root "$fixture/ambiguous/plugins/caller" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/ambiguous.err"; then
    status=1
  else
    rg 'source_kind=repository reason=marketplace-entry' "$fixture/ambiguous.err" >/dev/null || status=1
  fi

  mkdir -p "$fixture/playbook/scripts" "$fixture/repo"
  cp "$ROOT/shared/playbook/resolve.sh" "$fixture/playbook/scripts/resolve.sh"
  cp "$ROOT/shared/playbook/resolve-dependency.py" "$fixture/playbook/scripts/resolve-dependency.py"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fixture/playbook/scripts/validate-config.sh"
  chmod +x "$fixture/playbook/scripts/resolve.sh" "$fixture/playbook/scripts/validate-config.sh"
  printf '%s\n' 'version: 2' 'name: fixture-playbook' 'description: fixture' 'instructions:' '  execution: {directive: fixture}' 'requires:' '  - {plugin: fixture-plugin, marketplace: fixture-market}' 'steps:' '  - {id: invoke, skill: expected-skill, purpose: fixture}' > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/skill.err"; then
    status=1
  else
    rg 'steps が指すスキルが requires のプラグインに無い: expected-skill' "$fixture/skill.err" >/dev/null || status=1
  fi

  cp "$fixture/playbook/playbook.yml" "$fixture/playbook/base.yml"
  yq -o=json -I=0 '.' "$fixture/playbook/base.yml" | jq '.requires[0].version="1.0.0"' | yq -P > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/pin.err"; then status=1; fi
  yq -o=json -I=0 '.' "$fixture/playbook/base.yml" | jq '.requires[0]=.requires[0].plugin' | yq -P > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/bare.err"; then status=1; fi

  return "$status"
}

jq -r '.plugins[].name' "$ROOT/.agents/plugins/marketplace.json" | sort > "$TMP_ROOT/expected"
find "$ROOT/plugins" -path '*/.codex-plugin/plugin.json' -type f -exec jq -r '.name' {} \; | sort > "$TMP_ROOT/actual"
diff -u "$TMP_ROOT/expected" "$TMP_ROOT/actual" >/dev/null && pass "5 pluginだけを配布" || fail "plugin集合"
for market in .agents/plugins/marketplace.json .claude-plugin/marketplace.json; do
  jq -r '.plugins[].name' "$ROOT/$market" | sort > "$TMP_ROOT/market"
  diff -u "$TMP_ROOT/expected" "$TMP_ROOT/market" >/dev/null && pass "$market plugin集合" || fail "$market plugin集合"
done

while IFS='|' read -r name version rel; do
  if jq -e --arg n "$name" --arg v "$version" '.name==$n and .version==$v' "$ROOT/$rel/.codex-plugin/plugin.json" "$ROOT/$rel/.claude-plugin/plugin.json" >/dev/null; then
    pass "$name manifest identity"
  else
    fail "$name manifest identity"
  fi
done < <(jq -r '.plugins[] | [.name,.version,(.source.path | ltrimstr("./"))] | join("|")' "$ROOT/.agents/plugins/marketplace.json")

pb="$ROOT/plugins/playbooks/authoring/write-doc"
cmp -s "$ROOT/shared/playbook/resolve.sh" "$pb/scripts/resolve.sh" && pass "playbook resolver同期" || fail "playbook resolver同期"
cmp -s "$ROOT/shared/playbook/resolve-dependency.py" "$pb/scripts/resolve-dependency.py" && pass "dependency resolver同期" || fail "dependency resolver同期"
if yq -o=json -I=0 '.' "$pb/playbook.yml" | jq -e '.version==2 and (.requires|length>0) and all(.requires[]; .marketplace=="write-doc" and ((keys|sort)==["marketplace","plugin"]))' >/dev/null; then
  pass "完全修飾した同一marketplace依存"
else
  fail "playbook依存契約"
fi

mkdir -p "$TMP_ROOT/repo"
for runtime in codex claude; do
  out="$TMP_ROOT/$runtime.yml"
  if HARNESS_PLUGIN_RUNTIME="$runtime" bash "$pb/scripts/resolve.sh" "$TMP_ROOT/repo" > "$out" 2> "$out.err" \
    && yq -o=json -I=0 '.' "$out" | jq -e --arg runtime "$runtime" 'all(.deps[]; .runtime==$runtime and .source_kind=="repository")' >/dev/null; then
    pass "$runtime repository resolution"
  else
    fail "$runtime repository resolution"
  fi
done

validate_dependency_resolution_contract && pass "名前ベース依存解決の正常系とfail closed" || fail "名前ベース依存解決の正常系とfail closed"

content_types="$ROOT/plugins/skills/authoring/content-types"
specialist_details=(
  "$content_types/references/detail/product.md"
  "$content_types/references/detail/domain.md"
  "$content_types/references/detail/data-modeling.md"
)
specialist_examples=(
  "$content_types/assets/examples/north-star.example.md"
  "$content_types/assets/examples/strategy.example.md"
  "$content_types/assets/examples/domain-rule.example.md"
  "$content_types/assets/examples/rdb-logical-data-modeling.example.md"
  "$content_types/assets/examples/rdb-physical-design.example.md"
)
specialist_boundary_ok=1
for detail in "${specialist_details[@]}"; do
  rg -F '呼び出し元' "$detail" >/dev/null || specialist_boundary_ok=0
done
for example in "${specialist_examples[@]}"; do
  [ -s "$example" ] || specialist_boundary_ok=0
done
if [ "$specialist_boundary_ok" -eq 1 ] \
  && ! rg -n '(^|[^A-Za-z])(Given|When|Then)([^A-Za-z]|$)|診断|基本方針|一貫した行動|分離レベル|transaction|rollback|再試行' "${specialist_details[@]}" >/dev/null; then
  pass "専門型は記載例を保ち実行規律を呼び出し元へ委譲"
else
  fail "content-typesに専門領域の実行規律が混入"
fi

syntax_failed=0
while IFS= read -r script; do bash -n "$script" || syntax_failed=1; done < <(find "$ROOT" -type f -name '*.sh' | sort)
[ "$syntax_failed" -eq 0 ] && pass "shell構文" || fail "shell構文"
python_failed=0
while IFS= read -r script; do PYTHONPYCACHEPREFIX="$TMP_ROOT/pycache" python3 -m py_compile "$script" || python_failed=1; done < <(find "$ROOT" -type f -name '*.py' | sort)
[ "$python_failed" -eq 0 ] && pass "Python構文" || fail "Python構文"

printf '\nValidation: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
