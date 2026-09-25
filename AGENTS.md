> 共通の規約は /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md にある。ここには、この repository だけの規則を置く。

# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- marketplaceへ公開するインストール対象はpackage `write-doc`（`./plugins/write-doc`）だけにする。公開入口は`skills/write-doc` 1つで、内部skillは置かない。
- `write-doc`は自身の`SKILL.md`、`references/`、`assets/`だけで資料を直接執筆して保存する。
- BDD、対話、収集、PR、product、agent作業方針をこのrepositoryへ同梱しない。
- 資料の形は各型のtemplateが持ち、検査が読む目印もそのtemplateの冒頭に置く。文書型を追加したら、`assets/template-examples.yml`にtemplateと見本の組を足す。
- templateの冒頭は本文段落で始め、メタ情報の一覧・引用block・型の解説を置かない。作業記録の欄を成果物のtemplateへ足さない。
- Markdownを直接執筆し、明示されていない保存先を補わない。
