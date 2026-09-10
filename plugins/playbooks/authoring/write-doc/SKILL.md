---
name: write-doc
description: 資料を1本書いて保存する。読み手と目的から文書の型を決め、規律に従って書き、HTML か Markdown へ写して保存する。「資料にして」「サマリを作って」「ドキュメントを書いて」と言われたときに使う。
---

# write-doc

**資料を1本書いて、保存するところまで通す。**

四つのものを噛み合わせる。**何を書くか**（型と骨格）、**どう書くか**（構成・段落・強調・文体・出典の規律）、**何をどう図にするか**（問いと図の型）、**どう出すか**（媒体表現と保存）。各担当をつなぎ、最後に完成文書の確認（review-doc）を呼ぶのがこのスキルの仕事である。

**この段取りは、公開契約と内部の橋渡しも担う。** 呼び出し元から受けた入力を工程へ渡し、結果を契約の形へ写して返す。契約の正本は[CONTRACT.md](CONTRACT.md)（契約 ID `write-doc/write-doc`、版 1）である。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/playbooks/authoring/write-doc" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/playbooks/authoring/write-doc"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 工程を解決して、書かれた順に実行する

**まず、自分がどちらの呼ばれ方をしているかを決める。**

| 呼ばれ方 | `CFG_FILE` の決め方 |
|---|---|
| 呼び出し元が解決済みYAMLの絶対pathを渡してきた（入れ子実行） | **その path をそのまま `CFG_FILE` にする。prepare を実行しない** |
| 利用者が `/write-doc` で直接呼んだ（単独起動） | 下の `prepare.sh` を自分で実行する |

**渡されたのに prepare をやり直すと、呼び出し元が決めたものが消える。** 呼び出し元は `--input`（契約入力）、`--scope`（入口が決めた scope）、`--bindings`（実行内で固定した束縛）を載せて解決している。もう一度 prepare すると、入力は失われ、scope は自分の名前で作り直され、束縛は別の lock として引き直される。**受け取った解決済みYAMLは、作り直さずそのまま使う。**

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
printf '%s\n' "$CFG_FILE"
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

**上の実行は単独起動のときだけである。** 入れ子実行では、渡された path を `CFG_FILE` へ入れて次へ進む。`${...}` の読み方はどちらでも同じである。

呼び出し元がこの段取りを呼ぶ手順は、契約で 2 段に決まっている（[CONTRACT.md](CONTRACT.md) §1）。呼び出し元が `scripts/prepare.sh <repo> --input=<abs> [--scope=<dir>] [--bindings=<lock>]` を実行して解決済みYAMLの絶対pathを得て、**その path を添えてこの SKILL.md へ実行を渡す**。**この段取りが自分で prepare し直すことはない。**

最初に `${.instructions.execution.directive}` と `${.instructions.config.directive}` に従う。保存工程では `${.deps.doc-render.root}` のresolverも実行する。**依存先の解決済みYAMLは `${<プラグイン名>:.path}` と書く**（自分の解決済みYAMLと取り違えないため）。`${doc-render:.output.theme}`、`${doc-render:.instructions.render.directive}`、`${doc-render:.instructions.render.themes.<theme>.directive}`、`${doc-render:.instructions.render.themes.<theme>.palette}` に従う。

`output_format`を受け取った場合は、`${.playbook.contract.output_formats}`の値であることを確かめ、その媒体の手引きで本文を作る。保存工程へ`--format <output_format>`を渡し、`${.playbook.contract.output_format_precedence}`どおりdoc-render設定のformatより優先する。指定が無い場合だけ`${doc-render:.output.format}`を使う。

保存工程では、type工程が返した文書型slugをdoc-renderへ`--template <type>`として必ず渡す。新規作成先は次の優先順位で一つに決める。

ファイル名は呼び出し元が渡した`name`を使う（直接呼ばれた実行では自分で決める）。保存するdirectoryは次の優先順位で一つに決める。

1. `output_directory`を受け取った場合は、`--output-dir <output_directory>`を使う。依頼にないpathを推測して渡さない
2. `${doc-render:.output.routes}`の`templates`に`type`が完全一致すれば、そのrouteの`dir`を使う
3. 一致しなければ`${doc-render:.output.default}`を使う

**`output_directory`を受け取らなかった新規作成は、2と3で決まる。** 呼び出し元が directory を渡さないのは「利用者の設定に委ねる」という意味であり、保存しない理由にはならない。

設定の`dir.type`は`relative`か`absolute`を必ず明示する。`relative`の`path`は作業repository基準、`absolute`の`path`は`~/`または`/`で始める。typeとpathが矛盾する場合や、環境変数、`..`を含む場合は推測して補わない。routeの解決は新規作成だけに適用し、`update_target`の更新先は変更しない。

**各工程を呼ぶときは `--scope=${.resolution.scope_root}` を必ず渡す。**この段取りを通るときだけ効く設定がそこにある。渡さなければ効かない。入れ子の段取りへは、受け取ったものをそのまま渡す（自分の名前で作り直さない）。

**exit 2 で止まったら先へ進まない。** 何が起きたかは `scripts/resolve.sh` の冒頭に書いてある。

実行前に[状態管理](references/state-management.md)の`init`を行い、各工程を`start`してから着手し、`${.playbook.steps[].provides}`がすべて揃った後だけ`complete`する。失敗は`fail`で記録し、修復後に`retry`を明示して同じ`PLAYBOOK_RUN_ID`で再開する。状態ファイルをrepository内へ作らない。

## 2. 呼び出し元の入力を読む

```bash
INPUT=$(python3 "${PLUGIN_ROOT}/scripts/contract-io.py" read --config "$CFG_FILE") || exit 2
```

`present` が `true` なら、**その `document_type` / `material` / `output_format` / `name`（+ 任意の `output_directory`）または `update_target` / `references` が今回の依頼である**。

**入力の検査は入口で済んでいる。** `prepare.sh --input=` が `scripts/validate-input.sh` を通しているので、ここまで来た入力は契約 schema を満たしている。schema 違反・実装していない文書型・保存先の規則違反は、工程が1つも動く前に exit 2 で止まっている。このコマンドは、検査済みの入力を内部で使う形へ読み直すためのものである。

`present` が `false` のときは、利用者が `/write-doc` で直接呼んだ実行である。素材と保存先は依頼文と作業中の会話から決め、`output_to` は持たない。

**受け取ったものは、この段取りの中でだけ言い換える。** 契約の語（`material` / `update_target` / `output_directory` / `name` / `output_format` / `references`）を下段の工程が使う形へ写すのはこの段取りの責務であり、呼び出し元は下段の語を知らない。

`references` は**呼び出し元自身の文書**である。各工程へ追加指示として読ませ、無視しない。

## 3. 型を選び直させない

呼び出し元が型を指定してきたときは、**その型で書く**。選び直したら、呼び出し元がかけた制限を外したのと同じである。

指定が無いときだけ、型を決める工程に選ばせる。**選んだ型と理由を、書き始める前に1行で宣言する。**

型が指定済みでも、reader工程は3つを順に決める。**順序を入れ替えない。**

1. 同梱5人から**読み手を1人選ぶ**（`persona`）
2. その案件に固有の既知・未知を`reader_context`へ埋める
3. 読後の到達点を、**本文だけで答えられる問い2〜4個**へ落とす（`goal_questions`）

**`goal_questions`が、以降すべての判断基準になる。** あわせて、到達点の判断に必要な事実で素材に無いものを`open_questions`に残す（無ければ `count: 0`）。**型の節を埋められないことは不明点にしない。**

## 4. 曖昧さは、書く前に外の段取りへ渡して潰す

**中身が欠けたまま書き始めない。** 穴があると、その穴を枝葉で埋めることになる。`settle`工程は`when: open_questions.count > 0`の条件付きで、外部の段取り`grill`を`playbook:`の工程として呼ぶ。問いが無ければ`state.py skip --step settle`で飛ばす。依頼が明示している事項や、調べれば分かることを問い直さない。判断の詳細は[読者への引き継ぎ契約](references/reader-contract.md)をここで読む。

**この段取りは、相手の中の作りを知らない。** 使ってよいのは、相手が公開契約で示した入口だけである。手順は次の3つで固定する。

1. 入力YAMLを一時領域（`$(mktemp -d)` の下。作業repositoryの中には作らない）へ書く。`topic`は日本語のままでよい。`questions`はtype工程が残した`open_questions`から作り、**各問いに推奨回答を必ず添える**。

```yaml
contract: grill/grill
version: 1
topic: <何について詰めるか。資料の題材>
context:
  purpose: <goal_questionsに落とした到達点>
  audience: <選んだペルソナと、reader_contextの固有事情>
  boundary: <今回の資料で扱わない範囲>
questions:
  - id: <open_questionsのid>
    question: <問い>
    recommendation: <推奨回答と、その理由>
output_to: <一時領域の絶対path>
```

2. 相手の入口で解決する。**受け取った scope と束縛をそのまま渡す。** 解決するのは**こちらの仕事**であり、相手にやり直させない。

```bash
DEP_CFG=$(bash "${.deps.grill.root}/scripts/prepare.sh" "$(pwd)" \
  --input="$GRILL_INPUT" --scope="${.resolution.scope_root}" --bindings="${.resolution.bindings_lock}") || exit 2
```

3. `${.deps.grill.entry}` のSKILL.mdを読み、**`DEP_CFG` を渡して、そこに書かれた手順で実行する**。相手には prepare をやり直させない。やり直されると、渡した入力・scope・束縛が消える。終わったら `output_to` のYAMLから `decisions` と `open_questions` を受け取る。`decisions`をdraft工程の前提として渡し、残った`open_questions`は報告に含める。

**相手の中を覗かない。** 内部の工程名・skill名・script・設定キー・記録形式は契約に無い。相手を指す形は `${.deps.grill.root}`（直下の `scripts/prepare.sh` / `playbook.yml` / `scripts/resolve.sh` の3つだけ）と `${.deps.grill.entry}`（入口SKILL.mdの絶対path）の**2つだけ**である。skill 名で入口を指す形（`.skills.<名前>`）は使わない。相手が exit 2 で止まったら、こちらも止める。

draft工程は、`persona`・`reader_context`・`goal_questions`と（settleを通ったなら）`decisions`を前提に、writing-rulesの適用手順に従い、まず概念の導入順を決める経路表を`reading_path`として残し、その順で本文を書く。**テンプレートは節の候補として参照するだけで、埋める枠として扱わない。** 経路表に無い節を本文へ置かない。

最終確認で本文の根拠を伴う`reader_review`を返す。**これは自己申告であり、合否ではない。** 合否はjudge工程が決める。

## 5. 役を媒体へ写す

規律の側は強調を**二つの役の名前**でしか扱わない——`要点` / `キーワード`。冒頭の要点や文書全体の主張は見出しと段落が運び、役ではない。

**それを何のタグ・記号にするかは、媒体の側が決める。** 対応表は `playbook.contract` と、媒体側の手引きにある。確認が必要なときだけ[役の契約](references/roles.md)を読む。**このスキルはどちらの中身も解釈しない。**

## 6. 図の要件を確定して、図の工程へ渡す

解決した設定の `requirements.figures` を読み、要件を確定してから図の工程へ渡す。
**資料かどうかを知っているのはこの上段である。下段へ必須判定を押し付けない。**

返った `figures_applied` を確定した要件と照合する。**枚数を満たすための飾り図を作らせない。** 上限も課さない。図の方が速く正確に伝わる関係は、すべて図にする。
判断の詳細は[図の要件](references/figures.md)。

## 7. 保存の前に、独立した読み手で判定する

**書いた本人が読めば通じる。** だから合否は、執筆の文脈を持たない読み手が決める。judge工程で`review-doc`を呼び、**本文・`persona`・`goal_questions`の問いだけ**を渡す。

**渡してはいけないもの**を挙げる。依頼文、素材、`reader_context`、`reading_path`、`reader_review`、`decisions`、そして問いの期待する答え。渡すと読み手が本文に無い情報で穴を埋め、判定が成立しない。

合格は次の2つを**同時に**満たしたときだけである。

- 全部の問いに、本文だけを根拠に答えられ、答えが期待と一致する（照合はこの工程で行う）
- 詰まった箇所（語が分からない、前提が飛んでいる、順序が逆）の報告が0件

**点数で判定しない。** 不合格なら`judgement`へ問いごとの答えと詰まりの一覧を残し、`draft`へ戻す。**表現だけを直して通そうとしない。** 詰まりは経路の設計から出ていることが多いので、経路表の概念の順序と足場から直す。

3回戻しても合格しないときは止め、`reader`工程へ差し戻す。読み手の選択か到達点の設定が合っていない可能性が高い。

**判定を通った本文だけを保存する。** 不合格の文書をディスクへ残さない。

## 8. 保存で止まったら、既存を読む

保存の工程が `exit 3`（同名が既にある）を返したら、**既存を読んでから差し替えを判断する**。読まずに `--replace` を付け足すのは、上書き防止を外すのと同じである。

呼び出し元から`update_target`（既存資料の絶対path）を受け取った場合は、保存工程へ`--target <その絶対path> --replace`を渡す。`output.default`、`output.routes`、`output_directory`、`--name`から保存先を作り直さない。`update_target`が無い新規作成では、`--template <type>`と`--name <name>`（受け取った`output_directory`があれば`--output-dir`も）を使い、既存を読まずに差し替えない。

## 9. 結果を呼び出し元へ返す

`present` が `true` の実行では、確認まで通った後に結果を契約の形へ写して一時ファイルへ置き、次のコマンドで `output_to` の絶対pathへ書く。

```json
{"status": "completed", "path": "/abs/path/document.md", "document_type": "domain-rule", "output_format": "markdown"}
```

```bash
python3 "${PLUGIN_ROOT}/scripts/contract-io.py" write --config "$CFG_FILE" --result "$RESULT_JSON" || exit 2
```

**書けなければ止まる。** 保存できたのに結果を返せない状態を、成功として報告しない。途中で止まったときは `status: failed` と `reason` を書いて返す。`present` が `false` の実行では `output_to` が無いので、この書き出しは行わず、保存したpathを会話へ提示するだけにする。

## 10. 報告する

- 通した工程の `id` を順に（`type` → `settle`（skipしたならその旨） → `draft` → `visual` → `save` → `review`）
- 書いたファイルの**絶対パス**
- 最終確認の結論、修正した主な問題、残る未確認と確認記録のパス
- 入れた図の数と、各図が担う主要な主張
- settleを通ったなら、決めたことの要点と**残った未決**
- 出力YAMLの**絶対パス**（`output_to` を受け取った実行のみ）
- 途中で止まったなら、**どの工程で・なぜ**

## 順番を変えたいとき

`<repo>/.harness-plugins/write-doc.config.yml` に `steps` を書く。**書いたら丸ごと差し替わる。**

## 実行設定の寿命

prepareが返した絶対pathを実行記録へ保持する。**単独起動で自分が prepare したときだけ、自分が後始末する。** 入れ子実行で呼び出し元から受け取った設定は、呼び出し元のものなので消さない。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。**後始末はこの段取りが自分で行い、呼び出し元に委ねない。** 他runの設定やdirectoryを削除しない。settleのために作った一時領域も、自分で消す。

条件付き工程を含め、各工程を呼ぶ直前に`yq -o=json '.' "$CFG_FILE" | python3 "${PLUGIN_ROOT}/scripts/resolve-dependency.py" --check-steps <工程id>`を実行する。失敗時は工程を実行せず停止する。
