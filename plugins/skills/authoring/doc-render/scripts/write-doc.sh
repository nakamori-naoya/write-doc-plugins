#!/usr/bin/env bash
# 資料を1本、出力先へ安全に置く。
#
#   write-doc.sh --config <json|path> (--name <ファイル名> | --target <既存絶対path>) --body-file <path> [--format <markdown|html>] [--replace]
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

cfg=""; name=""; target_arg=""; body=""; requested_format=""; replace=0
while [ $# -gt 0 ]; do
  case "$1" in
    --config)    need "$1" "${2:-}"; cfg="$2"; shift 2 ;;
    --name)      need "$1" "${2:-}"; name="$2"; shift 2 ;;
    --target)    need "$1" "${2:-}"; target_arg="$2"; shift 2 ;;
    --body-file) need "$1" "${2:-}"; body="$2"; shift 2 ;;
    --format)    need "$1" "${2:-}"; requested_format="$2"; shift 2 ;;
    --replace)   replace=1; shift ;;
    *) echo "{\"error\":\"不明な引数: $1\"}"; exit 2 ;;
  esac
done

fail() { printf '{"error":%s}\n' "$(jq -Rn --arg m "$1" '$m')"; exit "${2:-2}"; }

[ -n "$cfg" ]  || fail "--config が無い"
[ -n "$name" ] || [ -n "$target_arg" ] || fail "--name または --target が無い"
[ -z "$name" ] || [ -z "$target_arg" ] || fail "--name と --target は同時に使えない"
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
  out_dir=$(jq -r '.output.dir // ""' <<<"$merged")
  [ -n "$out_dir" ] || fail "設定に output.dir が無い"
  mkdir -p "$out_dir" 2>/dev/null || fail "出力先を作れない: ${out_dir}"

  # 実パスで内包を確かめる。設定側に symlink があっても外へは書かせない。
  real_out=$(cd "$out_dir" 2>/dev/null && pwd -P) || fail "出力先へ入れない: ${out_dir}"
  # pwd -P は実パスへ直すだけで、内包を確かめない。
  # 出力先そのものが symlink だと、設定で指した場所の外へ書ける。
  declared=$(cd "$(dirname "$out_dir")" 2>/dev/null && pwd -P)/$(basename "$out_dir")
  if [ "$real_out" != "$declared" ]; then
    fail "出力先が symlink で別の場所を指している: ${out_dir} -> ${real_out}（設定した場所へ書けない）"
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

printf '{"decision":%s,"path":%s}\n' \
  "$(jq -Rn --arg d "$decision" '$d')" "$(jq -Rn --arg p "$target" '$p')"
