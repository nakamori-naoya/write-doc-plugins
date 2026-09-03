#!/usr/bin/env bash
set -uo pipefail

ROOT=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
ROOT=$(cd "$ROOT" && pwd -P)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/marketplace-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
status=0

fail() {
  printf 'marketplace validation: %s\n' "$1" >&2
  status=1
}

path_has_symlink_component() {
  local current="$1"
  local relative="$2"
  local component
  local saved_ifs="$IFS"
  local -a components

  IFS='/' read -r -a components <<< "$relative"
  IFS="$saved_ifs"
  for component in "${components[@]}"; do
    [ -n "$component" ] || continue
    current="$current/$component"
    [ -L "$current" ] && return 0
  done
  return 1
}

root_license="$ROOT/LICENSE"
codex_catalog="$ROOT/.agents/plugins/marketplace.json"
claude_catalog="$ROOT/.claude-plugin/marketplace.json"

[ -f "$root_license" ] && [ ! -L "$root_license" ] || fail 'root LICENSE must be a regular non-symlink file'
jq -e '.plugins | type == "array" and length > 0' "$codex_catalog" >/dev/null || fail 'Codex catalog is invalid'
jq -e '.plugins | type == "array" and length > 0' "$claude_catalog" >/dev/null || fail 'Claude catalog is invalid'

if [ "$(jq -r '.name' "$codex_catalog")" != "$(jq -r '.name' "$claude_catalog")" ]; then
  fail 'marketplace names differ'
fi

jq -e 'all(.plugins[]; .source.source == "local" and (.source.path | type == "string"))' "$codex_catalog" >/dev/null \
  || fail 'Codex catalog sources must be local paths'
jq -e '(.plugins | length) == ([.plugins[].name] | unique | length) and (.plugins | length) == ([.plugins[].source.path] | unique | length)' "$codex_catalog" >/dev/null \
  || fail 'Codex catalog contains duplicate names or sources'
jq -e '(.plugins | length) == ([.plugins[].name] | unique | length) and (.plugins | length) == ([.plugins[].source] | unique | length)' "$claude_catalog" >/dev/null \
  || fail 'Claude catalog contains duplicate names or sources'

jq -S -c '[.plugins[] | {name,version,source:.source.path}] | sort_by(.name)' "$codex_catalog" > "$TMP_ROOT/codex-catalog.json"
jq -S -c '[.plugins[] | {name,version,source}] | sort_by(.name)' "$claude_catalog" > "$TMP_ROOT/claude-catalog.json"
cmp -s "$TMP_ROOT/codex-catalog.json" "$TMP_ROOT/claude-catalog.json" \
  || fail 'catalog name, version, or source differs between runtimes'

jq -r '.plugins[].source.path' "$codex_catalog" | sort > "$TMP_ROOT/catalog-sources"
find "$ROOT/plugins" -path '*/.codex-plugin/plugin.json' -type f | while IFS= read -r manifest; do
  relative=${manifest#"$ROOT/"}
  printf './%s\n' "${relative%/.codex-plugin/plugin.json}"
done | sort > "$TMP_ROOT/codex-sources"
find "$ROOT/plugins" -path '*/.claude-plugin/plugin.json' -type f | while IFS= read -r manifest; do
  relative=${manifest#"$ROOT/"}
  printf './%s\n' "${relative%/.claude-plugin/plugin.json}"
done | sort > "$TMP_ROOT/claude-sources"
cmp -s "$TMP_ROOT/catalog-sources" "$TMP_ROOT/codex-sources" || fail 'Codex manifests and catalog sources differ'
cmp -s "$TMP_ROOT/catalog-sources" "$TMP_ROOT/claude-sources" || fail 'Claude manifests and catalog sources differ'

while IFS='|' read -r name version source; do
  case "$source" in
    ./plugins/*) ;;
    *) fail "$name has an unsafe catalog source: $source"; continue ;;
  esac

  plugin_root="$ROOT/${source#./}"
  if [ ! -d "$plugin_root" ] || [ -L "$plugin_root" ]; then
    fail "$name plugin root must be a regular directory"
    continue
  fi
  if path_has_symlink_component "$ROOT" "${source#./}"; then
    fail "$name plugin source subtree must not contain symlinks"
    continue
  fi
  resolved_root=$(cd "$plugin_root" && pwd -P)
  case "$resolved_root/" in
    "$ROOT/plugins/"*) ;;
    *) fail "$name plugin root escapes the repository plugins directory"; continue ;;
  esac
  subtree_symlink=$(find "$plugin_root" -type l -print -quit)
  if [ -n "$subtree_symlink" ]; then
    fail "$name plugin source subtree must not contain symlinks"
    continue
  fi

  plugin_license="$plugin_root/LICENSE"
  if [ ! -f "$plugin_license" ] || [ -L "$plugin_license" ]; then
    fail "$name LICENSE must be a regular non-symlink file"
  elif ! cmp -s "$root_license" "$plugin_license"; then
    fail "$name LICENSE differs from root LICENSE"
  fi

  codex_manifest="$plugin_root/.codex-plugin/plugin.json"
  claude_manifest="$plugin_root/.claude-plugin/plugin.json"
  for runtime in codex claude; do
    manifest="$plugin_root/.$runtime-plugin/plugin.json"
    if [ ! -f "$manifest" ] || [ -L "$manifest" ]; then
      fail "$name $runtime manifest must be a regular non-symlink file"
    elif ! jq -e --arg name "$name" --arg version "$version" '.name == $name and .version == $version' "$manifest" >/dev/null; then
      fail "$name $runtime manifest identity differs from catalog"
    fi
  done

  if [ ! -f "$codex_manifest" ] || [ -L "$codex_manifest" ] \
    || [ ! -f "$claude_manifest" ] || [ -L "$claude_manifest" ]; then
    continue
  fi

  skills_contract=0
  jq -e 'has("skills")' "$codex_manifest" >/dev/null && skills_contract=1
  jq -e 'has("skills")' "$claude_manifest" >/dev/null && skills_contract=1
  jq -e '.interface.capabilities | type == "array" and index("Skills") != null' "$codex_manifest" >/dev/null \
    && skills_contract=1
  [ -d "$plugin_root/skills" ] && skills_contract=1

  if [ "$skills_contract" -eq 1 ]; then
    if [ ! -d "$plugin_root/skills" ] || [ -L "$plugin_root/skills" ]; then
      fail "$name skills contract requires a physical non-symlink skills directory"
    fi
    for runtime in codex claude; do
      manifest="$plugin_root/.$runtime-plugin/plugin.json"
      declared_skills=$(jq -er '.skills | select(type == "string" and length > 0)' "$manifest" 2>/dev/null) || {
        fail "$name $runtime manifest must declare skills for its skills directory"
        continue
      }
      case "$declared_skills" in
        /*)
          fail "$name $runtime skills path must be relative"
          continue
          ;;
      esac
      skills_path="$plugin_root/$declared_skills"
      if [ ! -d "$skills_path" ] || [ -L "$skills_path" ]; then
        fail "$name $runtime skills path must be a regular directory"
        continue
      fi
      resolved_skills=$(cd "$skills_path" && pwd -P)
      case "$resolved_skills/" in
        "$resolved_root/"*) ;;
        *)
          fail "$name $runtime skills path escapes the plugin root"
          continue
          ;;
      esac
      skill_count=0
      while IFS= read -r -d '' skill_entry; do
        skill_count=$((skill_count + 1))
        if [ ! -f "$skill_entry" ] || [ -L "$skill_entry" ] \
          || ! LC_ALL=C grep -q '[^[:space:]]' "$skill_entry"; then
          fail "$name $runtime SKILL.md must contain non-whitespace content"
        fi
      done < <(find "$resolved_skills" -name SKILL.md -print0)
      [ "$skill_count" -gt 0 ] || fail "$name $runtime skills path contains no SKILL.md"
    done
    jq -e '.interface.capabilities | type == "array" and index("Skills") != null' "$codex_manifest" >/dev/null \
      || fail "$name Codex capabilities must include Skills"
  else
    jq -s -e 'all(.[]; has("skills") | not)' "$codex_manifest" "$claude_manifest" >/dev/null \
      || fail "$name manifests must not declare skills without a skills directory"
    jq -e '.interface.capabilities | type == "array" and index("Skills") == null' "$codex_manifest" >/dev/null \
      || fail "$name Codex capabilities must not include Skills"
  fi

  if jq -e '.interface.capabilities | type == "array" and index("Scripts") != null' "$codex_manifest" >/dev/null; then
    if [ ! -d "$plugin_root/scripts" ] || [ -L "$plugin_root/scripts" ]; then
      fail "$name Scripts capability requires a physical non-symlink scripts directory"
    else
      resolved_scripts=$(cd "$plugin_root/scripts" && pwd -P)
      case "$resolved_scripts/" in
        "$resolved_root/scripts/") ;;
        *) fail "$name Scripts capability requires a top-level scripts directory" ;;
      esac
      nonempty_script=""
      while IFS= read -r -d '' script_entry; do
        if [ -f "$script_entry" ] && [ ! -L "$script_entry" ] && [ -s "$script_entry" ]; then
          nonempty_script="$script_entry"
          break
        fi
      done < <(find "$resolved_scripts" -type f -print0)
      [ -n "$nonempty_script" ] \
        || fail "$name Scripts capability requires at least one nonempty regular script"
    fi
  fi

  if [ "$name" = "doc-render" ]; then
    jq -s -e 'all(.[]; has("skills") | not)' "$codex_manifest" "$claude_manifest" >/dev/null \
      || fail 'doc-render manifests must not declare skills'
    jq -e '.interface.capabilities | type == "array" and index("Skills") == null and index("Scripts") != null' "$codex_manifest" >/dev/null \
      || fail 'doc-render must advertise Scripts without Skills'
  fi
done < <(jq -r '.plugins[] | [.name,.version,.source.path] | join("|")' "$codex_catalog")

if [ "$status" -eq 0 ]; then
  printf 'Marketplace validation: passed\n'
else
  printf 'Marketplace validation: failed\n' >&2
fi
[ "$status" -eq 0 ]
