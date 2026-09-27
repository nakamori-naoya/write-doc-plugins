#!/usr/bin/env bash
# write-doc repository の検査。意味が一意に決まることだけを判定する。
#   1. package の構造（manifest の一致、公開入口、配置）は harness-tools の validate-plugin-repository.py が判定する。
#   2. assets/templates/<型>.md と assets/examples/<型>.example.md は、過不足なく組になっている。
#   3. テンプレートと見本は、冒頭に `> 型:` の引用行を置かない。
# 文章の良し悪しは判定しない。SKILL.md、テンプレート、書いた資料は、読んで評価する。
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOLS="$ROOT/../harness-tools/tools"
[ -d "$TOOLS" ] || { echo "[error] 兄弟 checkout harness-tools が無い: $TOOLS" >&2; exit 2; }
for command in rg; do
  command -v "$command" >/dev/null 2>&1 || { echo "[error] required command not found: $command" >&2; exit 2; }
done

ENTRY="$ROOT/plugins/write-doc/skills/write-doc"
status=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; status=1; }

if python3 "$TOOLS/validate-plugin-repository.py" "$ROOT"; then pass "package の構造"; else fail "package の構造"; fi

unpaired=$(
  for f in "$ENTRY"/assets/templates/*.md; do n=$(basename "$f" .md); [ -f "$ENTRY/assets/examples/$n.example.md" ] || printf 'templates/%s.md\n' "$n"; done
  for f in "$ENTRY"/assets/examples/*.example.md; do n=$(basename "$f" .example.md); [ -f "$ENTRY/assets/templates/$n.md" ] || printf 'examples/%s.example.md\n' "$n"; done
)
if [ -z "$unpaired" ]; then pass "テンプレートと見本が組になっている"; else fail "組の無いテンプレートか見本: $unpaired"; fi

if rg -n '^> 型:' "$ENTRY/assets/templates" "$ENTRY/assets/examples"; then
  fail "テンプレートか見本に > 型: の行がある"
else
  pass "テンプレートと見本に > 型: の行が無い"
fi

if python3 "$TOOLS/test-hardening.py" --repository "$ROOT" >/dev/null 2>&1; then pass "test-hardening --repository"; else fail "test-hardening --repository"; fi

[ "$status" -eq 0 ] && echo "Validation: passed" || echo "Validation: failed"
exit "$status"
