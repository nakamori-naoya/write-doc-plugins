---
name: choose-visual
description: 伝えたい主張と読み手の問いから、図にする箇所、図の型、画像生成を使うかを選び、描画可能な設計を返す。資料へ画像・図・グラフ・構成図・業務フロー・CI/CD・依存関係図・シーケンス図・状態遷移図・データフローを入れたいときに使う。
---

# choose-visual

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
