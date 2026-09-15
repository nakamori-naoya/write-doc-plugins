# write-doc

素材から Markdown 資料を1本書いて保存する playbook package である。公開入口は `write-doc` 1つ、内部 skill は `author-document` 1つで構成する。

## 使い方

`write-doc` に `material` と保存先を直接渡す。新規作成では `output_directory` と `name`、更新では `update_target` を渡す。`document_type` と `references` は任意である。

詳しい入力、出力、保証は [公開契約](plugins/playbooks/authoring/write-doc/CONTRACT.md) を参照する。

内部 skill は読み手と目的を定め、テンプレートを選び、Markdown を直接執筆して保存する。設定解決 script、中間 YAML、外部 playbook は使わない。

## 構成

```text
plugins/
├── playbooks/authoring/write-doc/
└── skills/authoring/author-document/
    ├── SKILL.md
    ├── references/
    └── assets/
```

## 移行と検証

契約 v1 からの移行対象と消費側 inventory は [契約 v2 移行表](docs/contract-v2-migration.md) にある。

```bash
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate.sh
```
