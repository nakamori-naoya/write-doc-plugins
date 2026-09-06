#!/usr/bin/env bash
# Scenario: write-doc marketplaceが6 pluginで自己完結し、両runtimeで解決できる
set -uo pipefail
# **依存解決のenvを継承しない。** 統合検証では各repoのvalidate.shがこのenvの設定された
# 状態で走る。継承すると、repository解決・dependency-missing・marketplace-entryの
# 負の試験が「たまたま別の場所で見つかる」ことで破れる。必要な検査だけが自分で設定する。
unset HARNESS_PLUGIN_DEV_ROOTS HARNESS_PLUGIN_CACHE_ROOT
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$ROOT/scripts/test-hardening.py" || exit 1
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/write-doc-validation.XXXXXX") || exit 2
export TMPDIR="$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT
passed=0 failed=0
pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }

# owning_bundle は所属package宣言から内外を判定する。合成fixtureの呼び出し元にも
# bundle manifest（marketplace 宣言）が要る。
write_bundle_manifest() {
  local dir="$1" name="$2" market="$3" internals="${4:-{\}}"
  local runtime
  for runtime in codex claude; do
    mkdir -p "$dir/.$runtime-plugin"
    jq -n --arg n "$name" --arg m "$market" --argjson i "$internals" \
      '{name:$n,version:"1.0.0",metadata:{harness:{installationSurface:"playbook-package",marketplace:$m,internalPlugins:$i,contractVersion:1}}}' \
      > "$dir/.$runtime-plugin/plugin.json"
  done
}

# 外部依存として解決できる provider は、公開playbookと implements を持つ。
# **宣言の無いpluginは外部から解決できない。** fixtureも本番と同じ形にする。
write_provider_package() {
  local dir="$1" plugin="$2" market="$3" version="$4"
  local runtime
  mkdir -p "$dir/pb/scripts"
  for runtime in codex claude; do
    mkdir -p "$dir/.$runtime-plugin"
    jq -n --arg n "$plugin" --arg v "$version" --arg m "$market" \
      '{name:$n,version:$v,skills:["./pb"],metadata:{harness:{installationSurface:"playbook-package",
        marketplace:$m,entryRoot:"./pb",playbooks:{"fixture-playbook":"./pb"},internalPlugins:{},
        contractVersion:1,implements:[{id:($m+"/"+$n),version:1,kind:"playbook",playbook:"fixture-playbook"}]}}}' \
      > "$dir/.$runtime-plugin/plugin.json"
  done
  printf '%s\n' '---' 'name: wrong-skill' 'description: fixture' '---' > "$dir/pb/SKILL.md"
  printf '%s\n' 'version: 2' 'name: fixture-playbook' 'description: fixture' > "$dir/pb/playbook.yml"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$dir/pb/scripts/resolve.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$dir/pb/scripts/prepare.sh"
  chmod +x "$dir/pb/scripts/resolve.sh" "$dir/pb/scripts/prepare.sh"
}

validate_dependency_resolution_contract() {
  local resolver="$ROOT/shared/playbook/resolve-dependency.py"
  local repo_resolver="$ROOT/plugins/playbooks/authoring/write-doc/scripts/resolve-dependency.py"
  local repo_root="$ROOT/plugins/playbooks/authoring/write-doc"
  local fixture="$TMP_ROOT/dependency-resolution"
  local cache="$fixture/empty/.harness-plugin-test-cache"
  local isolated_resolver="$fixture/empty/scripts/resolve-dependency.py"
  local isolated_root
  local status=0
  local out

  mkdir -p "$fixture/empty/scripts"
  cp "$resolver" "$isolated_resolver"
  isolated_root=$(cd "$fixture/empty" && pwd -P)
  write_bundle_manifest "$isolated_root" caller-plugin caller-market
  for version in 1.0.0 9.9.9; do
    write_provider_package "$cache/fixture-market/fixture-plugin/$version" fixture-plugin fixture-market "$version"
  done

  local marketplace repository_plugin
  marketplace=$(jq -r '.name' "$ROOT/.agents/plugins/marketplace.json")
  repository_plugin=$(jq -r '.plugins[0].name' "$ROOT/.agents/plugins/marketplace.json")
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" python3 "$repo_resolver" --plugin-root "$repo_root" --plugin "$repository_plugin" --marketplace "$marketplace" 2> "$fixture/repository-$runtime.err")
    jq -e '.dependency_scope=="internal"' >/dev/null <<<"$out" || status=1
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
  write_bundle_manifest "$installed_root" caller-plugin caller-market
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" python3 "$installed_caller/scripts/resolve-dependency.py" --plugin-root "$installed_root" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/installed-$runtime.err")
    jq -e --arg runtime "$runtime" '.runtime==$runtime and .version=="9.9.9" and .source_kind=="installed-cache"' >/dev/null <<<"$out" || status=1
  done

  write_provider_package "$fixture/dev" fixture-plugin fixture-market 3.4.5
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
  write_bundle_manifest "$fixture/ambiguous/plugins" caller-plugin caller-market
  jq -n '{name:"fixture-market",plugins:[{name:"fixture-plugin",source:{source:"local",path:"./plugins/a"}},{name:"fixture-plugin",source:{source:"local",path:"./plugins/b"}}]}' > "$fixture/ambiguous/.agents/plugins/marketplace.json"
  if HARNESS_PLUGIN_RUNTIME=codex python3 "$fixture/ambiguous/plugins/caller/scripts/resolve-dependency.py" --plugin-root "$ambiguous_root" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/ambiguous.err"; then
    status=1
  else
    rg 'source_kind=repository reason=marketplace-entry' "$fixture/ambiguous.err" >/dev/null || status=1
  fi

  mkdir -p "$fixture/playbook/scripts" "$fixture/repo" "$fixture/playbook/internal"
  local playbook_cache="$fixture/playbook/.harness-plugin-test-cache"
  mkdir -p "$playbook_cache"
  cp -R "$cache/." "$playbook_cache/"
  # 内部依存として解決させる。外部依存なら implements 宣言が要るので、
  # steps の skill 検査へ到達する前に external-dependency-no-playbook で落ちる。
  write_bundle_manifest "$fixture/playbook" caller-plugin fixture-market '{"fixture-plugin":"./internal"}'
  for runtime in codex claude; do
    mkdir -p "$fixture/playbook/internal/.$runtime-plugin"
    printf '%s\n' '{"name":"fixture-plugin","version":"1.0.0"}' > "$fixture/playbook/internal/.$runtime-plugin/plugin.json"
  done
  printf '%s\n' '---' 'name: wrong-skill' 'description: fixture' '---' > "$fixture/playbook/internal/SKILL.md"
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
# runtime-source 由来の複製は manifest（sha256）で全件検査する。cmp では pin した正本版とのずれを検出できない。
python3 "$ROOT/scripts/sync-runtime.py" --check >/dev/null && pass "runtime複製とmanifestの一致" || fail "runtime複製とmanifestの一致"
# **manifestとの一致だけでは、正本が進んだことを検出できない。** 兄弟checkoutの正本と直接突き合わせる。
# 正本が無ければ緑にしない。「正本を見ていない」ことを「一致している」と読み替えさせない。
RUNTIME_SOURCE="${HARNESS_RUNTIME_SOURCE:-$ROOT/../product-planning-plugins/shared/runtime-source}"
if [ ! -f "$RUNTIME_SOURCE/sync-runtime.py" ]; then
  fail "runtime正本が無い: ${RUNTIME_SOURCE}（兄弟checkoutを置くか HARNESS_RUNTIME_SOURCE で指す）"
elif python3 "$ROOT/scripts/sync-runtime.py" --check --source "$RUNTIME_SOURCE" > "$TMP_ROOT/runtime-source.json"; then
  pass "runtime複製が正本checkoutと一致"
else
  fail "runtime複製が正本checkoutとずれている: $(jq -c '.changed // .error' "$TMP_ROOT/runtime-source.json" 2>/dev/null)"
fi
# state.py は runtime-manifest の配布対象外なので、shared と配布物の一致をここで検査する。
cmp -s "$ROOT/shared/playbook/state.py" "$pb/scripts/state.py" && pass "playbook state同期" || fail "playbook state同期"
# 依存は marketplace / plugin で完全修飾する。同梱plugin以外に許すのは grill@grill だけ。
# **外部依存は playbook: でしか呼ばない。** skill: / script: で掴んだ瞬間に規則違反である。
if yq -o=json -I=0 '.' "$pb/playbook.yml" | jq -e '.version==2 and (.requires|length>0)
    and all(.requires[]; ((keys|sort)==["marketplace","plugin"]) and (.marketplace=="write-doc" or (.marketplace=="grill" and .plugin=="grill")))
    and any(.requires[]; .plugin=="grill")
    and any(.steps[]; .playbook=="grill" and (.when|type=="string") and (.provides==["decisions"]))
    and all(.steps[]; (.skill // "")!="grill" and (.plugin // "")!="grill")' >/dev/null; then
  pass "完全修飾した依存（同梱pluginとgrill@grill）と、playbookとして呼ぶ条件付きsettle工程"
else
  fail "playbook依存契約"
fi

# ── 公開契約 ────────────────────────────────────────────────────
# **公開面は CONTRACT.md が正本である。** 入口4点が実在し、契約の必須節が揃っていること。
contract_ok=1
for f in "$pb/CONTRACT.md" "$pb/SKILL.md" "$pb/playbook.yml" "$pb/scripts/resolve.sh" \
         "$pb/scripts/prepare.sh" "$pb/scripts/contract-io.py" "$pb/scripts/validate-config.sh" \
         "$pb/scripts/validate-input.sh"; do
  [ -f "$f" ] || { echo "  必須ファイルが無い: $f"; contract_ok=0; }
done
for section in '^## 1\. 入口' '^## 2\. 入力 schema' '^## 3\. 出力 schema' '^## 4\. 契約の語' '^## 5\. 保証' '^## 6\. 非契約'; do
  rg -q "$section" "$pb/CONTRACT.md" || { echo "  CONTRACT.mdに必須の節が無い: $section"; contract_ok=0; }
done
while IFS= read -r link; do
  [ -e "$pb/$link" ] || { echo "  契約文書の相対リンクが切れている: $link"; contract_ok=0; }
done < <(rg -o --no-filename '\]\(([^):]+\.md)\)' -r '$1' "$pb/SKILL.md" "$pb/CONTRACT.md" | sort -u)
# **入れ子実行では prepare をやり直さない。** やり直すと呼び出し元が載せた
# 入力・scope・束縛が消える。契約文書と入口SKILL.mdの両方に書いてあること。
rg -q '^### 呼び出し手順' "$pb/CONTRACT.md" || { echo '  CONTRACT.mdに呼び出し手順の節が無い'; contract_ok=0; }
rg -q 'E1 を自分でやり直さない' "$pb/CONTRACT.md" || { echo '  CONTRACT.mdにprepareを再実行しない旨が無い'; contract_ok=0; }
rg -q 'prepare を実行しない' "$pb/SKILL.md" || { echo '  SKILL.mdに入れ子実行でprepareを再実行しない旨が無い'; contract_ok=0; }
rg -q 'DEP_CFG` を渡して' "$pb/SKILL.md" || { echo '  SKILL.mdに解決済みYAMLを依存先へ渡す旨が無い'; contract_ok=0; }
# **外部依存を指す形は .root（直下3点）と .entry だけである。** .skills.<名前> は禁止。
rg -q '\$\{\.deps\.write-doc\.entry\}' "$pb/CONTRACT.md" || { echo '  CONTRACT.mdのE4がentry形でない'; contract_ok=0; }
rg -q '\$\{\.deps\.grill\.entry\}' "$pb/SKILL.md" || { echo '  SKILL.mdの依存先入口がentry形でない'; contract_ok=0; }
if rg -n '\$\{\.deps\.[A-Za-z0-9_-]+\.skills\.' "$pb/SKILL.md" "$pb/CONTRACT.md" "$pb/README.md" >/dev/null; then
  echo '  外部依存を .skills.<名前> で指している'; contract_ok=0
fi
[ "$contract_ok" -eq 1 ] && pass "公開契約の文書と入口4点" || fail "公開契約の文書と入口4点"

# **両runtimeのmanifestが同一値で契約を自己宣言し、実装済みの型がカタログと一致する。**
# カタログが正本なので、型を足したら implements も同時に更新する。
if python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path
root = Path(sys.argv[1])
catalog = (root / 'plugins/skills/authoring/content-types/references/catalog.md').read_text(encoding='utf-8')
slugs = re.findall(r'^\| \*\*[^|]+\*\* \| `([a-z0-9-]+)`', catalog, re.M)
if not slugs or len(slugs) != len(set(slugs)):
    print('  カタログの型slugを読めない'); raise SystemExit(1)
seen = []
for runtime in ('claude', 'codex'):
    harness = json.loads((root / f'plugins/.{runtime}-plugin/plugin.json').read_text(encoding='utf-8'))['metadata']['harness']
    seen.append(harness)
    if harness.get('marketplace') != 'write-doc':
        print(f'  {runtime}: metadata.harness.marketplace が write-doc でない'); raise SystemExit(1)
    entries = [e for e in harness.get('implements', []) if e.get('id') == 'write-doc/write-doc']
    if len(entries) != 1:
        print(f'  {runtime}: implements に write-doc/write-doc が1件無い'); raise SystemExit(1)
    entry = entries[0]
    if entry.get('version') != 1 or entry.get('kind') != 'playbook' or entry.get('playbook') != 'write-doc':
        print(f'  {runtime}: implements の契約版・kind・playbookが違う'); raise SystemExit(1)
    if entry.get('types') != slugs:
        print(f'  {runtime}: implements[].types がカタログと一致しない'); raise SystemExit(1)
if seen[0] != seen[1]:
    print('  claude と codex の metadata.harness が一致しない'); raise SystemExit(1)
PY
then
  pass "契約の自己宣言（marketplace / implements）とカタログ28型の一致"
else
  fail "契約の自己宣言またはカタログとの一致"
fi
if yq -o=json -I=0 '.' "$pb/playbook.yml" | jq -e 'all(.requires[]; .plugin!="write-doc-cleanup") and all(.steps[]; (.skill // "")!="remove-intermediate-artifacts" and (.playbook // "")!="write-doc-cleanup")' >/dev/null \
  && rg -F '`write-doc` playbookは削除を実行せず' "$ROOT/plugins/skills/authoring/write-doc-cleanup/README.md" >/dev/null; then
  pass "write-docとcleanupの責務境界"
else
  fail "write-docとcleanupの責務境界"
fi

# ── 依存先の実配布物に対する解決 ─────────────────────────────────
# **fixtureだけで緑にしない。** grillは別marketplaceなので、その実配布物（plugins/）を
# そのままinstalled-cacheへ写して解決させる。合成fixtureで緑になる状態を作らない。
mkdir -p "$TMP_ROOT/repo"
GRILL_PACKAGE="${HARNESS_GRILL_PACKAGE:-$ROOT/../grill-plugins/plugins}"
RESOLUTION_COPY="$TMP_ROOT/resolution-copy"
mkdir -p "$RESOLUTION_COPY"
cp -R "$ROOT/plugins" "$ROOT/.claude-plugin" "$ROOT/.agents" "$RESOLUTION_COPY/"
copy_pb="$RESOLUTION_COPY/plugins/playbooks/authoring/write-doc"
grill_cache="$copy_pb/.harness-plugin-test-cache"
if [ ! -f "$GRILL_PACKAGE/.claude-plugin/plugin.json" ]; then
  fail "依存先の実配布物が無い: ${GRILL_PACKAGE}（兄弟checkoutを置くか HARNESS_GRILL_PACKAGE で指す）"
else
  grill_version=$(jq -r '.version' "$GRILL_PACKAGE/.claude-plugin/plugin.json")
  mkdir -p "$grill_cache/grill/grill"
  cp -R "$GRILL_PACKAGE" "$grill_cache/grill/grill/$grill_version"
  cp "$copy_pb/playbook.yml" "$TMP_ROOT/write-doc.playbook.bundled.yml"
  probe_resolve() { HARNESS_PLUGIN_RUNTIME="$1" HARNESS_PLUGIN_CACHE_ROOT="$grill_cache" \
    bash "$copy_pb/scripts/resolve.sh" "$TMP_ROOT/repo"; }

  # (a) 公開playbookとして解決でき、契約の自己宣言と入口4点が見える。
  for runtime in codex claude; do
    out="$TMP_ROOT/$runtime.yml"
    if probe_resolve "$runtime" > "$out" 2> "$out.err" \
      && yq -o=json -I=0 '.' "$out" | jq -e --arg runtime "$runtime" 'all(.deps[]; .runtime==$runtime)
          and all(.deps | to_entries[] | select(.key!="grill");
                  .value.source_kind=="repository" and .value.dependency_scope=="internal")
          and .deps.grill.source_kind=="installed-cache"
          and .deps.grill.dependency_scope=="external" and .deps.grill.contract=="grill/grill"
          and (.deps.grill.implements|map(select(.id=="grill/grill" and .version==1 and .kind=="playbook"))|length==1)
          and (.deps.grill.entry|test("/playbooks/dialogue/grill/SKILL.md$"))
          and (.deps.grill as $g | $g.entry == $g.root + "/SKILL.md")
          and (.deps.grill.entry_skill|type=="string" and length>0)' >/dev/null; then
      entries_ok=1
      while IFS= read -r member; do
        [ -f "$member" ] || { echo "  公開面の入口が無い: $member"; entries_ok=0; }
      done < <(yq -o=json -I=0 '.' "$out" | jq -r '(.deps.grill.root as $r
        | ["playbook.yml","scripts/resolve.sh","scripts/prepare.sh"][] | $r + "/" + .), .deps.grill.entry')
      [ "$entries_ok" -eq 1 ] && pass "$runtime 実配布物のgrillを公開playbookとして解決" \
        || fail "$runtime 公開面の入口4点"
    else
      fail "$runtime 実配布物のgrillを公開playbookとして解決: $(head -2 "$out.err" 2>/dev/null)"
    fi
  done

  # (b) 外部依存を skill: では掴めない（最上位規則の機械的強制）。
  yq -o=json -I=0 '.' "$TMP_ROOT/write-doc.playbook.bundled.yml" \
    | jq '(.steps[] | select(.playbook=="grill")) |= (del(.playbook) | .skill="grill")' \
    | yq -P > "$copy_pb/playbook.yml"
  if probe_resolve codex >/dev/null 2> "$TMP_ROOT/skill-grill.err"; then
    fail "外部依存のgrillを skill: step で呼べてしまう"
  elif ! rg -q 'external-dependency-skill' "$TMP_ROOT/skill-grill.err"; then
    fail "外部skill参照を期待した理由で拒否できない: $(head -1 "$TMP_ROOT/skill-grill.err")"
  else
    pass "外部依存を skill: で掴むと external-dependency-skill で止まる"
  fi

  # (c) 相手の内部pluginは外部から指定しても解決しない。
  # 内部pluginの名前は相手のmanifestから取る。**契約に無い名前をこちらへ書かない。**
  grill_internal=$(jq -r '.metadata.harness.internalPlugins | keys[0]' "$GRILL_PACKAGE/.claude-plugin/plugin.json")
  yq -o=json -I=0 '.' "$TMP_ROOT/write-doc.playbook.bundled.yml" \
    | jq --arg p "$grill_internal" '(.requires[] | select(.plugin=="grill")) |= {plugin:$p, marketplace:"grill"}' \
    | yq -P > "$copy_pb/playbook.yml"
  if probe_resolve codex >/dev/null 2> "$TMP_ROOT/internal-grill.err"; then
    fail "外部packageの内部pluginが解決できてしまう"
  elif ! rg -q 'dependency-missing' "$TMP_ROOT/internal-grill.err"; then
    fail "内部pluginの外部指定を期待した理由で拒否できない: $(head -1 "$TMP_ROOT/internal-grill.err")"
  else
    pass "外部packageの内部pluginは dependency-missing で止まる"
  fi
  cp "$TMP_ROOT/write-doc.playbook.bundled.yml" "$copy_pb/playbook.yml"

  # (d) 消費側の文書・設定・scriptに相手の内部名が漏れていない。
  # 検出語は相手のmanifestから生成するので、dev-mapで実配布物を指す。
  devmap="$TMP_ROOT/dev-map.json"
  jq -n --arg root "$(cd "$GRILL_PACKAGE" && pwd -P)" '{schema:1,dependencies:{"grill/grill":$root}}' > "$devmap"
  lint_ok=1
  for runtime in codex claude; do
    HARNESS_PLUGIN_DEV_ROOTS="$devmap" python3 "$ROOT/scripts/lint-consumer-contract.py" \
      --repo "$ROOT" --runtime "$runtime" || lint_ok=0
  done
  [ "$lint_ok" -eq 1 ] && pass "消費側に依存先の内部名が漏れていない" || fail "消費側に依存先の内部名が漏れている"

  # ── 契約の入出力（提供側の変換層） ─────────────────────────────
  # **E1 を実際に通す。** prepare.sh --input=<abs> が .input を載せた解決済みYAMLを返し、
  # そこから契約入力を読めるところまでを、合成configではなく本番の経路で確かめる。
  # 入力pathは正規形でなければならない（祖先のsymlinkを許さない検査に掛かる）。
  mkdir -p "$TMP_ROOT/contract-io"
  io=$(cd "$TMP_ROOT/contract-io" && pwd -P)
  mkdir -p "$io/material" "$io/docs" "$io/out"
  printf '%s\n' 'material: fixture' > "$io/material/material.yml"
  printf '%s\n' '# 追加指示' > "$io/material/deliverable.md"
  printf '%s\n' '# 既存資料' > "$io/docs/existing.md"
  write_contract_input() { # write_contract_input <出力file> <jq式>
    jq -n --arg m "$io/material/material.yml" --arg d "$io/docs" --arg r "$io/material/deliverable.md" \
      --arg u "$io/docs/existing.md" --arg o "$io/out/output.yml" \
      '{contract:"write-doc/write-doc",version:1,document_type:"domain-rule",material:[$m],
        output_format:"markdown",output_directory:$d,name:"order-cancellation.md",
        references:[$r],output_to:$o}' | jq "$2" | yq -P > "$1"
  }
  contract_runtime=codex
  contract_prepare() { HARNESS_PLUGIN_RUNTIME="$contract_runtime" HARNESS_PLUGIN_CACHE_ROOT="$grill_cache" \
    bash "$copy_pb/scripts/prepare.sh" "$TMP_ROOT/repo" --input="$1"; }

  write_contract_input "$io/input.yml" '.'
  for contract_runtime in codex claude; do
  if cfg=$(contract_prepare "$io/input.yml" 2> "$io/prepare.err") \
    && parsed=$(python3 "$copy_pb/scripts/contract-io.py" read --config "$cfg" 2> "$io/read.err") \
    && jq -e --arg d "$io/docs" --arg m "$io/material/material.yml" '.present==true
        and .document_type=="domain-rule" and .material==[$m] and .output_format=="markdown"
        and .output_directory==$d and .name=="order-cancellation.md" and .update_target==null
        and (.references|length)==1' >/dev/null <<<"$parsed"; then
    printf '{"status":"completed","path":"%s","document_type":"domain-rule","output_format":"markdown"}\n' \
      "$io/docs/order-cancellation.md" > "$io/result.json"
    printf '%s\n' '# 保存済み' > "$io/docs/order-cancellation.md"
    if python3 "$copy_pb/scripts/contract-io.py" write --config "$cfg" --result "$io/result.json" >/dev/null 2> "$io/write.err" \
      && yq -o=json -I=0 '.' "$io/out/output.yml" | jq -e --arg p "$io/docs/order-cancellation.md" \
        '.contract=="write-doc/write-doc" and .version==1 and .status=="completed" and .path==$p
         and .document_type=="domain-rule" and .output_format=="markdown"' >/dev/null; then
      pass "$contract_runtime 契約入力を .input として受け、output_to へ契約出力を書く"
    else
      fail "$contract_runtime 契約出力を output_to へ書けない: $(head -1 "$io/write.err" 2>/dev/null)"
    fi
  else
    fail "$contract_runtime 契約入力を .input として受け取れない: $(head -2 "$io/prepare.err" "$io/read.err" 2>/dev/null | tr '\n' ' ')"
  fi
  done
  contract_runtime=codex

  # 負の試験：入口で止まるもの（契約ID・実装していない型）と、変換層で止まるもの（排他規則）。
  entry_negative_ok=1
  write_contract_input "$io/bad-contract.yml" '.contract="other/other"'
  contract_prepare "$io/bad-contract.yml" >/dev/null 2> "$io/bad-contract.err" \
    && { echo "  契約IDが違う入力を受け取ってしまう"; entry_negative_ok=0; }
  rg -q 'input-contract-mismatch' "$io/bad-contract.err" || { echo "  契約ID不一致を期待した理由で拒否できない"; entry_negative_ok=0; }
  write_contract_input "$io/bad-type.yml" '.document_type="not-a-type"'
  contract_prepare "$io/bad-type.yml" >/dev/null 2> "$io/bad-type.err" \
    && { echo "  実装していない文書型を受け取ってしまう"; entry_negative_ok=0; }
  rg -q 'input-capability-unsupported' "$io/bad-type.err" || { echo "  未実装の型を期待した理由で拒否できない"; entry_negative_ok=0; }
  write_contract_input "$io/bad-output.yml" '.output_to="out/output.yml"'
  contract_prepare "$io/bad-output.yml" >/dev/null 2> "$io/bad-output.err" \
    && { echo "  相対pathのoutput_toを受け取ってしまう"; entry_negative_ok=0; }
  rg -q 'input-output-unwritable' "$io/bad-output.err" || { echo "  output_toを期待した理由で拒否できない"; entry_negative_ok=0; }
  [ "$entry_negative_ok" -eq 1 ] && pass "契約ID・文書型・output_toは共通resolverが入口で止める" || fail "契約ID・文書型・output_toが入口で止まらない"

  # 契約固有のschemaは入口hook（scripts/validate-input.sh）が止める。
  # **変換層を呼ぶ前に落ちること**を、prepare.sh 経由で確かめる。
  schema_negative_ok=1
  while IFS='|' read -r label expression want; do
    write_contract_input "$io/bad.yml" "$expression"
    if contract_prepare "$io/bad.yml" >/dev/null 2> "$io/bad-prepare.err"; then
      echo "  受け取ってはいけない入力を入口が受け取る: $label"; schema_negative_ok=0
    elif ! rg -q 'error:input-schema' "$io/bad-prepare.err" || ! rg -q "$want" "$io/bad-prepare.err"; then
      echo "  期待した理由で拒否できない: $label ($(head -1 "$io/bad-prepare.err"))"; schema_negative_ok=0
    fi
  done <<EOF
保存先が両方|.update_target="$io/docs/existing.md"|field=update_target
保存先が無い|del(.output_directory,.name)|field=name
output_directoryだけ|del(.name)|field=name
materialが空|.material=[]|field=material
materialが単一path|.material="$io/material/material.yml"|field=material
未知のキー|.extra="x"|reason=unknown-keys
提供側のreferencesを渡す|.references=["$copy_pb/references/roles.md"]|field=references
EOF
  [ "$schema_negative_ok" -eq 1 ] && pass "契約入力schemaの負例を入口hookが exit 2 で止める" || fail "契約入力schemaの負例"

  # **output_directory を省いた新規作成は通る。** directory は利用者の設定（routes）が決める。
  # ここで exit 2 にすると 4.0.0 の型ごとの出力先ルーティングが使えなくなる。
  write_contract_input "$io/routed.yml" 'del(.output_directory) | .output_to="'"$io"'/out/routed.yml"'
  if cfg=$(contract_prepare "$io/routed.yml" 2> "$io/routed.err") \
    && parsed=$(python3 "$copy_pb/scripts/contract-io.py" read --config "$cfg" 2> "$io/routed-read.err") \
    && jq -e '.present==true and .name=="order-cancellation.md" and .output_directory==null
        and .update_target==null' >/dev/null <<<"$parsed"; then
    mkdir -p "$io/routed-dir"
    printf '%s\n' '# routes が決めた保存先' > "$io/routed-dir/order-cancellation.md"
    printf '{"status":"completed","path":"%s","document_type":"domain-rule","output_format":"markdown"}\n' \
      "$io/routed-dir/order-cancellation.md" > "$io/routed-result.json"
    if python3 "$copy_pb/scripts/contract-io.py" write --config "$cfg" --result "$io/routed-result.json" >/dev/null 2> "$io/routed-write.err" \
      && yq -o=json -I=0 '.' "$io/out/routed.yml" | jq -e --arg p "$io/routed-dir/order-cancellation.md" '.status=="completed" and .path==$p' >/dev/null; then
      pass "output_directoryを省いた新規作成は通り、保存先は利用者の設定が決める"
    else
      fail "設定が決めた保存先の結果を返せない: $(head -1 "$io/routed-write.err" 2>/dev/null)"
    fi
    # ファイル名は呼び出し元のものである。違う名前で保存したら受け取らない。
    printf '%s\n' '# 別名' > "$io/routed-dir/other.md"
    printf '{"status":"completed","path":"%s","document_type":"domain-rule","output_format":"markdown"}\n' \
      "$io/routed-dir/other.md" > "$io/routed-bad.json"
    if python3 "$copy_pb/scripts/contract-io.py" write --config "$cfg" --result "$io/routed-bad.json" >/dev/null 2> "$io/routed-bad.err"; then
      fail "nameと違うファイル名で保存した結果を受け取ってしまう"
    elif ! rg -q 'output-schema' "$io/routed-bad.err"; then
      fail "nameと違うファイル名を期待した理由で拒否できない"
    else
      pass "nameと違うファイル名で保存した結果は output-schema で止まる"
    fi
  else
    fail "output_directoryを省いた新規作成を受け取れない: $(head -1 "$io/routed.err" "$io/routed-read.err" 2>/dev/null | tr '\n' ' ')"
  fi

  # 入口hookそのものの契約：引数1つ、非0で拒否、診断は [error:input-schema]。
  hook="$copy_pb/scripts/validate-input.sh"
  hook_ok=1
  [ -x "$hook" ] || { echo "  入口hookが実行可能でない: $hook"; hook_ok=0; }
  bash "$hook" "$io/input.yml" 2> "$io/hook-ok.err" || { echo "  正しい入力を入口hookが拒否する: $(head -1 "$io/hook-ok.err")"; hook_ok=0; }
  bash "$hook" 2> "$io/hook-usage.err" && { echo "  引数なしの入口hookが成功してしまう"; hook_ok=0; }
  rg -q 'error:input-schema.*reason=usage' "$io/hook-usage.err" || { echo "  引数なしを期待した理由で拒否できない"; hook_ok=0; }
  bash "$hook" "$io/missing-input.yml" 2> "$io/hook-missing.err" && { echo "  存在しない入力を入口hookが受け取る"; hook_ok=0; }
  rg -q 'error:input-schema.*reason=not-file' "$io/hook-missing.err" || { echo "  不在の入力を期待した理由で拒否できない"; hook_ok=0; }
  bash "$hook" material/material.yml 2> "$io/hook-relative.err" && { echo "  相対pathの入力を入口hookが受け取る"; hook_ok=0; }
  rg -q 'error:input-schema.*reason=not-absolute' "$io/hook-relative.err" || { echo "  相対pathを期待した理由で拒否できない"; hook_ok=0; }
  [ "$hook_ok" -eq 1 ] && pass "入口hookの引数・診断・exit契約" || fail "入口hookの引数・診断・exit契約"

  # symlink 経由の一時領域（macOS 既定の TMPDIR）でも入口を通る。
  # **正規化するのは提供側の仕事である。** 呼び出し元へ pwd -P を強いない。
  linked="$TMP_ROOT/linked-run"
  mkdir -p "$io/real-run"
  ln -s "$io/real-run" "$linked"
  write_contract_input "$linked/input.yml" '.output_to="'"$linked"'/output.yml"'
  if contract_prepare "$linked/input.yml" >/dev/null 2> "$io/linked.err"; then
    pass "祖先がsymlinkの一時領域から渡された入力も入口を通る"
  else
    fail "symlink経由の一時領域の入力を受け取れない: $(head -1 "$io/linked.err")"
  fi
fi

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
python3 "$ROOT/scripts/test-output-routing.py" && pass "repository・文書型ごとの出力先ルーティング" || fail "repository・文書型ごとの出力先ルーティング"

printf '\nValidation: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
