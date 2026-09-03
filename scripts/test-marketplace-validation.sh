#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/marketplace-negative-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
status=0

fail() {
  printf 'marketplace negative validation: %s\n' "$1" >&2
  status=1
}

new_fixture() {
  local fixture="$TMP_ROOT/$1"
  mkdir -p "$fixture"
  cp -R "$ROOT/." "$fixture"
  rm -rf "$fixture/.git"
  printf '%s\n' "$fixture"
}

expect_rejected() {
  local fixture="$1"
  local expected="$2"
  local output="$fixture/validator.out"
  if bash "$fixture/scripts/validate-marketplace.sh" "$fixture" > "$output" 2>&1; then
    fail "mutation unexpectedly passed: $expected"
  elif ! rg -F "$expected" "$output" >/dev/null; then
    fail "mutation failed for an unexpected reason: $expected"
  fi
}

skills_source=""
while IFS= read -r source; do
  if [ -d "$ROOT/${source#./}/skills" ]; then
    skills_source="$source"
    break
  fi
done < <(jq -r '.plugins[].source.path' "$ROOT/.agents/plugins/marketplace.json")

if [ -z "$skills_source" ]; then
  fail 'no plugin with a skills directory was found'
else
  relative_root=${skills_source#./}

  missing_skills=$(new_fixture missing-skills)
  manifest="$missing_skills/$relative_root/.claude-plugin/plugin.json"
  jq 'del(.skills)' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  expect_rejected "$missing_skills" 'claude manifest must declare skills for its skills directory'

  empty_capabilities=$(new_fixture empty-capabilities)
  manifest="$empty_capabilities/$relative_root/.codex-plugin/plugin.json"
  jq '.interface.capabilities = []' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  expect_rejected "$empty_capabilities" 'Codex capabilities must include Skills'

  unsafe_skills=$(new_fixture unsafe-skills)
  outside="$unsafe_skills/outside-skills"
  mkdir -p "$outside"
  printf '%s\n' '---' 'name: outside' 'description: outside fixture' '---' > "$outside/SKILL.md"
  manifest="$unsafe_skills/$relative_root/.claude-plugin/plugin.json"
  jq --arg outside "$outside" '.skills = $outside' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  expect_rejected "$unsafe_skills" 'claude skills path must be relative'
fi

if [ "$status" -eq 0 ]; then
  printf 'Marketplace negative validation: passed\n'
else
  printf 'Marketplace negative validation: failed\n' >&2
fi
[ "$status" -eq 0 ]
