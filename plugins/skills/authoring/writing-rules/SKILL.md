---
name: write-with-rules
description: 文章を規律に従って書く／直す。構成・段落・主張の立て方・どこを強調するか・文体・出典の3点セット・観測値の扱い・コード注釈の規律を適用する。資料に限らず、PR の説明・チケット・レビューコメント・メールにも使う。「規律に従って書いて」「この文章を直して」と言われたときに使う。
---

# write-with-rules（規律に従って書く）

**このスキルは媒体を知らない。** Markdown なのかプレーンテキストなのかは決めない。決めるのは**何をどう書くか**だけである。

**単独で使える。** PR の説明文、チケット、レビューコメント、メール。保存や媒体への変換はこのスキルの関心ではない。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/skills/authoring/writing-rules" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/skills/authoring/writing-rules"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 規律を解決して読む

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
printf '%s\n' "$CFG_FILE"
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.instructions.writing.directive}` に従い、`${.rules.*.path}` と `${.extra[].path}` を読む。解決されたpathだけを読む。同梱規律は10本で、役割は[README](README.md)の表にある。

**exit 2 で止まったら先へ進まない。** 指したファイルが無いのに既定へ倒れると、差し替えたつもりで効いていない状態になる。

`source` が `default` の規律は、自分のファイルを `rules.<名前>` に指せば差し替えられる。`citation` と `terminology` は差し替えられず、resolver が拒否する。追加の規律は `${.extra[]}` へ置く。

## 2. 書く

[適用手順](references/apply.md)を読み、その順で書く。write-doc から呼ばれた場合は渡された `persona`・`reader_context`・`goal_questions`・（settle を通ったなら）`decisions` を使い、単独使用なら依頼と資料から同じ情報を整理する。

## 3. 出す前に

[final-check.md](references/final-check.md)の問いに本文だけを根拠に答える。write-doc で使う場合は、`goal_questions` の各問いを本文だけで答え、`expected` と照合した結果を `reader_review` に残し、経路表を `reading_path` として次工程へ渡す。

## 実行設定の寿命

prepareが返した絶対pathを実行記録へ保持する。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。他runの設定やdirectoryを削除しない。
