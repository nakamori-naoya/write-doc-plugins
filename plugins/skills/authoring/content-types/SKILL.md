---
name: pick-content-type
description: 読み手と目的から、書くべき文書の型を決める。Product North Star／Product Strategy／業務知識・コアドメイン／E2E BDDシナリオ／RDB論理設計／README／チュートリアル／コンセプト／ADR／実装解説／期間ダイジェスト／コード地図など28種のカタログ、テンプレート、記載例を返す。「どの型で書くべき？」「E2Eシナリオを資料にして」「この文書は何？」と聞かれたときに使う。
---

# pick-content-type（型を決める）

**このスキルは文章を書かない。** 読み手と目的から**型を1つ決め、その骨格を渡す**ところまでを担う。

**規律も媒体も知らない。** どう書くか・どう出すかは、それぞれ別の関心である。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. カタログを読む

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
trap 'rm -f "$CFG_FILE"' EXIT
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.instructions.selection.directive}` に従い、`${.catalog}` と `${.default_type}` を読む。

## 2. 決める

**カタログの「選び方」を上から順に判定する。** 決まった型の詳細ファイル（`references/detail/*.md`）**だけ**を読む。全部読まない。

詳細は `${.detail_dir}/<グループ>.md` を読む。

**選んだ型・catalogのslug・理由を1行で宣言する。** 読み手か目的が不明なら聞く。両方が判明してもカタログ上で一意に定まらない場合だけ、`${.default_type}`をslugとして選ぶ。

**1本に複数の型を混ぜない。** 必要なら分けて相互リンクする。

## 3. テンプレートを取る

`${.template_examples}`を読み、`pairs.<slug>.template`に指定されたテンプレートを`${.plugin_root}`からの相対パスとして使う。slugはcatalogの列をそのまま使い、翻訳・短縮しない。対応が無い、パスが配布物の外を指す、またはファイルが無い場合は停止する。利用できるのは同梱28種だけで、リポジトリ独自の型・テンプレート・上書きは受け付けない。

**テンプレートの見出し構成を勝手に変えない。** 埋められない節は削らず「なし」と書く（空欄と「なし」は別の情報である）。

## 4. 記載例を必ず読む

同じ`${.template_examples}`の`pairs.<slug>.example`に指定された記載例を`${.plugin_root}`からの相対パスとして取り、**テンプレートを埋める前に全文読む**。対応するテンプレートと記載例の両方を選んだことを確認してから執筆する。28種すべてに記載例があり、見つからなければ停止する。

**テンプレートは節の名前しか伝えない。** 節をどの粒度で切るか、図を何で描くか、具体例をどこまで具体的に書くかは、記載例を見ないと揃わない。記載例を読まずに書き始めない。

記載例は題材が違っても構造は同じである。**題材の中身を写すのではなく、粒度と書きぶりを写す。**
