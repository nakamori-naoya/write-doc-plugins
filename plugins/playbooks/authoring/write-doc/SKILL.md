---
name: write-doc
description: 資料を1本書いて保存する。読み手と目的から文書の型を決め、規律に従って書き、HTML か Markdown へ写して保存する。「資料にして」「サマリを作って」「ドキュメントを書いて」と言われたときに使う。
---

# write-doc

**資料を1本書いて、保存するところまで通す。**

四つのものを噛み合わせる。**何を書くか**（型と骨格）、**どう書くか**（構成・段落・強調・文体・出典の規律）、**何をどう図にするか**（問いと図の型）、**どう出すか**（媒体表現と保存）。この四つは互いを知らないので、噛み合わせるのがこのスキルの仕事である。

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

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
printf '%s\n' "$CFG_FILE"
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

最初に `${.instructions.execution.directive}` と `${.instructions.config.directive}` に従う。保存工程では `${.deps.doc-render.root}` のresolverも実行する。**依存先の解決済みYAMLは `${<プラグイン名>:.path}` と書く**（自分の解決済みYAMLと取り違えないため）。`${doc-render:.output.theme}`、`${doc-render:.instructions.render.directive}`、`${doc-render:.instructions.render.themes.<theme>.directive}`、`${doc-render:.instructions.render.themes.<theme>.palette}` に従う。

呼び出し元が`output_format`を渡した場合は、`${.playbook.contract.output_formats}`の値であることを確かめ、その媒体の手引きで本文を作る。保存工程へ`--format <output_format>`を渡し、`${.playbook.contract.output_format_precedence}`どおりdoc-render設定のformatより優先する。指定が無い場合だけ`${doc-render:.output.format}`を使う。

**各工程を呼ぶときは `--scope=${.resolution.scope_root}` を必ず渡す。**この段取りを通るときだけ効く設定がそこにある。渡さなければ効かない。入れ子の段取りへは、受け取ったものをそのまま渡す（自分の名前で作り直さない）。

**exit 2 で止まったら先へ進まない。** 何が起きたかは `scripts/resolve.sh` の冒頭に書いてある。

実行前に[状態管理](references/state-management.md)の`init`を行い、各工程を`start`してから着手し、`${.playbook.steps[].provides}`がすべて揃った後だけ`complete`する。失敗は`fail`で記録し、修復後に`retry`を明示して同じ`PLAYBOOK_RUN_ID`で再開する。状態ファイルをrepository内へ作らない。

## 2. 型を選び直させない

呼び出し元が型を指定してきたときは、**その型で書く**。選び直したら、呼び出し元がかけた制限を外したのと同じである。

指定が無いときだけ、型を決める工程に選ばせる。**選んだ型と理由を、書き始める前に1行で宣言する。**

型が指定済みでも、type工程は読み手の前提と読後の到達点を`reader_context`として残す。draft工程へ型・骨格と一緒に渡す。[読者への引き継ぎ契約](references/reader-contract.md)をここで読む。

draft工程は、writing-rulesの適用手順と最終確認に従い、本文の根拠を伴う`reader_review`を返す。読者が到達点を満たせない箇所を修正してから工程を完了する。図や媒体への変換で説明の順序・用語・例との対応が変わったときは、この確認を更新してから保存する。

## 3. 役を媒体へ写す

規律の側は強調を**四つの役の名前**でしか扱わない——`要点` / `キーワード` / `一言でいうと` / `要約項目`。

**それを何のタグ・記号にするかは、媒体の側が決める。** 対応表は `playbook.contract` と、媒体側の手引きにある。確認が必要なときだけ[役の契約](references/roles.md)を読む。**このスキルはどちらの中身も解釈しない。**

## 4. 図の要件を確定して、図の工程へ渡す

解決した設定の `requirements.figures` を読み、要件を確定してから図の工程へ渡す。
**資料かどうかを知っているのはこの上段である。下段へ必須判定を押し付けない。**

返った `figures_applied` を確定した要件と照合する。**枚数を満たすための飾り図を作らせない。**
判断の詳細は[図の要件](references/figures.md)。

## 5. 保存で止まったら、既存を読む

保存の工程が `exit 3`（同名が既にある）を返したら、**既存を読んでから差し替えを判断する**。読まずに `--replace` を付け足すのは、上書き防止を外すのと同じである。

呼び出し元から、同一path更新guardを通過した既存資料の絶対pathが`update_target`または`logical_update_target`として渡された場合は、保存工程へ`--target <その絶対path> --replace`を渡す。`output.dir`と`--name`から保存先を作り直さない。guard済みtargetが無い通常の資料作成では、従来どおり`--name`を使い、既存を読まずに差し替えない。

## 6. 報告する

- 通した工程の `id` を順に（`type` → `draft` → `visual` → `save`）
- 書いたファイルの**絶対パス**
- 入れた図の数と、各図が担う主要な主張
- 途中で止まったなら、**どの工程で・なぜ**

## 順番を変えたいとき

`<repo>/.harness-plugins/write-doc.config.yml` に `steps` を書く。**書いたら丸ごと差し替わる。**

## 実行設定の寿命

prepareが返した絶対pathを実行記録へ保持する。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。他runの設定やdirectoryを削除しない。

条件付き工程を含め、各工程を呼ぶ直前に`yq -o=json '.' "$CFG_FILE" | python3 "${PLUGIN_ROOT}/scripts/resolve-dependency.py" --check-steps <工程id>`を実行する。失敗時は工程を実行せず停止する。
