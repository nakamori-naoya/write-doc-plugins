# write-doc

素材から Markdown 資料を1本書いて保存する package である。公開入口は自己完結skill `write-doc` 1つで、読み手と目的の固定、型の選択、構成、直接執筆、推敲の自己監査、保存を同じagentが一気通貫で行う。内部skill、設定解決script、中間YAML、外部playbookは使わない。

## 使い方

`write-doc` に `material` と保存先を直接渡す。新規作成では `output_directory` と `name`、更新では `update_target` を渡す。`document_type` と `references` は任意である。保存先と名前は依頼で示された資料構成に従い、日本語のdirectory名・file名を使える。

外部packageからは公開契約 `write-doc/write-doc` v2 で呼ぶ。入力、出力、保証は [公開契約](plugins/write-doc/skills/write-doc/CONTRACT.md) を正本とする。

```yaml
requires:
  - {plugin: write-doc, marketplace: write-doc}
steps:
  - id: document
    playbook: write-doc
    purpose: 完成本文をkind:textのmaterialとして渡し、Markdownを1本保存する
    provides: [status, path, reason]
```

## 資料の規律

資料の冒頭は、読み手の既知の語で書いた本文段落から始め、誰が何を達成するために読み、どこから始まり、何が観測できたら完了かを文章で運ぶ。型・対象・確認日・確認した人のようなメタ情報の一覧や引用blockは冒頭に置かない。型の読み方はtemplateのcommentと型カタログ（`assets/template-examples.yml`）に一度だけ置き、資料本文には書かない。中心の問い、扱う理由、確認日、確認した人のような作業記録は正本へ写さない。

## 構成

```text
plugins/write-doc/
├── .claude-plugin/plugin.json      両runtime manifest
├── .codex-plugin/plugin.json
├── LICENSE
└── skills/write-doc/               公開入口（公開playbook）
    ├── SKILL.md                    目的・入力・判断基準・手順・停止条件・出力
    ├── playbook.yml                同じagentが辿る7工程の宣言順
    ├── CONTRACT.md                 公開契約 v2
    ├── references/                 文章原則、正確性の確認、図表の役割
    └── assets/                     templates 19型、examples、personas、visual-guidance、型カタログ
```

## 検証

```bash
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate.sh
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins
```

構造検査の成功は文章の妥当性を保証しない。SKILL.md、templates、生成資料は読んで根拠付きで評価する。契約 v1 からの移行記録は [契約 v2 移行表](docs/contract-v2-migration.md) にある。
