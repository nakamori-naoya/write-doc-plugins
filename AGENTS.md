> 共通の規約は /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md にある。ここには、この repository だけの規則を置く。

# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- marketplaceへ公開するインストール対象はpackage `write-doc`（`./plugins/write-doc`）だけにする。公開入口は`skills/write-doc` 1つで、公開playbook `write-doc`でもある。内部skillは置かない。
- `write-doc`は自身の`SKILL.md`、`playbook.yml`、`references/`、`assets/`だけで資料を直接執筆して保存する。工程の順は`playbook.yml`の宣言順で決まり、同じagentがその順に辿る。
- BDD、対話、収集、PR、product、agent作業方針をこのrepositoryへ同梱しない。
- このrepositoryの公開契約は`plugins/write-doc/skills/write-doc/CONTRACT.md`が契約定義である。契約に無い振る舞いを消費側へ約束しない。契約変更時は両manifestの`contractVersion`と`implements`を一致させる。
- 文書型を追加したら、`assets/template-examples.yml`、`metadata.harness.implements[].types`、`scripts/validate.sh`の期待資産集合を同時に更新する。
- templateの冒頭は本文段落で始め、メタ情報の一覧・引用block・型の解説を置かない。作業記録の欄を成果物のtemplateへ足さない。
- Markdownを直接執筆し、明示されていない保存先を補わない。
