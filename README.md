# write-doc

素材から Markdown の資料を1本書いて保存する package である。公開入口（外部から呼べる skill）は `write-doc` の一つだけで、読み手を決める、型を選ぶ、構成を決める、書く、読み直す、保存する、を同じ agent が最後まで続けて行う。ほかの skill や、設定を組み立てるスクリプト、途中の YAML は使わない。

## 使い方

`write-doc` に、素材の `material` と保存先を渡す。新しく作るなら `output_directory` と `name` を、書き直すなら `update_target` を渡す。文書型の `document_type` と、追加で従う資料の `references` は省略してよい。保存先と名前は依頼のとおりに使い、日本語のディレクトリ名やファイル名も使える。

ほかの package からも同じ入力で呼び、`status` と `path`（失敗なら `reason`）を受け取る。ほかの package の検査が資料から読んでよいのは、各型のテンプレートの冒頭にある「検査が読む目印」だけである。

## 書き方の決まり

どの文書型にも共通する書き方は、[書くときの規範](plugins/write-doc/skills/write-doc/references/writing-norms.md) にまとめてある。書く前に主メッセージを一文で書き、見出しだけの骨組みで話が通るかを確かめてから本文に入る。型ごとのテンプレートと見本は、この規範の上に載る。

資料の冒頭は、読み手が知っている言葉で書いた本文の段落から始める。誰が何のために読み、どこから始まり、何が見えたら終わりなのかを文章で書き、型や確認した日の一覧を冒頭に置かない。型の読み方はテンプレートの注釈と型の一覧（`assets/template-examples.yml`）に一度だけ書き、資料の本文には書かない。

## 構成

```text
plugins/write-doc/
├── .claude-plugin/plugin.json      二つの実行環境の manifest
├── .codex-plugin/plugin.json
├── LICENSE
└── skills/write-doc/               公開入口
    ├── SKILL.md                    目的、入力、判断基準、手順、止まるとき、出力
    ├── references/                 書くときの規範、保存する前の読み直し、本文と表と図の受け持ち
    └── assets/                     型ごとのテンプレート（冒頭に検査が読む目印）と見本、読み手の像、型の一覧
```

## 検査

```bash
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate.sh
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins
```

保守の道具（構造の検査、回帰の検査、release、eval）は、隣に checkout した `../harness-tools/` のものを使い、このリポジトリには写しを置かない。`scripts/validate.sh` は `../harness-tools/tools/` があるかを確かめてから呼び、無ければ止まる。CI の `validate.yml` も `harness-tools` を隣に checkout して、`harness-tools/ci/validate.sh` を動かす。

構造の検査が通っても、文章が良いことにはならない。SKILL.md、テンプレート、書いた資料は、読んで根拠を挙げて評価する。
