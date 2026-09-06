#!/usr/bin/env bash
# doc-render 固有の検査と、出す形の組み立て。
#
# **resolve.sh から source される。** 設定の解決手順は共通なのでここには無い。
# 使えるもの: merged / required / root / PLUGIN_ROOT / name / selected / source / explain / resolve_path
# やること: 固有schemaの検査と、out への最終JSONの代入。
jq -e 'def clean_segments:
    (contains("\\")|not) and (endswith("/")|not) and
    (split("/") | all(.!="" and .!="." and .!=".."));
  def routed_dir:
    type=="object" and (keys|sort)==["path","type"] and
    if .type=="relative" then
      (.path|type=="string" and length>0 and
        (startswith("/")|not) and (startswith("~")|not) and clean_segments)
    elif .type=="absolute" then
      (.path|type=="string" and
        ((startswith("~/") and (.[2:]|clean_segments)) or
         (startswith("/") and (.[1:]|clean_segments))))
    else false end;
  .version==2 and
  (.output.default|type=="object" and keys==["dir"] and (.dir|routed_dir)) and
  (.output.routes|type=="array") and
  (.output.routes|all(.[];
    type=="object" and (keys|sort)==["dir","templates"] and
    (.templates|type=="array" and length>0 and
      all(.[]; type=="string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")) and
      length==(unique|length)) and
    (.dir|routed_dir))) and
  ((.output.routes|map(.templates[])|length)==(.output.routes|map(.templates[])|unique|length)) and
  (.instructions.render.directive|type=="string" and length>0) and
  (.instructions.render.themes.dark.palette|type=="object") and
  (.instructions.render.themes.light.palette|type=="object") and
  (.instructions.render.themes.auto.palette_source|type=="string" and length>0)' >/dev/null <<<"$merged" \
  || { echo "[error] version、output.default、output.routes、render directiveのいずれかが不正" >&2; exit 2; }

fmt=$(jq -r '.output.format // "markdown"' <<<"$merged")
case "$fmt" in html|markdown) ;; *) echo "[error] output.format が不正: ${fmt}（html / markdown のみ）" >&2; exit 2 ;; esac
theme=$(jq -r '.output.theme // "auto"' <<<"$merged")
case "$theme" in dark|light|auto) ;; *) echo "[error] output.theme が不正: ${theme}（dark / light / auto）" >&2; exit 2 ;; esac

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

output=$(jq -c '{default:.output.default,routes:.output.routes}' <<<"$merged")
out=$(jq -cn --arg pr "$PLUGIN_ROOT" --arg root "$root" --arg f "$fmt" --arg t "$theme" \
  --argjson output "$output" --argjson instructions "$instructions" \
  '{contract:1, output:($output+{format:$f,theme:$t}),instructions:$instructions,
    shell:($pr+"/assets/html-shell.html"),
    guides:{html:($pr+"/references/html.md"), markdown:($pr+"/references/markdown.md"),
            emphasis:($pr+"/references/emphasis.md"), figures:($pr+"/references/figures.md"),
            citation:($pr+"/references/citation.md"), "annotated-code":($pr+"/references/annotated-code.md")},
    writer:($pr+"/scripts/write-doc.sh"), repo_root:$root, plugin_root:$pr}')
if [ "$explain" = "1" ]; then
  jq -r '"# 既定出力: dir.type=\(.dir.type) dir.path=\(.dir.path)"' <<<"$(jq -c '.output.default' <<<"$merged")" >&2
  jq -r '.[] | "# 型別出力: templates=\(.templates|join(",")) dir.type=\(.dir.type) dir.path=\(.dir.path)"' <<<"$(jq -c '.output.routes' <<<"$merged")" >&2
  echo "# 形式: ${fmt} / ${theme}" >&2
  echo "# 雛形: ${PLUGIN_ROOT}/assets/html-shell.html" >&2
fi
