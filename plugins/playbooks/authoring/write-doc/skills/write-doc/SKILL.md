---
name: write-doc
description: 資料を1本書いて保存する。読み手と目的から文書の型を決め、規律に従って書き、HTML か Markdown へ写して保存する。「資料にして」「サマリを作って」「ドキュメントを書いて」と言われたときに使う。
---

# write-doc

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
