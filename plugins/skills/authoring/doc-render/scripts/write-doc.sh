#!/usr/bin/env bash
# 資料を1本、出力先へ安全に置く。
#
#   write-doc.sh --config <json|path> (--name <ファイル名> | --target <既存絶対path>) --body-file <path> [--template <文書型slug>] [--output-dir <明示された絶対path>] [--format <markdown|html>] [--replace]
#
#   -> {"decision":"written"|"replaced","path":"..."}
#      既存があって --replace が無ければ {"decision":"exists",...} を出して exit 3
#
# このスクリプトが見るのは「どこへ置くか」だけである。
#
#   **本文の中身は一切検査しない。**
#
# 型が合っているか、構成が規約どおりか、強調が適切かは、機械が測るものではない。
# 比率や有無を数えて合否を出すと、良い文章ほど弾かれる規則ができあがる。
# 中身の判断はガイドと書き手（エージェント）に残す。ここは取り違えと消失だけを防ぐ。
set -uo pipefail

# 値の無いオプションで shift 2 すると位置引数が減らず、while が回り続ける。
# 「引数が足りない」を無限ループとして表に出さない。
need() { [ -n "$2" ] || { echo "[error] $1 に値が無い" >&2; exit 2; }; }

cfg=""; name=""; target_arg=""; body=""; template=""; explicit_out=""; requested_format=""; replace=0
while [ $# -gt 0 ]; do
  case "$1" in
    --config)    need "$1" "${2:-}"; cfg="$2"; shift 2 ;;
    --name)      need "$1" "${2:-}"; name="$2"; shift 2 ;;
    --target)    need "$1" "${2:-}"; target_arg="$2"; shift 2 ;;
    --body-file) need "$1" "${2:-}"; body="$2"; shift 2 ;;
    --template)  need "$1" "${2:-}"; template="$2"; shift 2 ;;
    --output-dir) need "$1" "${2:-}"; explicit_out="$2"; shift 2 ;;
    --format)    need "$1" "${2:-}"; requested_format="$2"; shift 2 ;;
    --replace)   replace=1; shift ;;
    *) echo "{\"error\":\"不明な引数: $1\"}"; exit 2 ;;
  esac
done

fail() { printf '{"error":%s}\n' "$(jq -Rn --arg m "$1" '$m')"; exit "${2:-2}"; }

[ -n "$cfg" ]  || fail "--config が無い"
[ -n "$name" ] || [ -n "$target_arg" ] || fail "--name または --target が無い"
[ -z "$name" ] || [ -z "$target_arg" ] || fail "--name と --target は同時に使えない"
[ -z "$target_arg" ] || [ -z "$explicit_out" ] || fail "--target と --output-dir は同時に使えない"
[ -n "$body" ] || fail "--body-file が無い"
[ -f "$body" ] || fail "--body-file が読めない: ${body}"
# 空の本文を written として受け入れると、「書けた」と報告されたのに
# 中身が無い資料が残る。生成が途中で落ちた事故を成功として隠す。
[ -s "$body" ] || fail "--body-file が空: ${body}（空の資料は書かない）"

# 設定は JSON そのものでも、ファイルパスでも受ける（resolve-style.sh の出力をそのまま渡せる）
case "$cfg" in
  \{*) merged="$cfg" ;;
  *)   [ -f "$cfg" ] || fail "--config が読めない: ${cfg}"
       command -v yq >/dev/null 2>&1 || fail "YAML設定を読むためにyqが要る"
       merged=$(yq -o=json -I=0 '.' "$cfg" 2>/dev/null) || fail "--config のYAMLが壊れている: ${cfg}" ;;
esac
jq -e . >/dev/null 2>&1 <<<"$merged" || fail "--config が JSON ではない"

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
  .output.default|type=="object" and keys==["dir"] and (.dir|routed_dir)' >/dev/null <<<"$merged" \
  || fail "設定のoutput.defaultが不正"
routes=$(jq -c '.output.routes // []' <<<"$merged")
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
  type=="array" and all(.[];
  type=="object" and (keys|sort)==["dir","templates"] and
  (.templates|type=="array" and length>0 and
    all(.[]; type=="string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")) and
    length==(unique|length)) and
  (.dir|routed_dir)) and
  ((map(.templates[])|length)==(map(.templates[])|unique|length))' >/dev/null <<<"$routes" \
  || fail "設定のoutput.routesが不正（templatesとdirを持ち、文書型が重複しない配列が必要）"
if [ -n "$template" ]; then
  [[ "$template" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
    || fail "--template が不正: ${template}（小文字英数字とハイフンのみ）"
fi
if [ -n "$explicit_out" ]; then
  case "$explicit_out" in /*) ;; *) fail "--output-dir は明示された絶対pathで指定する: ${explicit_out}" ;; esac
  case "$explicit_out" in *'/../'*|*/..|*/./*|*/.|*//*|*/|*\\*) fail "--output-dir は正規化済みpathで指定する: ${explicit_out}" ;; esac
fi

configured_format=$(jq -r '.output.format // ""' <<<"$merged")
theme=$(jq -r '.output.theme // ""' <<<"$merged")
case "$configured_format" in markdown|html) ;; *) fail "設定のoutput.formatが不正: ${configured_format}" ;; esac
case "$requested_format" in ''|markdown|html) ;; *) fail "--formatが不正: ${requested_format}（markdown / html）" ;; esac
format="${requested_format:-$configured_format}"
case "$theme" in dark|light|auto) ;; *) fail "設定のoutput.themeが不正: ${theme}" ;; esac

# --nameは新規作成の名前であってpathではない。--targetはguard済みの既存資料を
# 同じ場所で差し替えるための口であり、絶対path・既存regular file・非symlinkを要求する。
if [ -n "$target_arg" ]; then
  [ "$replace" = "1" ] || fail "--target は既存資料の差し替え専用。--replace が必要"
  case "$target_arg" in /*) ;; *) fail "--target は絶対pathで指定する: ${target_arg}" ;; esac
  [ ! -L "$target_arg" ] || fail "--target はsymlinkを許さない: ${target_arg}"
  [ -f "$target_arg" ] || fail "--target は既存のregular fileでなければならない: ${target_arg}"
  target_parent=$(dirname "$target_arg")
  real_out=$(cd "$target_parent" 2>/dev/null && pwd -P) || fail "--targetの親directoryへ入れない: ${target_parent}"
  declared_parent=$(cd "$(dirname "$target_parent")" 2>/dev/null && pwd -P)/$(basename "$target_parent")
  [ "$real_out" = "$declared_parent" ] \
    || fail "--targetの親directoryがsymlinkで別の場所を指している: ${target_parent} -> ${real_out}"
  name=$(basename "$target_arg")
  target="${real_out}/${name}"
  [ "$target" = "$target_arg" ] || fail "--target は正規化済みの絶対pathで指定する: ${target_arg} -> ${target}"
else
  case "$name" in
    ''|.|..)      fail "--name が不正: ${name}" ;;
    */*|*\\*)     fail "--name にパス区切りは使えない: ${name}" ;;
    .*)           fail "--name をドットで始めない: ${name}" ;;
    *[!A-Za-z0-9._-]*) fail "--name に使えない文字がある（英数と . _ - のみ）: ${name}" ;;
  esac
fi
case "$name" in
  *.html|*.md) ;;
  *) fail "--name の拡張子は .html か .md（${name}）" ;;
esac
case "$format:$name" in
  markdown:*.md|html:*.html) ;;
  *) fail "有効なformat=${format}とファイル名が一致しない: ${name}" ;;
esac

# HTMLの本文断片をそのまま保存すると、CSS・theme・文字色を持たない壊れた資料になる。
# 媒体の完全性だけを検査し、本文の良し悪しには立ち入らない。
case "$name" in
  *.html)
    first=$(awk 'NF { print; exit }' "$body" | tr '[:upper:]' '[:lower:]')
    case "$first" in '<!doctype html>'*) ;; *)
      fail "HTML は本文断片ではなく <!doctype html> から始まる完全な1ファイルを渡すこと"
    esac
    grep -qi "<html[^>]*data-theme=\"${theme}\"" "$body" \
      || fail "HTML の data-theme が設定値 ${theme} と一致しない"
  ;;
esac

if [ -z "$target_arg" ]; then
  destination_source="explicit"
  if [ -n "$explicit_out" ]; then
    out_dir="$explicit_out"
  else
    destination=$(jq -c --arg template "$template" '
      ([.output.routes[]? | select(.templates | index($template))] | first) // .output.default' <<<"$merged")
    dir_type=$(jq -r '.dir.type' <<<"$destination")
    dir_path=$(jq -r '.dir.path' <<<"$destination")
    destination_source="default"
    if [ -n "$template" ] && jq -e --arg template "$template" \
      'any(.output.routes[]?; .templates | index($template))' >/dev/null <<<"$merged"; then
      destination_source="route"
    fi
    check_root=1
    case "$dir_type" in
      relative)
        target_root=$(jq -r '.repo_root // empty' <<<"$merged")
        [ -n "$target_root" ] || fail "解決済み設定にrepo_rootが無い"
        [ -d "$target_root" ] || fail "作業repositoryが存在しない: ${target_root}"
        real_root=$(cd "$target_root" 2>/dev/null && pwd -P) || fail "作業repositoryへ入れない: ${target_root}"
        out_dir="${real_root}/${dir_path}"
      ;;
      absolute)
        case "$dir_path" in
          "~/"*)
            [ -n "${HOME:-}" ] || fail "~/ を解決するHOMEが無い"
            [ -d "$HOME" ] || fail "HOMEが存在しない: ${HOME}"
            real_root=$(cd "$HOME" 2>/dev/null && pwd -P) || fail "HOMEへ入れない: ${HOME}"
            out_dir="${real_root}/${dir_path:2}"
          ;;
          /*)
            real_root="/"
            out_dir="$dir_path"
            check_root=0
          ;;
        esac
      ;;
    esac
  fi
  mkdir -p "$out_dir" 2>/dev/null || fail "出力先を作れない: ${out_dir}"

  # 実パスで内包を確かめる。設定側に symlink があっても外へは書かせない。
  real_out=$(cd "$out_dir" 2>/dev/null && pwd -P) || fail "出力先へ入れない: ${out_dir}"
  # pwd -P は実パスへ直すだけで、内包を確かめない。
  # 出力先そのものが symlink だと、設定で指した場所の外へ書ける。
  declared=$(cd "$(dirname "$out_dir")" 2>/dev/null && pwd -P)/$(basename "$out_dir")
  if [ "$real_out" != "$declared" ]; then
    fail "出力先が symlink で別の場所を指している: ${out_dir} -> ${real_out}（設定した場所へ書けない）"
  fi
  if [ -z "$explicit_out" ] && [ "${check_root:-0}" = "1" ]; then
    case "${real_out}/" in
      "${real_root}/"|"${real_root}/"*) ;;
      *) fail "解決した出力先が基準directoryの外にある: ${real_out}（基準: ${real_root}）" ;;
    esac
  fi
  target="${real_out}/${name}"
fi

# 検査してから書くまでの間に、別のプロセスが同じ名前で書けてしまう。
# 「無いことを確かめる」と「作る」を別々にやると、両方が「無い」と見て
# 両方が書き、後着が先着を踏む。どちらも written を返すので消失に気づけない。
# link(2) は既存があれば必ず失敗するので、作成そのものを排他にする。
tmp=$(mktemp "${real_out}/.write-doc.XXXXXXXX") || fail "一時ファイルを作れない: ${real_out}"
if ! cat "$body" > "$tmp" 2>/dev/null; then
  rm -f "$tmp"; fail "書き込みに失敗した: ${target}"
fi
# mktemp は 0600 で作る。排他作成のための都合であって、資料の permission ではない。
# 一時ファイルの mode がそのまま保存物へ移ると、共有 repository に置いた資料を
# 書いた本人しか読めなくなる。link / mv の前に、資料として普通の読み取り可へ直す。
# --replace は mv で置き換えるので、こちらの経路も同じ mode になる。
chmod u+rw,go+r "$tmp" 2>/dev/null || { rm -f "$tmp"; fail "permissionを直せない: ${target}"; }

decision=""
if [ "$replace" = "1" ]; then
  [ -e "$target" ] && decision="replaced" || decision="written"
  if ! mv -f "$tmp" "$target" 2>/dev/null; then
    rm -f "$tmp"; fail "差し替えに失敗した: ${target}"
  fi
else
  if ln "$tmp" "$target" 2>/dev/null; then
    decision="written"
    rm -f "$tmp"
  else
    rm -f "$tmp"
    # 既にあるのか、別の理由で作れないのかを言い分ける。
    if [ -e "$target" ]; then
      printf '{"decision":"exists","path":%s,"hint":"既存を読んだうえで --replace を付けて呼び直す"}\n' \
        "$(jq -Rn --arg p "$target" '$p')"
      exit 3
    fi
    fail "作成に失敗した: ${target}"
  fi
fi

printf '{"decision":%s,"path":%s,"destinationSource":%s}\n' \
  "$(jq -Rn --arg d "$decision" '$d')" "$(jq -Rn --arg p "$target" '$p')" \
  "$(jq -Rn --arg s "${destination_source:-existing-target}" '$s')"
