# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- 配布対象は`write-doc`、`content-types`、`writing-rules`、`visual-guidance`、`doc-render`に限定する。
- BDD、grill、収集、PR、product、agent作業方針を追加しない。
- playbookの依存は`marketplace / plugin / exact version`で完全修飾する。
- install cacheは編集せず、このsourceを正本として変更する。
- 変更後は`bash scripts/validate.sh`を実行する。
