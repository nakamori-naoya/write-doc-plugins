---
name: remove-intermediate-artifacts
description: 最終資料や入力資料を残し、資料化後に不要となった明示パスの中間生成ファイルだけを検査して削除する。「最終成果物だけ残して」「資料化後の中間ファイルを片付けて」と言われたときに使う。追跡中のファイルやdirectoryは削除しない。
---

# remove-intermediate-artifacts

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
