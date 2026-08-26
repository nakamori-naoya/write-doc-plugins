---
name: write-with-rules
description: 文章を規律に従って書く／直す。構成・段落・主張の立て方・どこを強調するか・文体・出典の3点セット・コード注釈の規律を適用する。資料に限らず、PR の説明・チケット・レビューコメント・メールにも使う。「規律に従って書いて」「この文章を直して」と言われたときに使う。
---

# write-with-rules

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
