#!/usr/bin/env bash
# content-types 固有の検査と、出す形の組み立て。
#
# **resolve.sh から source される。** 設定の解決手順は共通なのでここには無い。
# 使えるもの: merged / required / root / PLUGIN_ROOT / name / selected / source / explain / resolve_path
# やること: 固有schemaの検査と、out への最終JSONの代入。
jq -e '.version==1 and (.default_type|type=="string" and length>0) and (.instructions.selection.directive|type=="string" and length>0)' >/dev/null <<<"$merged" \
  || { echo "[error] versionまたはinstructions.selection.directiveが不正" >&2; exit 2; }

dtype=$(jq -r '.default_type // "concept"' <<<"$merged")
case "$dtype" in ''|*[!a-z0-9-]*) echo "[error] default_type が不正: ${dtype}（英小文字・数字・- のみ）" >&2; exit 2 ;; esac
# 実在しない型を既定にすると、型が特定できなかったときに存在しない骨格を探しにいく。
if [ ! -f "$PLUGIN_ROOT/assets/templates/${dtype}.md" ]; then
  echo "[error] default_type に対応するテンプレートが無い: ${dtype}" >&2
  echo "        同梱の型: $(ls "$PLUGIN_ROOT/assets/templates" | sed 's/\.md$//' | tr '\n' ' ')" >&2
  exit 2
fi
out=$(jq -cn --arg pr "$PLUGIN_ROOT" --arg root "$root" --arg dt "$dtype" --argjson instructions "$(jq -c '.instructions' <<<"$merged")" \
  '{contract:1, catalog:($pr+"/references/catalog.md"), detail_dir:($pr+"/references/detail"),
    instructions:$instructions,
    templates:{plugin_dir:($pr+"/assets/templates")},
    examples:{plugin_dir:($pr+"/assets/examples")},
    template_examples:($pr+"/assets/template-examples.yml"),
    default_type:$dt, repo_root:$root, plugin_root:$pr}')
if [ "$explain" = "1" ]; then
  echo "# カタログ: ${PLUGIN_ROOT}/references/catalog.md（型 $(ls "$PLUGIN_ROOT/assets/templates" | wc -l | tr -d ' ') 種）" >&2
  echo "# テンプレート: plugin=${PLUGIN_ROOT}/assets/templates（独自テンプレート非対応）" >&2
  echo "# 記載例: plugin=${PLUGIN_ROOT}/assets/examples（全型）" >&2
  echo "# 対応表: ${PLUGIN_ROOT}/assets/template-examples.yml" >&2
  echo "# 既定の型: ${dtype}" >&2
fi
