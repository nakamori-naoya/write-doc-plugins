---
name: pick-content-type
description: 読み手と目的から、書くべき文書の型を決める。Product North Star／Product Strategy／業務知識・コアドメイン／RDB論理設計／README／チュートリアル／コンセプト／ADR／デザインドック／実装解説／期間ダイジェスト／コード地図など27種のカタログ、テンプレート、記載例を返す。「どの型で書くべき？」「North Starや戦略を資料にして」「この文書は何？」と聞かれたときに使う。
---

# pick-content-type

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
