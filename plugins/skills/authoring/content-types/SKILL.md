---
name: pick-content-type
description: 読み手と目的から、書くべき文書の型を決める。Product North Star／Product Strategy／業務知識・コアドメイン／ユーザー目的達成BDD／RDB論理設計／README／チュートリアル／コンセプト／ADR／実装解説／期間ダイジェスト／コード地図など28種のカタログ、テンプレート、記載例を返す。「どの型で書くべき？」「User JourneyをBDD資料にして」「この文書は何？」と聞かれたときに使う。
---

# pick-content-type（型を決める）

**このスキルは文章を書かない。** 読み手と目的から**型を1つ決め、その骨格を渡す**ところまでを担う。

**規律も媒体も知らない。** どう書くか・どう出すかは、それぞれ別の関心である。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/skills/authoring/content-types" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/skills/authoring/content-types"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. カタログを読む

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
printf '%s\n' "$CFG_FILE"
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

型の指定がある場合も、主な読み手・読む場面・既知のこと・説明が必要なこと・起こりそうな誤解・読後にできる判断や行動を短く記録する。依頼と提供資料から分かる範囲を使い、推定は仮定と明示する。playbookから呼ばれた場合はこの記録を`reader_context`として骨格と一緒に返す。文体や本文の順序の設計は執筆担当へ渡す。

## 3. テンプレートを取る

`${.template_examples}`を読み、`pairs.<slug>.template`に指定されたテンプレートを`${.plugin_root}`からの相対パスとして使う。slugはcatalogの列をそのまま使い、翻訳・短縮しない。対応が無い、パスが配布物の外を指す、またはファイルが無い場合は停止する。利用できるのは同梱28種だけで、リポジトリ独自の型・テンプレート・上書きは受け付けない。

テンプレートは必要な情報とその所在を示す出発点として渡す。依頼・呼び出し元の成果契約・専門型の不変条件で指定された見出しや順序は保持する。それ以外は、読み手の目的に応じて節の省略・統合・並べ替えを執筆担当が判断できる。型の目的と必要情報を保ち、変更理由を読者の到達点に結びつけて作業記録に残す。

必須の節に該当事項がないと確認できた場合は「なし」、情報不足は「未確認」と区別する。任意の節を埋めるための推測や枝葉の説明を足さない。判断に影響する未確認は省略せず本文へ残す。依頼者が構成を明示した場合はその指定を優先する。

## 4. 記載例を必ず読む

同じ`${.template_examples}`の`pairs.<slug>.example`に指定された記載例を`${.plugin_root}`からの相対パスとして取り、**テンプレートを埋める前に全文読む**。対応するテンプレートと記載例の両方を選んだことを確認してから執筆する。28種すべてに記載例があり、見つからなければ停止する。

**テンプレートは節の名前しか伝えない。** 節をどの粒度で切るか、図を何で描くか、具体例をどこまで具体的に書くかは、記載例を見ないと揃わない。記載例を読まずに書き始めない。

記載例はテンプレートの既定構成を具体化している。**題材の中身を写さず、説明の関係と粒度を読み取る。** 構成を調整する場合も、型が必要とする情報の役割を保つ。

記載例からは、読み手が何を理解するためにその構成を使っているかを読み取る。たとえば業務の型は決まりと最後の具体例を対応させ、データモデルの型は業務上の事実と記録の変化を対応させている。この方法が役立つ型では応用するが、別の型へBDDや同じ説明順を追加する必要はない。具体例を最後へまとめる型の配置は保つ。

## 実行設定の寿命

prepareが返した絶対pathを実行記録へ保持する。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。他runの設定やdirectoryを削除しない。
