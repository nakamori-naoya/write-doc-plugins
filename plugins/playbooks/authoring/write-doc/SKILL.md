---
name: write-doc
description: 資料を1本書いて保存する。読み手と目的から文書の型を決め、規律に従って書き、Markdown へ写して保存する。「資料にして」「サマリを作って」「ドキュメントを書いて」と言われたときに使う。
---

# write-doc

**資料を1本書いて、保存するところまで通す。**

四つのものを噛み合わせる。**何を書くか**（型と骨格）、**どう書くか**（構成・段落・強調・文体・出典の規律）、**何をどう図にするか**（問いと図の型）、**どう出すか**（媒体表現と保存）。各担当をつなぎ、保存まで通すのがこのスキルの仕事である。

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

**呼び出し元が解決済みYAMLのpathを渡してきたなら、prepareを再実行しない。** 呼び出し元は `scripts/prepare.sh <repo> --input=<abs> [--scope=<dir>] [--bindings=<lock>]` で解決済みYAMLを作り、その path を添えてこの SKILL.md へ実行を渡す（[CONTRACT.md](CONTRACT.md) §1）。渡されたのに prepare をやり直すと、呼び出し元が載せた入力・scope・束縛が消える。**自分で prepare するのは、自分が入口のとき（単独起動）だけである。**

<!-- BEGIN shared:skill-entry/config-load -->
```bash
if [ -n "${CFG_FILE:-}" ] && [ -f "$CFG_FILE" ]; then
  : # 呼び出し元がE1で解決済み。入れ子実行では prepare を実行しない
else
  # 単独起動
  CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
fi
printf '%s\n' "$CFG_FILE"
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

上の prepare は単独起動のときだけ走る。`${...}` の読み方は、どちらの呼ばれ方でも同じである。

最初に `${.instructions.execution.directive}` と `${.instructions.config.directive}` に従う。**依存先の解決済みYAMLのプロパティは `${<プラグイン名>:.<プロパティ>}` と書く**（例 `${doc-render:.writer}`。自分の解決済みYAMLと取り違えないため）。

**設定を持つ下段は、この段取りが `--scope=${.resolution.scope_root}` 付きで解決し、解決済みYAMLの path を渡す。** 下段の SKILL.md にある prepare は実行させず、`CFG_FILE` に渡した path を使わせる。この段取りを通るときだけ効く設定が scope にある。

| 工程 | 解決 | 渡し方 |
|---|---|---|
| `reader` | `CT_CFG=$(bash "${.deps.content-types.root}/scripts/prepare.sh" "$(pwd)" --scope="${.resolution.scope_root}")` | content-types の SKILL.md を `CFG_FILE="$CT_CFG"` で実行する |
| `draft` | `WR_CFG=$(bash "${.deps.writing-rules.root}/scripts/prepare.sh" "$(pwd)" --scope="${.resolution.scope_root}")` | writing-rules の SKILL.md を `CFG_FILE="$WR_CFG"` で実行する |
| `save` | `DR_CFG=$(bash "${.deps.doc-render.root}/scripts/resolve.sh" "$(pwd)" --scope="${.resolution.scope_root}")` | `${doc-render:.writer}` へ `--config "$DR_CFG"` で渡し、`${doc-render:.instructions.render.directive}` に従う |

`visual` 工程（visual-guidance）は設定を持たないので、SKILL.md の `--root-only` 検証だけを実行させる。各工程を呼ぶ直前に `yq -o=json '.' "$CFG_FILE" | python3 "${PLUGIN_ROOT}/scripts/resolve-dependency.py" --check-steps <工程id>` を実行し、失敗したら工程を実行せず停止する。**exit 2 で止まったら先へ進まない。**

工程の記録の置き場は[記録の契約](references/reader-contract.md)の `ARTIFACT_DIR`、状態の遷移と再開は[状態管理](references/state-management.md)に従う。

## 2. 呼び出し元の入力を読む

```bash
INPUT=$(python3 "${PLUGIN_ROOT}/scripts/contract-io.py" read --config "$CFG_FILE") || exit 2
```

`present` が `true` なら、その `document_type` / `material` / `output_format` / `name`（+ 任意の `output_directory`）または `update_target` / `references` が今回の依頼である。入力の検査は入口（`prepare.sh --input=`）で済んでいるので、ここまで来た入力は契約 schema を満たしている。

`present` が `false` なら、利用者が `/write-doc` で直接呼んだ実行である。素材と保存先は依頼文と作業中の会話から決め、ファイル名は CONTRACT の `name` の制約（`[A-Za-z0-9_-][A-Za-z0-9._-]*\.md`）に合わせて自分で決める。`output_to` は持たない。

契約の語（`material` / `update_target` / `output_directory` / `name` / `output_format` / `references`）を下段の工程が使う形へ写すのはこの段取りの責務であり、呼び出し元は下段の語を知らない。`references` は呼び出し元自身の文書で、各工程へ追加指示として読ませる。

## 3. 読み手・到達点・型を決める（reader）

呼び出し元が型を指定してきたときは、その型で書き、選び直さない。指定が無いときだけ reader 工程に選ばせる。

型が指定済みでも、reader 工程は `persona` → `reader_context` → `goal_questions` の順に決める。各記録の定義は[読者への引き継ぎ契約](references/reader-contract.md)、決め方は content-types の SKILL.md にある。到達点の判断に必要な事実で素材に無いものは `open_questions` に残る。

## 4. 曖昧さは、書く前に外の段取りへ渡して潰す（settle）

`settle` 工程は `when: open_questions.count > 0` の条件付きで、外部の公開playbook `grill` を `playbook:` の工程として呼ぶ。問いが無ければ `state.py skip --step settle` で飛ばす。

**この段取りは、相手の中の作りを知らない。** 使ってよいのは、相手が公開契約で示した入口だけである。手順は次の3つで固定する。

1. 入力YAMLを一時領域（`$(mktemp -d)` の下。作業repositoryの中には作らない）へ書く。`questions` は reader 工程が残した `open_questions` から作る。

```yaml
contract: grill/grill
version: 1
topic: <何について詰めるか。資料の題材>
context:
  purpose: <goal_questionsに落とした到達点>
  audience: <選んだペルソナと、reader_contextの固有事情>
  boundary: <今回の資料で扱わない範囲>
grounding:
  - <material の絶対path>
questions:
  - id: <open_questionsのid>
    question: <問い>
    recommendation: <推奨回答と、その理由>
output_to: <一時領域の絶対path>
```

2. 相手の入口で解決する。受け取った scope と束縛をそのまま渡す。解決するのはこちらの仕事であり、相手にやり直させない。

```bash
DEP_CFG=$(bash "${.deps.grill.root}/scripts/prepare.sh" "$(pwd)" \
  --input="$GRILL_INPUT" --scope="${.resolution.scope_root}" --bindings="${.resolution.bindings_lock}") || exit 2
```

3. `${.deps.grill.entry}` のSKILL.mdを読み、**`DEP_CFG` を渡して、そこに書かれた手順で実行する**。実行中だけ `WD_CFG="$CFG_FILE"; CFG_FILE="$DEP_CFG"` として自分の path を退避し、終わったら `CFG_FILE="$WD_CFG"` で戻す。`output_to` のYAMLを `$ARTIFACT_DIR/decisions.yml` へ写し、その絶対 path を `decisions` として登録する。残った未決は報告に含める。

相手を指す形は `${.deps.grill.root}`（直下の `scripts/prepare.sh` / `playbook.yml` / `scripts/resolve.sh` の3つだけ）と `${.deps.grill.entry}` の2つだけである。`.skills.<名前>` で入口を指さない。相手が exit 2 で止まったら、こちらも止める。

## 5. 書く（draft）

draft 工程は `persona`・`reader_context`・`goal_questions`・（settle を通ったなら）`decisions` を前提に、writing-rules の適用手順に従って書き、`body`・`roles_applied`・`reading_path`・`reader_review` を返す（[記録の定義](references/reader-contract.md)）。テンプレートの扱いは content-types の SKILL.md §5 に従う。

強調は `要点` / `キーワード` の2つの役の名前でだけ扱い、本文には[役の契約](references/roles.md)の印で書く。どの記法へ写すかは媒体の側が決める。

## 6. 図の要件を確定して、図の工程へ渡す（visual）

解決した設定の `requirements.figures` を読み、要件を確定してから図の工程へ渡す。返った `figures_applied`（ファイル。形は[記録の契約](references/reader-contract.md)）を要件と照合する。判断の詳細は[図の要件](references/figures.md)。

## 7. 保存する（save）

保存工程（`${doc-render:.writer}`）には、`body` の役の印を `${doc-render:.guides.markdown}` の対応表で Markdown の記法へ写し、`figures_applied` の各図を `insert_after` の直後へ置いた Markdown を一時ファイルへ書いて `--body-file <path>` として渡す。`roles_applied` が `none` なら本文に印が残っていないことを確かめる。reader 工程が返した文書型slugを `--template <type>`、ファイル名を `--name <name>`、`--format markdown` を渡す。媒体は Markdown だけである。

画像図（`figures_applied` で `kind: image` の図）は、保存工程が返した path と同じ directory の `<資料名>.assets/` へ置く。固定図はテンプレートの SVG を複製して文言を置き換える。`update_target` の差し替えでは、旧 `<資料名>.assets/` を消してから置く。

新規作成の保存先は次の優先順位で一つに決める。

1. `output_directory` を受け取った場合は `--output-dir <output_directory>`。依頼にないpathを推測して渡さない
2. `${doc-render:.output.routes}` の `templates` に `type` が完全一致すれば、そのrouteの `dir`
3. 一致しなければ `${doc-render:.output.default}`

呼び出し元から `update_target`（既存資料の絶対path）を受け取った場合は、`--target <その絶対path> --replace` を渡し、保存先を作り直さない。

保存の工程が `exit 3`（同名が既にある）を返したら止める（CONTRACT G2）。契約入力ありの実行では `status: failed` と理由を返す。単独起動では既存の path を利用者へ示し、指示を待つ。自分で `--replace` を付け足さない。

## 8. 結果を呼び出し元へ返す

`present` が `true` の実行では、結果を契約の形へ写して一時ファイルへ置き、次のコマンドで `output_to` の絶対pathへ書く。

```json
{"status": "completed", "path": "/abs/path/document.md", "document_type": "domain-rule", "output_format": "markdown"}
```

```bash
python3 "${PLUGIN_ROOT}/scripts/contract-io.py" write --config "$CFG_FILE" --result "$RESULT_JSON" || exit 2
```

書けなければ止まる。保存できたのに結果を返せない状態を、成功として報告しない。途中で止まったときは `status: failed` と `reason` を書いて返す。`present` が `false` の実行では、保存したpathを会話へ提示するだけにする。

## 9. 報告する

- 通した工程の `id` を順に（`reader` → `settle`（skipしたならその旨） → `draft` → `visual` → `save`）
- 書いたファイルの**絶対パス**
- `reader_review` の結論、修正した主な問題、残る未確認と確認記録のパス
- 入れた図の数と、各図が担う主要な主張
- settleを通ったなら、決めたことの要点と残った未決
- 出力YAMLの**絶対パス**（`output_to` を受け取った実行のみ）
- 途中で止まったなら、どの工程で・なぜ

## 順番を変えたいとき

`<repo>/.harness-plugins/write-doc.config.yml` に `steps` を書く。書いたら丸ごと差し替わる。

## 実行設定の寿命

prepareが返した絶対pathを実行記録へ保持する。**単独起動で自分が prepare したときだけ、自分が後始末する。** 入れ子実行で呼び出し元から受け取った設定は、呼び出し元のものなので消さない。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。後始末はこの段取りが自分で行い、呼び出し元に委ねない。他runの設定やdirectoryを削除しない。settleのために作った一時領域も、自分で消す。
