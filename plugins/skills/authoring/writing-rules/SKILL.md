---
name: write-with-rules
description: 文章を規律に従って書く／直す。構成・段落・主張の立て方・どこを強調するか・文体・出典の3点セット・コード注釈の規律を適用する。資料に限らず、PR の説明・チケット・レビューコメント・メールにも使う。「規律に従って書いて」「この文章を直して」と言われたときに使う。
---

# write-with-rules（規律に従って書く）

**このスキルは媒体を知らない。** HTML なのか Markdown なのかプレーンテキストなのかは決めない。決めるのは**何をどう書くか**だけである。

**単独で使える。** PR の説明文、チケット、レビューコメント、メール。保存や媒体への変換はこのスキルの関心ではない。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 規律を解決して読む

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
trap 'rm -f "$CFG_FILE"' EXIT
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.instructions.writing.directive}` に従い、`${.rules.*.path}` と `${.extra[].path}` を読む。
同梱規律は[structure](references/structure.md)、[section](references/section.md)、[emphasis](references/emphasis.md)、[style](references/style.md)、[citation](references/citation.md)、[annotated-code](references/annotated-code.md)である。解決されたpathだけを読む。

**exit 2 で止まったら先へ進まない。** 指したファイルが無いのに既定へ倒れると、差し替えたつもりで効いていない状態になる。

`source` が `default` のものは、**citation以外なら「自分のファイルを指せば差し替えられる」と一度だけ伝える**。citationは上書きせず、追加規律を`${.extra[]}`へ置く。

## 2. 書く

[適用手順](references/apply.md)を必ず読み、structure→section→emphasisの順に進める。扱う役は4つだけで、出典の3点セットは設定でも解除できない。

## 3. 出す前に

[final-check.md](references/final-check.md)を読み、全項目を確認する。

設定の形式と差し替え例は[README](README.md)を参照する。指定したファイルが無ければresolverが停止する。
