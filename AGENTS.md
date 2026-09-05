# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- marketplaceへ公開するインストール対象は`write-doc` playbook packageだけにする。`content-types`、`writing-rules`、`visual-guidance`、`doc-render`、`write-doc-cleanup`はpackage内部へ同梱し、別entryへ公開しない。
- `write-doc-cleanup`は、資料完成後の後始末として、明示された未追跡の中間成果物だけを最終資料を残して除く支援能力であるため配布する。`write-doc` playbookの必須依存にはしない。
- BDD、grill、収集、PR、product、agent作業方針を追加しない。
- playbookの依存は`marketplace / plugin`で完全修飾し、versionを固定せず、解決先に必要なskillが存在することを検査する。
- install cacheは編集せず、このsourceを正本として変更する。
- 変更後は`bash scripts/validate.sh`を実行する。
