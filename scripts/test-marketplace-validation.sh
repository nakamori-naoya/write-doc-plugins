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

  missing_skills_directory=$(new_fixture missing-skills-directory)
  rm -rf "$missing_skills_directory/$relative_root/skills"
  expect_rejected "$missing_skills_directory" 'skills contract requires a physical non-symlink skills directory'

  zero_byte_skill=$(new_fixture zero-byte-skill)
  skill_entry=$(find "$zero_byte_skill/$relative_root/skills" -type f -name SKILL.md -print -quit)
  : > "$skill_entry"
  expect_rejected "$zero_byte_skill" 'SKILL.md must contain non-whitespace content'

  whitespace_skill=$(new_fixture whitespace-skill)
  skill_entry=$(find "$whitespace_skill/$relative_root/skills" -type f -name SKILL.md -print -quit)
  printf ' \n\t\n' > "$skill_entry"
  expect_rejected "$whitespace_skill" 'SKILL.md must contain non-whitespace content'

  intermediate_symlink=$(new_fixture intermediate-symlink)
  plugin_root="$intermediate_symlink/$relative_root"
  ln -s . "$plugin_root/alias"
  for runtime in codex claude; do
    manifest="$plugin_root/.$runtime-plugin/plugin.json"
    jq '.skills = "alias/skills"' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  done
  expect_rejected "$intermediate_symlink" 'plugin source subtree must not contain symlinks'

  catalog_intermediate_symlink=$(new_fixture catalog-intermediate-symlink)
  mv "$catalog_intermediate_symlink/plugins" "$catalog_intermediate_symlink/plugins-real"
  ln -s plugins-real "$catalog_intermediate_symlink/plugins"
  expect_rejected "$catalog_intermediate_symlink" 'plugin source subtree must not contain symlinks'
fi

scripts_source=""
while IFS= read -r source; do
  plugin_root="$ROOT/${source#./}"
  if jq -e '.interface.capabilities | type == "array" and index("Scripts") != null' "$plugin_root/.codex-plugin/plugin.json" >/dev/null; then
    scripts_source="$source"
    break
  fi
done < <(jq -r '.plugins[].source.path' "$ROOT/.agents/plugins/marketplace.json")

if [ -n "$scripts_source" ]; then
  scripts_relative_root=${scripts_source#./}

  missing_scripts=$(new_fixture missing-scripts)
  rm -rf "$missing_scripts/$scripts_relative_root/scripts"
  expect_rejected "$missing_scripts" 'Scripts capability requires a physical non-symlink scripts directory'

  symlink_scripts=$(new_fixture symlink-scripts)
  plugin_root="$symlink_scripts/$scripts_relative_root"
  mv "$plugin_root/scripts" "$plugin_root/scripts-real"
  ln -s scripts-real "$plugin_root/scripts"
  expect_rejected "$symlink_scripts" 'plugin source subtree must not contain symlinks'

  empty_scripts=$(new_fixture empty-scripts)
  rm -rf "$empty_scripts/$scripts_relative_root/scripts"
  mkdir -p "$empty_scripts/$scripts_relative_root/scripts"
  expect_rejected "$empty_scripts" 'Scripts capability requires at least one nonempty regular script'
fi

if [ "$status" -eq 0 ]; then
  printf 'Marketplace negative validation: passed\n'
else
  printf 'Marketplace negative validation: failed\n' >&2
fi
[ "$status" -eq 0 ]
