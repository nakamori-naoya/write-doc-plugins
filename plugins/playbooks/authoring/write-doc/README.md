# write-doc

**資料を1本書いて保存する上段プラグイン。** 自分では型も規律も図の選択基準も媒体も持たず、下段を工程として組み合わせる。

**外部から見える面は[CONTRACT.md](CONTRACT.md)（契約 ID `write-doc/write-doc`、版 1）だけである。** 下の表は内部の作りであり、契約ではない。

| 工程 | 下段 | 何を決めるか |
|---|---|---|
| `reader` | `content-types` | 読み手を1人、読後の到達点を問いへ、そこから型と骨格 |
| `settle`（`open_questions.count > 0` のときだけ） | `grill`（外部・公開playbook） | 到達点の判断に必要で素材に無い事実を、推奨付きで1問ずつ合意する |
| `draft` | `writing-rules` | 主張・経路・構成・段落・強調・文体・出典 |
| `visual` | `visual-guidance` | 読み手の問いと図の型 |
| `save` | `doc-render` | 媒体表現と保存 |

工程間で引き継ぐ記録の定義は[記録の契約](references/reader-contract.md)、強調と図の役は[役の契約](references/roles.md)にある。

必要なidentityは `grill@grill`（外部）と、`content-types@write-doc`、`writing-rules@write-doc`、`visual-guidance@write-doc`、`doc-render@write-doc`（内部）。versionは固定せず、解決先のmanifest identityと各工程が指すものを検査する。外部の実体は利用者が `dependencies.yml` で契約ID `grill/grill` へ束縛して差し替える。

## 使う

```
/write-doc      資料を1本書く
```

**下段が1つでも欠けていたら止まる。** 「規律なしで資料が出る」は、資料が出ないことより悪い。

```
[error] 下段プラグインが見つからない: writing-rules
        write-doc は組み立て役なので、欠けたまま書くと質が担保されない。
```

## 外部playbookの呼び方

`grill` は相手のCONTRACT.mdが公開した入口だけで呼ぶ。入力YAML（題材・文脈・問いと推奨・出力先）を一時領域に置いて渡し、返された出力YAMLから決定と未決を受け取る。解決はこちらが1回だけ行い、得た解決済みYAMLのpathを相手の入口SKILL.mdへ渡す。この段取り自身も、呼び出し元から解決済みYAMLのpathを受け取ったときは `prepare` を実行せず、それをそのまま使う（[CONTRACT.md](CONTRACT.md) §1）。

## 設定

出力する資料全体にかかる要件だけを、この上段が持つ。`requirements.figures` の意味は [references/figures.md](references/figures.md) にある。

```yaml
# <repo>/.harness-plugins/write-doc.config.yml
# 同梱playbook.ymlを丸ごと複製し、次の値を変更する
requirements: {figures: true}
```

外部設定は `version`、`name`、`instructions`、`requires`、`contract`、`requirements`、`steps` をすべて持つ。部分設定は受け付けない。`steps` を書いた設定は同梱 playbook.yml の工程を引き継がず、丸ごと差し替わる。開始済みrunの設定は変更せず、新しいrunで使う。

| ファイル | 誰のもの |
|---|---|
| `.harness-plugins/write-doc.config.yml` | 資料全体の要件・工程の上書き |
| `.harness-plugins/content-types.config.yml` | 既定の型 |
| `.harness-plugins/writing-rules.config.yml` | 規律の差し替え |
| `.harness-plugins/doc-render.config.yml` | 保存先。文書型ごとの保存先は `output.routes` |

媒体は Markdown だけである。呼び出し元が `output_format` を渡す場合も値は `markdown` に限る。

## 実行状態

工程の状態遷移・再開・保存場所は [references/state-management.md](references/state-management.md) にある。

## しないこと

- 型を持たない。カタログは `content-types`
- 規律を持たない。書き方は `writing-rules`
- 図の選択基準を持たない。図の設計は `visual-guidance`
- 媒体を持たない。Markdown の記法は `doc-render`
- 中身を機械で検査しない
