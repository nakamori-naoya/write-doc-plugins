# write-doc

素材から Markdown の資料を1本書いて保存する plugin である。外から呼べる skill は `write-doc` の一つだけで、読み手を決める、型を選ぶ、構成を決める、書く、読み直す、保存する、を同じ agent が最後まで続けて行う。ほかの skill や、設定を組み立てる script、途中の YAML は使わない。

## 使い方

`write-doc` に、素材の `material` と保存先を渡す。新しく作るなら `output_directory` と `name` を、書き直すなら `update_target` を渡す。文書型の `document_type` と、追加で従う資料の `references` は省略してよい。保存先と名前は依頼のとおりに使い、日本語の directory 名や file 名も使える。

ほかの plugin からは、公開契約 `write-doc/write-doc` の版2で呼ぶ。入力、出力、約束することは [公開契約](plugins/write-doc/skills/write-doc/CONTRACT.md) が決める。

```yaml
requires:
  - {plugin: write-doc, marketplace: write-doc}
steps:
  - id: document
    playbook: write-doc
    purpose: 完成した本文を kind:text の material として渡し、Markdown を1本保存する
    provides: [status, path, reason]
```

## 書き方の決まり

どの文書型にも共通する書き方は、[書くときの規範](plugins/write-doc/skills/write-doc/references/writing-norms.md) にまとめてある。書く前に主メッセージを一文で書き、見出しだけの骨組みで話が通るかを確かめてから本文に入る。型ごとの template と見本は、この規範の上に載る。

資料の冒頭は、読み手が知っている言葉で書いた本文の段落から始める。誰が何のために読み、どこから始まり、何が見えたら終わりなのかを文章で書き、型や確認した日の一覧を冒頭に置かない。型の読み方は template の注釈と型の一覧（`assets/template-examples.yml`）に一度だけ書き、資料の本文には書かない。

## 構成

```text
plugins/write-doc/
├── .claude-plugin/plugin.json      二つの実行環境の manifest
├── .codex-plugin/plugin.json
├── LICENSE
└── skills/write-doc/               外から呼べる skill
    ├── SKILL.md                    目的、入力、判断基準、手順、止まるとき、出力
    ├── playbook.yml                同じ agent が進める7つの工程の順番
    ├── CONTRACT.md                 公開契約の版2
    ├── references/                 書くときの規範、保存する前の読み直し、本文と表と図の受け持ち
    └── assets/                     20の型の template と見本、読み手の像、図の参考、型の一覧
```

## 検査

```bash
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate.sh
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins
```

保守の道具（構造の検査、回帰の検査、release、eval）は、隣に checkout した `../harness-tools/` のものを使い、この repository には写しを置かない。`scripts/validate.sh` は `../harness-tools/tools/` があるかを確かめてから呼び、無ければ止まる。CI の `validate.yml` も `harness-tools` を隣に checkout して、`harness-tools/ci/validate.sh` を動かす。

構造の検査が通っても、文章が良いことにはならない。SKILL.md、template、書いた資料は、読んで根拠を挙げて評価する。契約の版1からの移り変わりは [契約 v2 移行表](docs/contract-v2-migration.md) にある。
