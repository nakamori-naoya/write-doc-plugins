#!/usr/bin/env bash
# writing-rules 固有の検査と、出す形の組み立て。
#
# **resolve.sh から source される。** 設定の解決手順は共通なのでここには無い。
# 使えるもの: merged / required / root / PLUGIN_ROOT / name / selected / source / explain / resolve_path
# やること: 固有schemaの検査と、out への最終JSONの代入。
jq -e '.version==1 and (.rules|type=="object" and all(.[]; type=="string")) and
  ((.extra|type)=="string" or ((.extra|type)=="array" and all(.extra[]; type=="string"))) and
  (.instructions.writing.directive|type=="string" and length>0)' >/dev/null <<<"$merged" \
  || { echo "[error] version、rules、writing directiveのいずれかが不正" >&2; exit 2; }

RULE_NAMES="structure section emphasis style citation annotated-code"
rules_json='{}'; report=''
for r in $RULE_NAMES; do
  want=$(jq -r --arg r "$r" '.rules[$r] // ""' <<<"$merged")
  if [ "$r" = "citation" ] && [ -n "$want" ]; then
    echo "[error] rules.citation は出典3点セットを弱められないため上書き禁止。追加規律はextraへ置くこと" >&2
    exit 2
  fi
  resolved=$(resolve_path "$want")
  if [ -n "$resolved" ] && [ -f "$resolved" ]; then
    src=repo
  else
    # 指したのに無いのを既定へ倒すと、差し替えたつもりで効いていない。
    [ -z "$resolved" ] || { echo "[error] rules.${r} に指定したファイルが無い: ${resolved}" >&2; exit 2; }
    resolved="$PLUGIN_ROOT/references/${r}.md"; src=default
  fi
  rules_json=$(jq -c --arg r "$r" --arg p "$resolved" --arg s "$src" '.[$r]={path:$p,source:$s}' <<<"$rules_json")
  report="${report}  ${r}: ${src} (${resolved})\n"
done

# rules は同梱の規律名だけを受け取る。名前を個別に覚えず、許可名の一覧で判定する。
unknown=$(jq -r --arg allowed "$RULE_NAMES" '
  ($allowed | split(" ")) as $ok
  | [.rules | keys[] | select(. as $k | ($ok | index($k) | not))] | join(", ")
' <<<"$merged")
[ -z "$unknown" ] || { echo "[error] rules に未知のキーがある: ${unknown}" >&2; exit 2; }

extra_raw=$(jq -r '(.extra // "") | if type=="array" then join(",") else tostring end' <<<"$merged")
extra_json='[]'
if [ -n "$extra_raw" ] && [ "$extra_raw" != "null" ]; then
  old_ifs=$IFS; IFS=','
  for item in $extra_raw; do
    item=$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$item" ] || continue
    x=$(resolve_path "$item")
    [ -f "$x" ] || { echo "[error] extra に指定したファイルが無い: ${x}" >&2; exit 2; }
    extra_json=$(jq -c --arg p "$x" '. + [{path:$p}]' <<<"$extra_json")
    report="${report}  extra: ${x}\n"
  done
  IFS=$old_ifs
fi

out=$(jq -cn --argjson r "$rules_json" --argjson e "$extra_json" --arg root "$root" --arg pr "$PLUGIN_ROOT" --argjson instructions "$(jq -c '.instructions' <<<"$merged")" \
  '{contract:1, rules:$r, extra:$e,
    instructions:$instructions,
    repo_root:$root, plugin_root:$pr}')
if [ "$explain" = "1" ]; then
  echo "# 規律:" >&2; printf "$report" >&2
fi
