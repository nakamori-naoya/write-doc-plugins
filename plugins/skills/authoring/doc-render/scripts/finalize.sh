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
  (.instructions.render.directive|type=="string" and length>0)' >/dev/null <<<"$merged" \
  || { echo "[error] version、output.default、output.routes、render directiveのいずれかが不正" >&2; exit 2; }

fmt=$(jq -r '.output.format // "markdown"' <<<"$merged")
case "$fmt" in markdown) ;; *) echo "[error] output.format が不正: ${fmt}（markdown のみ）" >&2; exit 2 ;; esac
instructions=$(jq -c '.instructions' <<<"$merged")

output=$(jq -c '{default:.output.default,routes:.output.routes}' <<<"$merged")
out=$(jq -cn --arg pr "$PLUGIN_ROOT" --arg root "$root" --arg f "$fmt" \
  --argjson output "$output" --argjson instructions "$instructions" \
  '{contract:1, output:($output+{format:$f}),instructions:$instructions,
    guides:{markdown:($pr+"/references/markdown.md"),
            citation:($pr+"/references/citation.md"), "annotated-code":($pr+"/references/annotated-code.md")},
    writer:($pr+"/scripts/write-doc.sh"), repo_root:$root, plugin_root:$pr}')
if [ "$explain" = "1" ]; then
  jq -r '"# 既定出力: dir.type=\(.dir.type) dir.path=\(.dir.path)"' <<<"$(jq -c '.output.default' <<<"$merged")" >&2
  jq -r '.[] | "# 型別出力: templates=\(.templates|join(",")) dir.type=\(.dir.type) dir.path=\(.dir.path)"' <<<"$(jq -c '.output.routes' <<<"$merged")" >&2
  echo "# 形式: ${fmt}" >&2
fi
