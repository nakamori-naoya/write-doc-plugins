# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- marketplaceへ公開するインストール対象は`write-doc` playbook packageだけにする。`content-types`、`writing-rules`、`visual-guidance`、`doc-render`、`review-doc`、`write-doc-cleanup`はpackage内部へ同梱し、別entryへ公開しない。
- `write-doc-cleanup`は、資料完成後の後始末として、明示された未追跡の中間成果物だけを最終資料を残して除く支援能力であるため配布する。`write-doc` playbookの必須依存にはしない。
- BDD、対話、収集、PR、product、agent作業方針をこのrepositoryへ同梱しない。
- **外部pluginは公開playbookとしてしか参照しない。** `grill`は`{plugin: grill, marketplace: grill}`として`requires`で宣言し、`when`付きのsettle工程から`playbook: grill`で呼ぶ。`skill:`や`script:`で掴まない。相手の内部skill名・工程id・script引数・exit code・設定キーを、SKILL.md、README、references、playbook.yml、scriptsのどこにも書かない。使ってよいのは相手のCONTRACT.mdが公開した入口・入力・出力・保証だけである。
- **この repository の公開契約は[CONTRACT.md](plugins/playbooks/authoring/write-doc/CONTRACT.md)が正本である。** 契約に無い振る舞いを消費側へ約束しない。逆に、契約に書いたものは`metadata.harness.implements`と`scripts/contract-io.py`の検査と一致させる。文書型を足したら、カタログ・`implements[].types`・validateの3つを同時に更新する。
- playbookの依存は`marketplace / plugin`で完全修飾し、versionを固定しない。差し替えは`dependencies.yml`が担うので、`requires`を利用者向けに書き換えない。
- 実行基盤（resolver、prepare、state、lint）の正本はProduct Planning repositoryの`shared/runtime-source`である。ここでは直さず、正本を直して`scripts/sync-runtime.py --source <正本>`で配り直す。
- install cacheは編集せず、このsourceを正本として変更する。
- 変更後は`bash scripts/validate.sh`を実行する。依存先の実配布物に対する解決も検査するので、兄弟checkoutとして`../grill-plugins`を置くか、`HARNESS_GRILL_PACKAGE`でその`plugins/`を指す。
