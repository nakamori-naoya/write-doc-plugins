#!/usr/bin/env bash
# Scenario: write-doc marketplaceが6 pluginで自己完結し、両runtimeで解決できる
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$ROOT/scripts/test-hardening.py" || exit 1
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/write-doc-validation.XXXXXX") || exit 2
export TMPDIR="$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT
passed=0 failed=0
pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }

validate_dependency_resolution_contract() {
  local resolver="$ROOT/shared/playbook/resolve-dependency.py"
  local fixture="$TMP_ROOT/dependency-resolution"
  local cache="$fixture/empty/.harness-plugin-test-cache"
  local isolated_resolver="$fixture/empty/scripts/resolve-dependency.py"
  local isolated_root
  local status=0
  local out

  mkdir -p "$fixture/empty/scripts" "$cache/fixture-market/fixture-plugin/1.0.0/.codex-plugin" "$cache/fixture-market/fixture-plugin/1.0.0/.claude-plugin"
  cp "$resolver" "$isolated_resolver"
  isolated_root=$(cd "$fixture/empty" && pwd -P)
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

    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$isolated_resolver" --plugin-root "$isolated_root" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/cache-$runtime.err")
    jq -e --arg runtime "$runtime" '.runtime==$runtime and .version=="9.9.9" and .source_kind=="installed-cache"' >/dev/null <<<"$out" || status=1
  done

  local installed_cache="$fixture/profile/plugins/cache"
  local installed_caller="$installed_cache/caller-market/caller-plugin/1.0.0/playbook"
  mkdir -p "$installed_caller/scripts"
  cp "$resolver" "$installed_caller/scripts/resolve-dependency.py"
  cp -R "$cache/fixture-market" "$installed_cache/"
  local installed_root
  installed_root=$(cd "$installed_caller" && pwd -P)
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" python3 "$installed_caller/scripts/resolve-dependency.py" --plugin-root "$installed_root" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/installed-$runtime.err")
    jq -e --arg runtime "$runtime" '.runtime==$runtime and .version=="9.9.9" and .source_kind=="installed-cache"' >/dev/null <<<"$out" || status=1
  done

  mkdir -p "$fixture/dev/.codex-plugin" "$fixture/dev/.claude-plugin"
  printf '%s\n' '{"name":"fixture-plugin","version":"3.4.5"}' > "$fixture/dev/.codex-plugin/plugin.json"
  printf '%s\n' '{"name":"fixture-plugin","version":"3.4.5"}' > "$fixture/dev/.claude-plugin/plugin.json"
  jq -n --arg root "$fixture/dev" '{schema:1,dependencies:{"fixture-market/fixture-plugin":$root}}' > "$fixture/dev-map.json"
  out=$(HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-map.json" HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$isolated_resolver" --plugin-root "$isolated_root" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/dev.err")
  jq -e '.version=="3.4.5" and .source_kind=="dev-map"' >/dev/null <<<"$out" || status=1

  if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$isolated_resolver" --plugin-root "$isolated_root" --plugin missing-plugin --marketplace fixture-market >/dev/null 2> "$fixture/missing.err"; then
    status=1
  else
    rg '\[error:dependency-missing\].*plugin=missing-plugin.*marketplace=fixture-market' "$fixture/missing.err" >/dev/null || status=1
  fi

  mv "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json" "$fixture/correct-manifest.json"
  printf '%s\n' '{"name":"other-plugin","version":"9.9.9"}' > "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"
  if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$isolated_resolver" --plugin-root "$isolated_root" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/identity.err"; then
    status=1
  else
    rg 'manifest-identity-mismatch' "$fixture/identity.err" >/dev/null || status=1
  fi
  mv "$fixture/correct-manifest.json" "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"

  mkdir -p "$fixture/ambiguous/.agents/plugins" "$fixture/ambiguous/.claude-plugin" "$fixture/ambiguous/plugins/caller"
  mkdir -p "$fixture/ambiguous/plugins/caller/scripts"
  cp "$resolver" "$fixture/ambiguous/plugins/caller/scripts/resolve-dependency.py"
  local ambiguous_root
  ambiguous_root=$(cd "$fixture/ambiguous/plugins/caller" && pwd -P)
  jq -n '{name:"fixture-market",plugins:[{name:"fixture-plugin",source:{source:"local",path:"./plugins/a"}},{name:"fixture-plugin",source:{source:"local",path:"./plugins/b"}}]}' > "$fixture/ambiguous/.agents/plugins/marketplace.json"
  if HARNESS_PLUGIN_RUNTIME=codex python3 "$fixture/ambiguous/plugins/caller/scripts/resolve-dependency.py" --plugin-root "$ambiguous_root" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/ambiguous.err"; then
    status=1
  else
    rg 'source_kind=repository reason=marketplace-entry' "$fixture/ambiguous.err" >/dev/null || status=1
  fi

  mkdir -p "$fixture/playbook/scripts" "$fixture/repo"
  local playbook_cache="$fixture/playbook/.harness-plugin-test-cache"
  mkdir -p "$playbook_cache"
  cp -R "$cache/." "$playbook_cache/"
  cp "$ROOT/shared/playbook/resolve.sh" "$fixture/playbook/scripts/resolve.sh"
  cp "$ROOT/shared/playbook/resolve-dependency.py" "$fixture/playbook/scripts/resolve-dependency.py"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fixture/playbook/scripts/validate-config.sh"
  chmod +x "$fixture/playbook/scripts/resolve.sh" "$fixture/playbook/scripts/validate-config.sh"
  printf '%s\n' 'version: 2' 'name: fixture-playbook' 'description: fixture' 'instructions:' '  execution: {directive: fixture}' 'requires:' '  - {plugin: fixture-plugin, marketplace: fixture-market}' 'steps:' '  - {id: invoke, skill: expected-skill, purpose: fixture}' > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$playbook_cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/skill.err"; then
    status=1
  else
    rg 'steps が指すスキルが requires のプラグインに無い: expected-skill' "$fixture/skill.err" >/dev/null || status=1
  fi

  cp "$fixture/playbook/playbook.yml" "$fixture/playbook/base.yml"
  yq -o=json -I=0 '.' "$fixture/playbook/base.yml" | jq '.requires[0].version="1.0.0"' | yq -P > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$playbook_cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/pin.err"; then status=1; fi
  yq -o=json -I=0 '.' "$fixture/playbook/base.yml" | jq '.requires[0]=.requires[0].plugin' | yq -P > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$playbook_cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/bare.err"; then status=1; fi

  return "$status"
}

validate_write_doc_cleanup_fixture() {
  local plugin="$ROOT/plugins/skills/authoring/write-doc-cleanup"
  local cleanup="$plugin/scripts/cleanup.py"
  local fixture="$TMP_ROOT/write-doc-cleanup"
  local repo="$fixture/repository"
  local final="$repo/final/document.md"
  local generated="$repo/work/generated/draft.md"
  local tracked_file="$repo/input.md"
  local status=0 out

  mkdir -p "$repo/final" "$(dirname "$generated")"
  git -C "$repo" init -q || return 1
  printf '%s\n' '# 最終資料' > "$final"
  printf '%s\n' '# 入力資料' > "$tracked_file"
  git -C "$repo" add final/document.md input.md || return 1
  git -C "$repo" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm fixture || return 1
  printf '%s\n' '一時生成物' > "$generated"

  echo 'Scenario: 最終資料を残して明示した未追跡の中間生成物だけを削除する'
  echo '  Given Git追跡済みの最終資料と未追跡の中間生成物がある'
  out=$(python3 "$cleanup" check --repo-root "$repo" --delete "$generated" --keep "$final") || status=1
  echo '  When 削除前検査を実行する'
  jq -e '.status=="checked" and (.deletable|length)==1 and (.deletable[0]|endswith("/work/generated/draft.md")) and (.preserved|length)==1 and (.preserved[0]|endswith("/final/document.md"))' >/dev/null <<<"$out" || status=1
  out=$(python3 "$cleanup" delete --repo-root "$repo" --delete "$generated" --keep "$final") || status=1
  echo '  Then 最終資料を残し、中間生成物と空の親directoryを削除する'
  jq -e '.status=="deleted" and (.deleted|length)==1 and (.deleted[0]|endswith("/work/generated/draft.md")) and (.preserved|length)==1 and (.preserved[0]|endswith("/final/document.md"))' >/dev/null <<<"$out" || status=1
  [ -f "$final" ] && [ ! -e "$generated" ] && [ ! -d "$repo/work" ] || status=1

  echo 'Scenario: 削除対象を明示しても追跡中の入力資料は削除しない'
  echo '  Given Git追跡済みの入力資料がある'
  if python3 "$cleanup" check --repo-root "$repo" --delete "$tracked_file" --keep "$final" > "$fixture/tracked.json"; then
    status=1
  else
    echo '  When 追跡中のファイルを削除候補にする'
    jq -e '.status=="rejected" and any(.errors[]; contains("Git追跡中"))' "$fixture/tracked.json" >/dev/null || status=1
  fi
  echo '  Then 拒否し、入力資料を残す'
  [ -f "$tracked_file" ] || status=1

  echo 'Scenario: 最終資料そのものを削除候補にしても削除しない'
  echo '  Given 保持対象として指定した最終資料がある'
  if python3 "$cleanup" check --repo-root "$repo" --delete "$final" --keep "$final" > "$fixture/keep-collision.json"; then
    status=1
  else
    echo '  When 同じpathを削除対象と保持対象に指定する'
    jq -e '.status=="rejected" and any(.errors[]; contains("保持対象と一致する"))' "$fixture/keep-collision.json" >/dev/null || status=1
  fi
  echo '  Then 拒否し、最終資料を残す'
  [ -f "$final" ] || status=1

  echo 'Scenario: repository外の明示パスは削除しない'
  printf '%s\n' '外部ファイル' > "$fixture/outside.md"
  if python3 "$cleanup" check --repo-root "$repo" --delete "$fixture/outside.md" --keep "$final" > "$fixture/outside.json"; then
    status=1
  else
    jq -e '.status=="rejected" and any(.errors[]; contains("repository内のファイルではない"))' "$fixture/outside.json" >/dev/null || status=1
  fi

  return "$status"
}

jq -r '.plugins[].name' "$ROOT/.agents/plugins/marketplace.json" | sort > "$TMP_ROOT/expected"
jq -r '.name' "$ROOT/plugins/.codex-plugin/plugin.json" | sort > "$TMP_ROOT/actual"
diff -u "$TMP_ROOT/expected" "$TMP_ROOT/actual" >/dev/null && pass "公開インストール対象はwrite-doc playbook packageだけ" || fail "plugin集合"
for market in .agents/plugins/marketplace.json .claude-plugin/marketplace.json; do
  jq -r '.plugins[].name' "$ROOT/$market" | sort > "$TMP_ROOT/market"
  diff -u "$TMP_ROOT/expected" "$TMP_ROOT/market" >/dev/null && pass "$market plugin集合" || fail "$market plugin集合"
done

while IFS='|' read -r name version rel; do
  if jq -e --arg n "$name" --arg v "$version" '.name==$n and .version==$v' "$ROOT/$rel/.codex-plugin/plugin.json" >/dev/null \
    && jq -e --arg n "$name" --arg v "$version" '.name==$n and .version==$v' "$ROOT/$rel/.claude-plugin/plugin.json" >/dev/null; then
    pass "$name manifest identity"
  else
    fail "$name manifest identity"
  fi
done < <(jq -r '.plugins[] | [.name,.version,(.source.path | ltrimstr("./"))] | join("|")' "$ROOT/.agents/plugins/marketplace.json")
bash "$ROOT/scripts/validate-marketplace.sh" "$ROOT" && pass "marketplace配布契約" || fail "marketplace配布契約"
bash "$ROOT/scripts/test-marketplace-validation.sh" && pass "marketplace配布契約の負例" || fail "marketplace配布契約の負例"

pb="$ROOT/plugins/playbooks/authoring/write-doc"
cmp -s "$ROOT/shared/playbook/resolve.sh" "$pb/scripts/resolve.sh" && pass "playbook resolver同期" || fail "playbook resolver同期"
cmp -s "$ROOT/shared/playbook/resolve-dependency.py" "$pb/scripts/resolve-dependency.py" && pass "dependency resolver同期" || fail "dependency resolver同期"
if yq -o=json -I=0 '.' "$pb/playbook.yml" | jq -e '.version==2 and (.requires|length>0) and all(.requires[]; .marketplace=="write-doc" and ((keys|sort)==["marketplace","plugin"]))' >/dev/null; then
  pass "完全修飾した同一marketplace依存"
else
  fail "playbook依存契約"
fi
if yq -o=json -I=0 '.' "$pb/playbook.yml" | jq -e 'all(.requires[]; .plugin!="write-doc-cleanup") and all(.steps[]; (.skill // "")!="remove-intermediate-artifacts" and (.playbook // "")!="write-doc-cleanup")' >/dev/null \
  && rg -F '`write-doc` playbookは削除を実行せず' "$ROOT/plugins/skills/authoring/write-doc-cleanup/README.md" >/dev/null; then
  pass "write-docとcleanupの責務境界"
else
  fail "write-docとcleanupの責務境界"
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

cleanup="$ROOT/plugins/skills/authoring/write-doc-cleanup"
if cmp -s "$ROOT/shared/prepare.sh" "$cleanup/scripts/prepare.sh" \
  && rg -F '明示パス' "$cleanup/SKILL.md" >/dev/null \
  && rg -F '最終資料' "$cleanup/SKILL.md" >/dev/null; then
  pass "write-doc-cleanupはwrite-doc内で一意に配布される"
else
  fail "write-doc-cleanupの配布物または安全境界"
fi

prepare_sync=1
while IFS= read -r script; do cmp -s "$ROOT/shared/prepare.sh" "$script" || prepare_sync=0; done < <(find "$ROOT/plugins/skills" -path '*/scripts/prepare.sh' -type f | sort)
resolve_sync=1
while IFS= read -r script; do cmp -s "$ROOT/shared/skill/resolve.sh" "$script" || resolve_sync=0; done < <(find "$ROOT/plugins/skills" -path '*/scripts/resolve.sh' -type f | sort)
if [ "$prepare_sync" -eq 1 ] && [ "$resolve_sync" -eq 1 ]; then
  pass "shared prepare/skill resolver同期"
else
  fail "shared prepare/skill resolver同期"
fi

validate_write_doc_cleanup_fixture && pass "中間成果物の明示削除と保持境界" || fail "中間成果物の明示削除と保持境界"

content_types="$ROOT/plugins/skills/authoring/content-types"
specialist_details=(
  "$content_types/references/detail/product.md"
  "$content_types/references/detail/domain.md"
  "$content_types/references/detail/data-modeling.md"
  "$content_types/references/detail/user-journey-bdd.md"
)
specialist_examples=(
  "$content_types/assets/examples/north-star.example.md"
  "$content_types/assets/examples/strategy.example.md"
  "$content_types/assets/examples/domain-rule.example.md"
  "$content_types/assets/examples/rdb-logical-data-modeling.example.md"
  "$content_types/assets/examples/rdb-physical-design.example.md"
  "$content_types/assets/examples/user-journey-bdd.example.md"
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

journey_template="$content_types/assets/templates/user-journey-bdd.md"
journey_example="$content_types/assets/examples/user-journey-bdd.example.md"
journey_detail="$content_types/references/detail/user-journey-bdd.md"
if rg -F 'user-journey-bdd:' "$content_types/assets/template-examples.yml" >/dev/null \
  && rg -F 'ユーザーが目的を達成するまで' "$content_types/references/catalog.md" >/dev/null \
  && rg -F '何がJourneyで何がJourneyでないか' "$journey_detail" >/dev/null \
  && rg -F '呼び出し元' "$journey_detail" >/dev/null \
  && rg -F '**接続**:' "$journey_template" >/dev/null \
  && rg -F '**Journeyとして扱う理由**:' "$journey_template" >/dev/null \
  && rg -F '**Journeyに含めない問い**:' "$journey_template" >/dev/null \
  && [ "$(rg -c '^## 場面 [0-9]+:' "$journey_example")" -ge 4 ] \
  && ! rg -n '実行環境|試行回数|実行証拠|flaky|APIを呼び出|画面を操作' "$journey_example" >/dev/null; then
  pass "ユーザー目的達成BDD型は判定済みJourneyの構成だけを提供"
else
  fail "ユーザー目的達成BDD型に必要な構成が無いか別責務が混入"
fi

if ! rg -n 'e2e-bdd|E2E BDD|E2E-BDD' "$content_types" >/dev/null; then
  pass "テスト実行と誤読される旧文書型名なし"
else
  fail "テスト実行と誤読される旧文書型名が残存"
fi

doc_render="$ROOT/plugins/skills/authoring/doc-render"
if rg -F '`writing-rules` が付与済みの役だけ' "$doc_render/references/emphasis.md" >/dev/null \
  && rg -F '`writing-rules` が確定した出典リンク' "$doc_render/references/citation.md" >/dev/null \
  && rg -F '`visual-guidance` から受け取る' "$doc_render/references/figures.md" >/dev/null \
  && rg -F '受け取った意味上の役を媒体表現へ写す' "$doc_render/config/defaults.yml" >/dev/null \
  && ! rg -n 'R[0-9]+|引用の量|表で足りるなら|何に付けるか' "$doc_render/references" >/dev/null; then
  pass "doc-renderは確定済みの役から媒体表現への写像だけを持つ"
else
  fail "doc-renderに文章判断または図の選択が混入"
fi

roles="$pb/references/roles.md"
if rg -F '役の付与は `writing-rules`' "$roles" >/dev/null \
  && rg -F '| **図の型** | `visual-guidance` |' "$roles" >/dev/null \
  && ! rg -n '<mark|<figure|<span class|インラインSVG|外部SVG' "$roles" >/dev/null; then
  pass "write-docの役契約は判断者だけを接続"
else
  fail "write-docの役契約が媒体表現を再定義"
fi

syntax_failed=0
while IFS= read -r script; do bash -n "$script" || syntax_failed=1; done < <(find "$ROOT" -type f -name '*.sh' | sort)
[ "$syntax_failed" -eq 0 ] && pass "shell構文" || fail "shell構文"
python_failed=0
while IFS= read -r script; do PYTHONPYCACHEPREFIX="$TMP_ROOT/pycache" python3 -m py_compile "$script" || python_failed=1; done < <(find "$ROOT" -type f -name '*.py' | sort)
[ "$python_failed" -eq 0 ] && pass "Python構文" || fail "Python構文"

python3 "$ROOT/scripts/test-reader-contract.py" && pass "読者の前提と本文確認の工程間引き継ぎ" || fail "読者の前提と本文確認の工程間引き継ぎ"

printf '\nValidation: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
