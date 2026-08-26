#!/usr/bin/env bash
# Scenario: write-doc marketplaceが5 pluginで自己完結し、両runtimeで解決できる
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/write-doc-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
passed=0 failed=0
pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }

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
if yq -o=json -I=0 '.' "$pb/playbook.yml" | jq -e '.version==2 and all(.requires[]; .marketplace=="write-doc" and ((keys|sort)==["marketplace","plugin","version"]))' >/dev/null; then
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

syntax_failed=0
while IFS= read -r script; do bash -n "$script" || syntax_failed=1; done < <(find "$ROOT" -type f -name '*.sh' | sort)
[ "$syntax_failed" -eq 0 ] && pass "shell構文" || fail "shell構文"
python_failed=0
while IFS= read -r script; do PYTHONPYCACHEPREFIX="$TMP_ROOT/pycache" python3 -m py_compile "$script" || python_failed=1; done < <(find "$ROOT" -type f -name '*.py' | sort)
[ "$python_failed" -eq 0 ] && pass "Python構文" || fail "Python構文"

printf '\nValidation: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
