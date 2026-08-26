#!/usr/bin/env bash
# doc-render 固有の検査と、出す形の組み立て。
#
# **resolve.sh から source される。** 設定の解決手順は共通なのでここには無い。
# 使えるもの: merged / required / root / PLUGIN_ROOT / name / selected / source / explain / resolve_path
# やること: 固有schemaの検査と、out への最終JSONの代入。
jq -e '.version==1 and (.output.dir|type=="string" and length>0) and
  (.instructions.render.directive|type=="string" and length>0) and
  (.instructions.render.themes.dark.palette|type=="object") and
  (.instructions.render.themes.light.palette|type=="object") and
  (.instructions.render.themes.auto.palette_source|type=="string" and length>0)' >/dev/null <<<"$merged" \
  || { echo "[error] version、output.dir、render directiveのいずれかが不正" >&2; exit 2; }

fmt=$(jq -r '.output.format // "markdown"' <<<"$merged")
case "$fmt" in html|markdown) ;; *) echo "[error] output.format が不正: ${fmt}（html / markdown のみ）" >&2; exit 2 ;; esac
theme=$(jq -r '.output.theme // "auto"' <<<"$merged")
case "$theme" in dark|light|auto) ;; *) echo "[error] output.theme が不正: ${theme}（dark / light / auto）" >&2; exit 2 ;; esac
out_dir=$(resolve_path "$(jq -r '.output.dir // "docs"' <<<"$merged")")

# **どのthemeでも palette を同じ形で引けるようにする。**
# auto だけ palette を持たず palette_source しか無いと、
# 「解決済み設定の値は使用時に yq -er で読み、欠落なら停止する」という契約に従った
# 呼び出し側が、既定設定のまま必ず止まる。auto は「明暗の両方を使う」ので、
# その意味どおり light と dark を束ねた palette を解決時に組んで載せる。
instructions=$(jq -c '
  .instructions.render.themes.auto.palette = {
    light: .instructions.render.themes.light.palette,
    dark:  .instructions.render.themes.dark.palette
  } | .instructions' <<<"$merged")

out=$(jq -cn --arg pr "$PLUGIN_ROOT" --arg root "$root" --arg dir "$out_dir" --arg f "$fmt" --arg t "$theme" \
  --argjson instructions "$instructions" \
  '{contract:1, output:{format:$f, dir:$dir, theme:$t},instructions:$instructions,
    shell:($pr+"/assets/html-shell.html"),
    guides:{html:($pr+"/references/html.md"), markdown:($pr+"/references/markdown.md"),
            emphasis:($pr+"/references/emphasis.md"), figures:($pr+"/references/figures.md"),
            citation:($pr+"/references/citation.md"), "annotated-code":($pr+"/references/annotated-code.md")},
    writer:($pr+"/scripts/write-doc.sh"), repo_root:$root, plugin_root:$pr}')
if [ "$explain" = "1" ]; then
  echo "# 出力: ${out_dir} (${fmt} / ${theme})" >&2
  echo "# 雛形: ${PLUGIN_ROOT}/assets/html-shell.html" >&2
fi
