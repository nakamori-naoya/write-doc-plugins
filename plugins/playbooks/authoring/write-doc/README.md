# write-doc

**資料を1本書いて保存する上段プラグイン。** 自分では型も規律も図の選択基準も媒体も持たず、4つを組み合わせる。

| 下段 | 何を決めるか |
|---|---|
| `content-types` | **何を書くか** — 型と、その骨格 |
| `writing-rules` | **どう書くか** — 構成・段落・強調・文体・出典 |
| `visual-guidance` | **何をどう図にするか** — 読み手の問いと図の型 |
| `doc-render` | **どう出すか** — 媒体表現と保存 |

**4つは互いを知らない。** つなぐのは「意味上の役」だけで、その契約はこのプラグインが持つ（[references/roles.md](references/roles.md)）。

## 使う

```
/write-doc      資料を1本書く
```

**下段が1つでも欠けていたら止まる。** 黙って劣化した結果を出さない。**「規律なしで資料が出る」は、資料が出ないことより悪い。**

```
[error] 下段プラグインが見つからない: writing-rules
        write-doc は組み立て役なので、欠けたまま書くと質が担保されない。
```

## 設定

出力する資料全体にかかる決定的な要件だけは、この上段が持つ。**既定では、主要な主張を理解させる図を最低1つ要求する。**

```yaml
# <repo>/.harness-plugins/write-doc.config.yml
# 同梱playbook.ymlを丸ごと複製し、次の値を変更する
requirements: {figures: false}
```

外部設定は`version`、`name`、`instructions`、`requires`、`contract`、`requirements`、`steps`をすべて持つ。部分設定は受け付けない。

`false` は図を禁止する指定ではなく、最低1つという要件を外す指定である。図の題材と型は `visual-guidance`、媒体へどう描くかは `doc-render` が持つ。

| ファイル | 誰のもの |
|---|---|
| `.harness-plugins/writing-rules.config.yml` | 規律の差し替え |
| `visual-guidance` の references | 目的別の図の選択基準 |
| `.harness-plugins/content-types.config.yml` | テンプレートの置き場・既定の型 |
| `.harness-plugins/doc-render.config.yml` | 出力先・形式・テーマ |
| `.harness-plugins/write-doc.config.yml` | 資料全体の要件・工程の上書き |

呼び出し元playbookが`output_format`を固定した場合は、その値をdoc-render設定の`output.format`より優先する。これは、BDD資料のように媒体自体が上段の成果契約である場合に限る。指定が無い通常の呼び出しはdoc-render設定へ従う。

## 実行状態

各工程は `pending → running → completed` の順で進み、失敗は `failed` で止まる。前工程を飛ばした開始や、`provides`不足での完了は拒否する。状態はrepositoryではなく`${XDG_STATE_HOME:-~/.local/state}/harness-plugins/playbooks/write-doc/`へ保存する。成果物本文は台帳へ入れず、参照だけを持つ。

## しないこと

- **型を持たない。** カタログは `content-types`
- **規律を持たない。** 書き方は `writing-rules`
- **図の選択基準を持たない。** 図の設計は `visual-guidance`
- **媒体を持たない。** タグも CSS も `doc-render`
- **中身を機械で検査しない**
